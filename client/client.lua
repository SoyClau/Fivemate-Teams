-- ================================================
-- Fivemate Teams - Client Side
-- Sistema de clanes compatible con ESX y QBCore
-- ================================================

local Framework = nil
local PlayerData = {}
local PlayerClan = nil
local ClanMembers = {}
local IsHudActive = false

-- ================================================
-- INICIALIZACIÓN
-- ================================================

-- Variables de limpieza para evitar memory leaks
local eventHandlers = {}
local registeredMenus = {}

Citizen.CreateThread(function()
    -- Esperar a que el framework se cargue
    while Framework == nil do
        if GetResourceState('es_extended') == 'started' then
            Framework = 'ESX'
            ESX = exports['es_extended']:getSharedObject()
            
            while ESX.GetPlayerData().job == nil do
                Citizen.Wait(100)
            end
            
            PlayerData = ESX.GetPlayerData()
        elseif GetResourceState('qb-core') == 'started' then
            Framework = 'QBCore'
            QBCore = exports['qb-core']:GetCoreObject()
            
            while QBCore.Functions.GetPlayerData().job == nil do
                Citizen.Wait(100)
            end
            
            PlayerData = QBCore.Functions.GetPlayerData()
        end
        Citizen.Wait(100)
    end
    
    -- Esperar un tiempo adicional para asegurar que el servidor esté listo
    Citizen.Wait(1000)
    
    -- Solicitar datos del clan al servidor
    TriggerServerEvent('fivemate-teams:server:getClanData')
    
    -- Inicializar HUD si está habilitado (con pequeño retraso para asegurar carga correcta)
    Citizen.Wait(500)
    if Config.HUD.Enabled then
        StartClanHUD()
    end
    
    -- Inicializar sistema de blips si está habilitado
    if Config.Blips and Config.Blips.Enabled then
        Citizen.Wait(200) -- Pequeño retraso para evitar sobrecarga
        InitClanMemberBlips() -- Esta función ahora se encuentra en blips_new.lua para más funcionalidades
        
        if Config.Debug then
            print("[Fivemate-Teams] Sistema de blips dinámicos inicializado correctamente")
        end
    end
end)

-- Función para limpiar recursos cuando se detiene el script
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    
    -- Limpiar todos los event handlers registrados
    for _, handler in ipairs(eventHandlers) do
        if handler then
            RemoveEventHandler(handler)
        end
    end
    
    -- Limpiar todos los menús registrados
    for _, menuId in ipairs(registeredMenus) do
        if lib and lib.unregisterContext then
            lib.unregisterContext(menuId)
        end
    end
    
    -- Ocultar HUD al detener el recurso
    if IsHudActive then
        IsHudActive = false
        
        -- Usar pcall para evitar errores
        pcall(function()
            SendNUIMessage({
                action = 'hideHUD'
            })
        end)
    end
    
    -- Limpiar variables
    PlayerClan = nil
    ClanMembers = {}
    CachedHudData = nil
    
    print("[Fivemate-Teams] Recurso detenido y memoria limpiada correctamente")
end)

-- Inicializar el recurso con un retraso de seguridad para evitar crasheos
Citizen.CreateThread(function()
    -- Esperar un tiempo para asegurar que todo se cargue correctamente
    Citizen.Wait(2000)
    
    -- Inicializar HUD si está habilitado
    if Config.HUD.Enabled then
        StartClanHUD()
    end
end)

-- Función para registrar event handlers de forma limpia
function RegisterSafeEventHandler(eventName, callback)
    local handler = AddEventHandler(eventName, callback)
    table.insert(eventHandlers, handler)
    return handler
end

-- Función para registrar menús de forma limpia
function RegisterSafeContext(menuData)
    lib.registerContext(menuData)
    table.insert(registeredMenus, menuData.id)
end

-- ================================================
-- EVENTOS DE FRAMEWORK
-- ================================================

if Framework == 'ESX' then
    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(xPlayer)
        PlayerData = xPlayer
        TriggerServerEvent('fivemate-teams:server:getClanData')
    end)
    
    RegisterNetEvent('esx:setJob')
    AddEventHandler('esx:setJob', function(job)
        PlayerData.job = job
    end)
elseif Framework == 'QBCore' then
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
    AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
        PlayerData = QBCore.Functions.GetPlayerData()
        TriggerServerEvent('fivemate-teams:server:getClanData')
    end)
    
    RegisterNetEvent('QBCore:Client:OnJobUpdate')
    AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
        PlayerData.job = JobInfo
    end)
end

-- ================================================
-- EVENTOS DEL SERVIDOR
-- ================================================

-- Recibir datos del clan
RegisterNetEvent('fivemate-teams:client:receiveClanData')
AddEventHandler('fivemate-teams:client:receiveClanData', function(clanData)
    PlayerClan = clanData
end)

-- Actualizar datos del clan
RegisterNetEvent('fivemate-teams:client:updateClanData')
AddEventHandler('fivemate-teams:client:updateClanData', function(clanData)
    PlayerClan = clanData
    
    if clanData then
        TriggerServerEvent('fivemate-teams:server:getClanMembers')
    else
        ClanMembers = {}
        
        -- Si ya no pertenecemos a un clan, limpiar los blips
        if Config.Blips and Config.Blips.Enabled then
            ClearAllClanBlips()
        end
    end
end)

-- Recibir lista de miembros
RegisterNetEvent('fivemate-teams:client:receiveClanMembers')
AddEventHandler('fivemate-teams:client:receiveClanMembers', function(members)
    ClanMembers = members
    
    -- Actualizar blips cuando recibimos nuevos datos de miembros
    if Config.Blips and Config.Blips.Enabled then
        Citizen.Wait(100) -- Pequeña espera para procesar los datos
        UpdateClanBlips()
    end
    
    -- Actualizar HUD cuando recibimos nuevos datos de miembros
    if Config.HUD and Config.HUD.Enabled then
        Citizen.Wait(100) -- Pequeña espera para procesar los datos
        UpdateClanHUD()
    end
end)

-- Recibir invitación
RegisterNetEvent('fivemate-teams:client:receiveInvitation')
AddEventHandler('fivemate-teams:client:receiveInvitation', function(inviteData)
    -- Verificar que tenemos todos los datos necesarios
    if not inviteData or not inviteData.clanName or not inviteData.inviterName or not inviteData.id or not inviteData.clanId then
        print('[Fivemate-Teams] Error: Datos de invitación incompletos')
        return
    end
    
    -- Usar Citizen.CreateThread para evitar bloqueos
    Citizen.CreateThread(function()
        -- Formatear el contenido del mensaje
        local content = string.format(
            '**%s** te ha invitado a unirte al clan **%s [%s]**\n\n¿Deseas aceptar la invitación?', 
            inviteData.inviterName, 
            inviteData.clanName, 
            inviteData.clanTag or ''
        )
        
        -- Mostrar la alerta de invitación
        local alert = lib.alertDialog({
            header = 'Invitación a Clan',
            content = content,
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Aceptar',
                cancel = 'Rechazar'
            }
        })
        
        -- Procesar la respuesta
        if alert == 'confirm' then
            -- Enviar respuesta al servidor incluyendo los datos completos de la invitación
            TriggerServerEvent('fivemate-teams:server:acceptInvitation', inviteData)
        else
            -- Opcional: Notificar rechazo
            TriggerServerEvent('fivemate-teams:server:rejectInvitation', inviteData)
        end
    end)
end)

-- Miembro se conectó
RegisterNetEvent('fivemate-teams:client:memberOnline')
AddEventHandler('fivemate-teams:client:memberOnline', function(memberData)
    if not memberData or not memberData.citizenid then return end
    
    -- Verificar si ya tenemos datos de miembros
    if not ClanMembers or #ClanMembers == 0 then
        -- Si no tenemos datos, solicitar la lista completa
        TriggerServerEvent('fivemate-teams:server:getClanMembers')
        return
    end
    
    -- Actualizar el estado del miembro en la lista
    local memberFound = false
    for i, member in ipairs(ClanMembers) do
        if member.citizenid == memberData.citizenid then
            ClanMembers[i].online = true
            ClanMembers[i].name = memberData.name
            ClanMembers[i].source = memberData.source
            memberFound = true
            break
        end
    end
    
    -- Si no encontramos al miembro, es posible que necesitemos recargar la lista completa
    if not memberFound then
        TriggerServerEvent('fivemate-teams:server:getClanMembers')
    end
    
    -- Actualizar blips si están habilitados
    if Config.Blips and Config.Blips.Enabled then
        Citizen.Wait(500) -- Pequeña espera para asegurar que los datos estén actualizados
        UpdateClanBlips()
    end
    
    -- Mostrar notificación
    lib.notify({
        title = 'Miembro del Clan',
        description = string.format('%s está ahora online', memberData.name),
        type = 'info',
        duration = 5000
    })
end)

-- Miembro se desconectó
RegisterNetEvent('fivemate-teams:client:memberOffline')
AddEventHandler('fivemate-teams:client:memberOffline', function(memberData)
    if not memberData or not memberData.citizenid then return end
    
    -- Verificar si ya tenemos datos de miembros
    if not ClanMembers or #ClanMembers == 0 then
        -- Si no tenemos datos, solicitar la lista completa
        TriggerServerEvent('fivemate-teams:server:getClanMembers')
        return
    end
    
    -- Actualizar el estado del miembro en la lista
    local memberFound = false
    for i, member in ipairs(ClanMembers) do
        if member.citizenid == memberData.citizenid then
            ClanMembers[i].online = false
            ClanMembers[i].name = memberData.name
            ClanMembers[i].source = nil
            memberFound = true
            break
        end
    end
    
    -- Si no encontramos al miembro, es posible que necesitemos recargar la lista completa
    if not memberFound then
        TriggerServerEvent('fivemate-teams:server:getClanMembers')
    end
    
    -- Actualizar blips si están habilitados
    if Config.Blips and Config.Blips.Enabled then
        Citizen.Wait(500) -- Pequeña espera para asegurar que los datos estén actualizados
        UpdateClanBlips()
    end
    
    -- Mostrar notificación
    lib.notify({
        title = 'Miembro del Clan',
        description = string.format('%s está ahora offline', memberData.name),
        type = 'info',
        duration = 5000
    })
end)

-- Nuevo evento para cuando un miembro se une al clan
RegisterNetEvent('fivemate-teams:client:memberJoined')
AddEventHandler('fivemate-teams:client:memberJoined', function(memberData)
    if not memberData or not memberData.citizenid then return end
    
    -- Recargar la lista de miembros para incluir al nuevo
    TriggerServerEvent('fivemate-teams:server:getClanMembers')
    
    -- Actualizar blips si están habilitados
    if Config.Blips and Config.Blips.Enabled then
        Citizen.Wait(500) -- Pequeña espera para asegurar que los datos estén actualizados
        UpdateClanBlips()
    end
    
    -- Forzar actualización del HUD para reflejar el nuevo miembro
    if Config.HUD and Config.HUD.Enabled then
        Citizen.Wait(500) -- Esperar a que se actualicen los datos
        UpdateClanHUD()
        
        -- Forzar que el HUD se muestre si aún no está activo
        if not IsHudActive then
            IsHudActive = true
            SendNUIMessage({
                action = 'showHUD'
            })
        end
    end
    
    -- Mostrar notificación
    if memberData.message then
        lib.notify({
            title = 'Clan',
            description = memberData.message,
            type = 'success',
            duration = 5000
        })
    else
        lib.notify({
            title = 'Clan',
            description = string.format('%s se ha unido al clan', memberData.name),
            type = 'success',
            duration = 5000
        })
    end
end)

-- Nuevo evento para cuando un miembro es expulsado del clan
RegisterNetEvent('fivemate-teams:client:memberRemoved')
AddEventHandler('fivemate-teams:client:memberRemoved', function(memberData)
    if not memberData then return end
    
    -- Recargar la lista de miembros para actualizar
    TriggerServerEvent('fivemate-teams:server:getClanMembers')
    
    -- Actualizar blips si están habilitados
    if Config.Blips and Config.Blips.Enabled then
        Citizen.Wait(500) -- Pequeña espera para asegurar que los datos estén actualizados
        UpdateClanBlips()
    end

    -- Actualizar HUD cuando un miembro es expulsado
    if Config.HUD and Config.HUD.Enabled then
        Citizen.Wait(500) -- Esperar a que se actualicen los datos
        UpdateClanHUD()
    end    

    -- Mostrar notificación
    if memberData.message then
        lib.notify({
            title = 'Clan',
            description = memberData.message,
            type = 'warning',
            duration = 5000
        })
    end
end)

-- Nuevo evento para cuando un miembro abandona el clan
RegisterNetEvent('fivemate-teams:client:memberLeft')
AddEventHandler('fivemate-teams:client:memberLeft', function(memberData)
    if not memberData or not memberData.citizenid then return end
    
    -- Recargar la lista de miembros para actualizar
    TriggerServerEvent('fivemate-teams:server:getClanMembers')
    
    -- Actualizar blips si están habilitados
    if Config.Blips and Config.Blips.Enabled then
        Citizen.Wait(500) -- Pequeña espera para asegurar que los datos estén actualizados
        UpdateClanBlips()
    end
    
    -- Actualizar HUD cuando un miembro abandona el clan
    if Config.HUD and Config.HUD.Enabled then
        Citizen.Wait(500) -- Esperar a que se actualicen los datos
        UpdateClanHUD()
    end
    
    -- Mostrar notificación
    if memberData.message then
        lib.notify({
            title = 'Clan',
            description = memberData.message,
            type = 'info',
            duration = 5000
        })
    else
        lib.notify({
            title = 'Clan',
            description = string.format('%s ha abandonado el clan', memberData.name or 'Un miembro'),
            type = 'info',
            duration = 5000
        })
    end
end)

-- Evento para limpiar recursos del cliente cuando se detiene el recurso
RegisterNetEvent('fivemate-teams:client:cleanupResource')
AddEventHandler('fivemate-teams:client:cleanupResource', function()
    -- Limpiar variables
    PlayerClan = nil
    ClanMembers = {}
    IsHudActive = false
    CachedHudData = nil
    
    -- Ocultar HUD
    SendNUIMessage({
        action = 'hideHUD'
    })
    
    -- Limpiar blips si están habilitados
    if Config.Blips and Config.Blips.Enabled then
        ClearAllClanBlips()
    end
    
    if Config.Debug then
        print("[Fivemate-Teams] Cliente: Recurso limpiado por solicitud del servidor")
    end
end)

-- ================================================
-- FUNCIONES DEL MENÚ
-- ================================================

-- Menú principal de clan
function OpenClanMenu()
    -- Solicitar la lista actualizada de miembros al servidor
    TriggerServerEvent('fivemate-teams:server:getClanMembers')
    
    -- Forzar actualización del HUD si está habilitado
    if Config.HUD and Config.HUD.Enabled and PlayerClan then
        Citizen.CreateThread(function()
            Citizen.Wait(200) -- Esperar a que lleguen los datos
            UpdateClanHUD()
        end)
    end
    
    if not PlayerClan then
        OpenCreateClanMenu()
    else
        OpenManageClanMenu()
    end
end

-- Menú de creación de clan
function OpenCreateClanMenu()
    local input = lib.inputDialog('Crear Clan', {
        {
            type = 'input',
            label = 'Nombre del Clan',
            description = string.format('Entre %d y %d caracteres', Config.Clan.MinNameLength, Config.Clan.MaxNameLength),
            required = true,
            min = Config.Clan.MinNameLength,
            max = Config.Clan.MaxNameLength
        },
        {
            type = 'input',
            label = 'Tag del Clan',
            description = string.format('Entre %d y %d caracteres', Config.Clan.MinTagLength, Config.Clan.MaxTagLength),
            required = true,
            min = Config.Clan.MinTagLength,
            max = Config.Clan.MaxTagLength
        }
    })

    if input then
        TriggerServerEvent('fivemate-teams:server:createClan', {
            name = input[1],
            tag = input[2]
        })
    end
end

-- Menú de gestión de clan
function OpenManageClanMenu()
    -- Verificar que PlayerClan existe para evitar errores
    if not PlayerClan then
        lib.notify({
            title = 'Error',
            description = 'No se pudo cargar la información del clan. Inténtalo de nuevo.',
            type = 'error'
        })
        return
    end
    
    local options = {
        {
            title = string.format('Clan: %s [%s]', PlayerClan.name or 'Desconocido', PlayerClan.tag or ''),
            description = string.format('Tu rol: %s', Config.Roles[PlayerClan.role or 'member'].label),
            icon = 'users',
            disabled = true
        },
        {
            title = 'Ver Miembros',
            description = 'Lista de miembros del clan',
            icon = 'list',
            onSelect = function()
                OpenMembersMenu()
            end
        }
    }
    
    -- Opciones según permisos
    if PlayerClan and (PlayerClan.role == 'leader' or PlayerClan.role == 'sublider') then
        table.insert(options, {
            title = 'Invitar Jugador',
            description = 'Invitar a un jugador cercano',
            icon = 'user-plus',
            onSelect = function()
                InviteNearbyPlayer()
            end
        })
    end
    
    if PlayerClan and (PlayerClan.role == 'leader' or PlayerClan.role == 'sublider') then
        table.insert(options, {
            title = 'Expulsar Miembro',
            description = 'Expulsar a un miembro del clan',
            icon = 'user-minus',
            onSelect = function()
                OpenKickMenu()
            end
        })
    end
    
    if PlayerClan and PlayerClan.role == 'leader' then
        table.insert(options, {
            title = 'Transferir Liderazgo',
            description = 'Transferir el liderazgo a otro miembro',
            icon = 'crown',
            onSelect = function()
                OpenTransferMenu()
            end
        })
        
        -- Añadir opción para eliminar el clan (solo para el líder)
        table.insert(options, {
            title = 'Eliminar Clan',
            description = 'Eliminar permanentemente el clan',
            icon = 'trash',
            iconColor = 'red',
            onSelect = function()
                local alert = lib.alertDialog({
                    header = 'Eliminar Clan',
                    content = Config.Messages.Info.ConfirmDeleteClan,
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = 'Sí, eliminar clan',
                        cancel = 'Cancelar'
                    }
                })
                
                if alert == 'confirm' then
                    -- Solicitar una segunda confirmación con cuenta regresiva
                    lib.notify({
                        id = 'delete_clan_confirm',
                        title = 'Confirmación Requerida',
                        description = 'El clan será eliminado en 5 segundos. Escribe /cancelar para abortar.',
                        type = 'warning',
                        duration = 5000
                    })
                    
                    -- Iniciar un temporizador antes de eliminar
                    Citizen.CreateThread(function()
                        local cancelled = false
                        
                        -- Registrar comando temporal para cancelar
                        RegisterCommand('cancelar', function()
                            cancelled = true
                            lib.notify({
                                title = 'Eliminación Cancelada',
                                description = 'La eliminación del clan ha sido cancelada',
                                type = 'success'
                            })
                        end, false)
                        
                        -- Esperar 5 segundos
                        for i = 5, 1, -1 do
                            if cancelled then break end
                            
                            lib.notify({
                                id = 'delete_clan_countdown',
                                title = 'Eliminando Clan',
                                description = string.format('El clan será eliminado en %d segundos...', i),
                                type = 'warning',
                                duration = 1000
                            })
                            
                            Citizen.Wait(1000)
                        end
                        
                        -- Eliminar el comando temporal
                        ExecuteCommand('unbind /cancelar')
                        
                        -- Si no se canceló, eliminar el clan
                        if not cancelled then
                            TriggerServerEvent('fivemate-teams:server:deleteClan')
                        end
                    end)
                end
            end
        })
    end
    
    table.insert(options, {
        title = 'Salir del Clan',
        description = 'Abandonar el clan actual',
        icon = 'sign-out-alt',
        onSelect = function()
            local alert = lib.alertDialog({
                header = 'Salir del Clan',
                content = '¿Estás seguro de que quieres salir del clan?',
                centered = true,
                cancel = true
            })
            
            if alert == 'confirm' then
                TriggerServerEvent('fivemate-teams:server:leaveClan')
            end
        end
    })

    RegisterSafeContext({
        id = 'clan_menu',
        title = 'Gestión de Clan',
        options = options
    })

    lib.showContext('clan_menu')
end

-- Menú de miembros
function OpenMembersMenu()
    -- Primero establecer un indicador de que estamos esperando datos
    local waitingForMembers = true
    local memberEventHandler = nil
    
    -- Registrar una devolución de llamada de evento temporal para la respuesta
    memberEventHandler = RegisterSafeEventHandler('fivemate-teams:client:receiveClanMembers', function(members)
        ClanMembers = members
        waitingForMembers = false
    end)
    
    -- Solicitar miembros al servidor
    TriggerServerEvent('fivemate-teams:server:getClanMembers')
    
    -- Esperar a que los datos lleguen o pasar un tiempo máximo de espera
    local timeout = 0
    while waitingForMembers and timeout < 50 do -- 5 segundos máximo (100ms x 50)
        Citizen.Wait(100)
        timeout = timeout + 1
    end
    
    -- Si salimos por timeout, no es necesario eliminar el handler manualmente
    -- ya que RegisterSafeEventHandler lo maneja automáticamente
    if waitingForMembers then
        lib.notify({
            title = 'Error',
            description = 'No se pudieron cargar los miembros. Inténtalo de nuevo.',
            type = 'error'
        })
        return
    end
    
    local options = {}
    
    for _, member in ipairs(ClanMembers) do
        local roleData = Config.Roles[member.role]
        local statusIcon = member.online and 'circle' or 'circle-o'
        local statusColor = member.online and 'green' or 'red'
        
        table.insert(options, {
            title = member.name,
            description = string.format('Rol: %s | Estado: %s', 
                roleData.label, 
                member.online and 'Conectado' or 'Desconectado'
            ),
            icon = statusIcon,
            iconColor = statusColor
        })
    end
    
    if #options == 0 then
        table.insert(options, {
            title = 'No hay miembros',
            disabled = true
        })
    end

    lib.registerContext({
        id = 'clan_members',
        title = Config.Messages.Info.ClanMembers,
        menu = 'clan_menu',
        options = options
    })

    lib.showContext('clan_members')
end

-- Menú para expulsar miembros
function OpenKickMenu()
    -- Primero establecer un indicador de que estamos esperando datos
    local waitingForMembers = true
    local memberEventHandler = nil
    
    -- Registrar una devolución de llamada de evento temporal para la respuesta
    memberEventHandler = RegisterSafeEventHandler('fivemate-teams:client:receiveClanMembers', function(members)
        ClanMembers = members
        waitingForMembers = false
    end)
    
    -- Solicitar miembros al servidor
    TriggerServerEvent('fivemate-teams:server:getClanMembers')
    
    -- Esperar a que los datos lleguen o pasar un tiempo máximo de espera
    local timeout = 0
    while waitingForMembers and timeout < 50 do -- 5 segundos máximo (100ms x 50)
        Citizen.Wait(100)
        timeout = timeout + 1
    end
    
    -- Si salimos por timeout, no es necesario eliminar el handler manualmente
    -- ya que RegisterSafeEventHandler lo maneja automáticamente
    if waitingForMembers then
        lib.notify({
            title = 'Error',
            description = 'No se pudieron cargar los miembros. Inténtalo de nuevo.',
            type = 'error'
        })
        return
    end
    
    local options = {}
    local citizenid = GetPlayerIdentifier()
    
    for _, member in ipairs(ClanMembers) do
        if member.role ~= 'leader' and member.citizenid ~= citizenid then
            table.insert(options, {
                title = member.name,
                description = string.format('Rol: %s', Config.Roles[member.role].label),
                icon = 'user-minus',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = 'Expulsar Miembro',
                        content = string.format('¿Estás seguro de que quieres expulsar a %s?', member.name),
                        centered = true,
                        cancel = true
                    })
                    
                    if alert == 'confirm' then
                        TriggerServerEvent('fivemate-teams:server:kickPlayer', member.citizenid)
                    end
                end
            })
        end
    end
    
    if #options == 0 then
        table.insert(options, {
            title = 'No hay miembros para expulsar',
            disabled = true
        })
    end

    lib.registerContext({
        id = 'clan_kick',
        title = 'Expulsar Miembro',
        menu = 'clan_menu',
        options = options
    })

    lib.showContext('clan_kick')
end

-- Invitar jugador cercano
function InviteNearbyPlayer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local players = {}
    
    -- Obtener todos los jugadores activos (actualizado para usar GetActivePlayers)
    for _, playerId in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)
            
            if distance <= 10.0 then -- 10 metros de distancia
                local serverId = GetPlayerServerId(playerId)
                local playerName = GetPlayerName(playerId)
                
                table.insert(players, {
                    serverId = serverId,
                    name = playerName,
                    distance = math.floor(distance)
                })
            end
        end
    end
    
    -- Ordenar por distancia
    table.sort(players, function(a, b) return a.distance < b.distance end)
    
    local options = {}
    for _, playerData in ipairs(players) do
        table.insert(options, {
            title = playerData.name,
            description = string.format('Distancia: %dm - Invitar a este jugador', playerData.distance),
            icon = 'user-plus',
            onSelect = function()
                TriggerServerEvent('fivemate-teams:server:invitePlayer', playerData.serverId)
            end
        })
    end
    
    if #options == 0 then
        lib.notify({
            title = 'Clan System',
            description = 'No hay jugadores cercanos para invitar (máximo 10m)',
            type = 'error'
        })
        return
    end

    lib.registerContext({
        id = 'clan_invite',
        title = 'Invitar Jugador Cercano',
        menu = 'clan_menu',
        options = options
    })

    lib.showContext('clan_invite')
end

-- ================================================
-- FUNCIONES HUD
-- ================================================

local LastHudUpdate = 0
local HudUpdateInterval = 2000 -- Actualizar cada 2 segundos para optimización
local CachedHudData = {}

-- Iniciar HUD del clan
function StartClanHUD()
    -- Crear un wrapper seguro para actualizar el HUD
    local function SafeUpdateHUD()
        -- Usar pcall para evitar que cualquier error en el HUD crashee el juego
        local success, error = pcall(UpdateClanHUD)
        if not success and Config.Debug then
            print("[Fivemate-Teams] Error en actualización del HUD: " .. tostring(error))
        end
        return success
    end

    Citizen.CreateThread(function()
        -- Asegurar que todo está listo antes de comenzar
        Citizen.Wait(1000)
        
        local startTime = GetGameTimer()
        local hudInitialized = false
        
        -- Intentar inicializar el HUD con reintentos
        while not hudInitialized and GetGameTimer() - startTime < 10000 do
            hudInitialized = SafeUpdateHUD()
            Citizen.Wait(500)
        end
        
        -- Si no se pudo inicializar después de los reintentos, mostrar un mensaje y continuar
        if not hudInitialized and Config.Debug then
            print("[Fivemate-Teams] No se pudo inicializar el HUD después de varios intentos")
        end
        
        -- Bucle principal del HUD (con menor frecuencia para optimización)
        while true do
            -- Usar un intervalo más largo para evitar sobrecarga
            Citizen.Wait(HudUpdateInterval or 2000)
            
            local currentTime = GetGameTimer()
            if currentTime - LastHudUpdate >= HudUpdateInterval then
                SafeUpdateHUD()
                LastHudUpdate = currentTime
            end
        end
    end)
end

-- Actualizar datos del HUD
function UpdateClanHUD()
    -- No hacer nada si no tenemos clan o el HUD está desactivado
    if not PlayerClan or not Config.HUD.Enabled then
        if IsHudActive then
            IsHudActive = false
            SendNUIMessage({
                action = 'hideHUD'
            })
            
            -- Esperar confirmación de que se ocultó (evitar race conditions)
            Citizen.Wait(50)
        end
        return
    end
    
    -- Validar que el PlayerClan tenga todas las propiedades necesarias
    if not PlayerClan.name or not PlayerClan.tag or not PlayerClan.role then
        if Config.Debug then
            print("[Fivemate-Teams] Error: Datos de clan incompletos en UpdateClanHUD")
        end
        return
    end
    
    -- Mostrar HUD si tenemos clan (incluso sin miembros cercanos para info persistente)
    if not IsHudActive then
        IsHudActive = true
        
        -- Primero enviamos un mensaje para comprobar que la NUI está lista
        SendNUIMessage({action = 'ping'})
        Citizen.Wait(100) -- Espera más tiempo para asegurar que la NUI esté lista
        
        SendNUIMessage({
            action = 'showHUD'
        })
        
        -- Esperar confirmación de que se mostró (evitar race conditions)
        Citizen.Wait(100)
    end
    
    local hudData = {}
    local playerPed = PlayerPedId()
    if not DoesEntityExist(playerPed) then
        return -- Si el jugador no existe, no actualizamos el HUD
    end
    
    -- Agregar información básica del clan
    table.insert(hudData, {
        name = string.format('Clan: %s [%s]', PlayerClan.name, PlayerClan.tag),
        role = 'info',
        distance = 0,
        health = 0, -- No mostrar salud
        color = '#FFD700',
        isHeader = true,
        hideHealth = true
    })
    
    -- Agregar información del jugador actual, sin mostrar la salud
    table.insert(hudData, {
        name = 'Tú (' .. Config.Roles[PlayerClan.role].label .. ')',
        role = PlayerClan.role,
        distance = 0,
        health = 0, -- No mostrar salud
        color = Config.Roles[PlayerClan.role].color,
        isSelf = true,
        hideHealth = true
    })
    
    -- Agregar miembros del clan online (sin calcular distancia)
    if ClanMembers and #ClanMembers > 0 then
        local onlineMembers = 0
        
        for _, member in ipairs(ClanMembers) do
            -- Verificar que los datos del miembro son válidos
            if member and member.online and member.source and member.citizenid and
               member.role and member.name and 
               member.citizenid ~= GetPlayerIdentifier() then
                
                local memberPed = GetPlayerPed(GetPlayerFromServerId(member.source))
                if memberPed and memberPed ~= 0 and memberPed ~= playerPed and DoesEntityExist(memberPed) then
                    local health = GetEntityHealth(memberPed)
                    local maxHealth = GetEntityMaxHealth(memberPed)
                    
                    -- No mostrar salud
                    table.insert(hudData, {
                        name = member.name,
                        role = member.role,
                        distance = 0, -- Sin calcular distancia para optimización
                        health = 0, -- No mostrar salud
                        color = Config.Roles[member.role].color,
                        hideHealth = true
                    })
                    
                    onlineMembers = onlineMembers + 1
                end
            end
        end
        
        -- Si no hay miembros online, mostrar información
        if onlineMembers == 0 then
            table.insert(hudData, {
                name = 'No hay otros miembros online',
                role = 'info',
                distance = 0,
                health = 0,
                color = '#888888',
                isInfo = true,
                hideHealth = true
            })
        end
    else
        table.insert(hudData, {
            name = 'Eres el único miembro',
            role = 'info',
            distance = 0,
            health = 0,
            color = '#888888',
            isInfo = true,
            hideHealth = true
        })
    end
    
    -- Solo enviar si los datos han cambiado (optimización)
    local success, dataString = pcall(json.encode, hudData)
    if not success then
        if Config.Debug then
            print("[Fivemate-Teams] Error al codificar datos del HUD: ", dataString)
        end
        return
    end
    
    if dataString ~= CachedHudData then
        CachedHudData = dataString
        
        -- Verificar que tenemos hudData antes de enviar
        if hudData and #hudData > 0 then
            -- Usar pcall para evitar crasheos por errores en envío de mensajes NUI
            local success, error = pcall(function()
                -- Enviamos primero un mensaje para comprobar que la NUI está lista
                SendNUIMessage({action = 'ping'})
                
                -- Luego enviamos los datos con un pequeño retraso para evitar race conditions
                Citizen.Wait(50)
                
                SendNUIMessage({
                    action = 'updateHUD',
                    members = hudData
                })
            end)
            
            if not success and Config.Debug then
                print("[Fivemate-Teams] Error al enviar mensaje NUI: " .. tostring(error))
            end
        else
            if Config.Debug then
                print("[Fivemate-Teams] Error: hudData inválido")
            end
        end
    end
end

-- ================================================
-- PROTECCIÓN CONTRA FUEGO AMIGO (OPTIMIZADA)
-- ================================================

local LastFriendlyFireCheck = 0
local FriendlyFireCheckInterval = 100 -- Verificar cada 100ms en lugar de cada frame

-- Prevenir daño entre miembros del clan
Citizen.CreateThread(function()
    if Config.Protection.FriendlyFire then return end -- Si está permitido, no hacer nada
    
    while true do
        local currentTime = GetGameTimer()
        
        -- Solo verificar si han pasado suficientes milisegundos y hay clan
        if PlayerClan and ClanMembers and #ClanMembers > 0 and 
           currentTime - LastFriendlyFireCheck >= FriendlyFireCheckInterval then
            
            -- Usar IsPedShooting en lugar de GetEntityPlayerIsFreeAimingAt para mejor rendimiento
            if IsPedArmed(PlayerPedId(), 4) and IsPedShooting(PlayerPedId()) then
                -- Si está disparando, verificar si algún miembro del clan está en la línea de fuego
                local startPoint = GetPedBoneCoords(PlayerPedId(), 31086, 0.0, 0.0, 0.0)
                local cameraRotation = GetGameplayCamRot(0)
                local direction = RotationToDirection(cameraRotation)
                local endPoint = vector3(
                    startPoint.x + direction.x * 50.0,
                    startPoint.y + direction.y * 50.0,
                    startPoint.z + direction.z * 50.0
                )
                
                -- Comprobar si algún miembro del clan está en la línea de tiro
                for _, member in ipairs(ClanMembers) do
                    if member.online and member.source and member.citizenid ~= GetPlayerIdentifier() then
                        local memberPed = GetPlayerPed(GetPlayerFromServerId(member.source))
                        if memberPed and memberPed ~= 0 and DoesEntityExist(memberPed) then
                            -- Verificar si el miembro está en la línea de tiro usando raycast
                            local hit, entityHit = GetShapeTestResult(
                                StartShapeTestRay(startPoint.x, startPoint.y, startPoint.z, 
                                                 endPoint.x, endPoint.y, endPoint.z, 
                                                 -1, PlayerPedId(), 0)
                            )
                            
                            if entityHit == memberPed then
                                -- Desactivar capacidad de disparo temporalmente
                                DisablePlayerFiring(PlayerId(), true)
                                
                                -- Mostrar mensaje de advertencia (solo una vez cada 2 segundos)
                                if currentTime - LastFriendlyFireCheck >= 2000 then
                                    lib.notify({
                                        title = 'Fuego Amigo',
                                        description = string.format('No puedes atacar a %s (miembro del clan)', member.name),
                                        type = 'error',
                                        duration = 1000
                                    })
                                end
                                break
                            end
                        end
                    end
                end
            end
            
            LastFriendlyFireCheck = currentTime
        end
        
        Citizen.Wait(50) -- Verificar cada 50ms en lugar de cada frame
    end
end)

-- Función auxiliar para convertir rotación a dirección
function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return vector3(direction.x, direction.y, direction.z)
end

-- ================================================
-- FUNCIONES AUXILIARES
-- ================================================

-- Obtener jugadores en rango
function GetPlayersInRange(coords, range)
    local players = {}
    for _, playerId in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= PlayerPedId() then
            local targetCoords = GetEntityCoords(targetPed)
            if #(coords - targetCoords) <= range then
                table.insert(players, GetPlayerServerId(playerId))
            end
        end
    end
    return players
end

-- Obtener identificador del jugador (para compatibilidad)
function GetPlayerIdentifier()
    if Framework == 'ESX' then
        return PlayerData.identifier
    elseif Framework == 'QBCore' then
        return PlayerData.citizenid
    end
end

-- ================================================
-- COMANDOS
-- ================================================

-- Comando para abrir menú de clan
RegisterCommand(Config.Commands.ClanMenu, function()
    OpenClanMenu()
end)

-- Mapeo de tecla (opcional)
if Config.Keys.OpenMenu then
    RegisterKeyMapping(Config.Commands.ClanMenu, 'Abrir Menú de Clan', 'keyboard', Config.Keys.OpenMenu)
end

-- ================================================
-- EXPORTS
-- ================================================

exports('GetPlayerClan', function()
    return PlayerClan
end)

exports('GetClanMembers', function()
    return ClanMembers
end)

exports('OpenClanMenu', OpenClanMenu)