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

Citizen.CreateThread(function()
    -- Esperar a que el framework se cargue
    while Framework == nil do
        if GetResourceState('es_extended') == 'started' then
            Framework = 'ESX'
            ESX = exports['es_extended']:getSharedObject()
            
            while ESX.GetPlayerData().job == nil do
                Citizen.Wait(10)
            end
            
            PlayerData = ESX.GetPlayerData()
        elseif GetResourceState('qb-core') == 'started' then
            Framework = 'QBCore'
            QBCore = exports['qb-core']:GetCoreObject()
            
            while QBCore.Functions.GetPlayerData().job == nil do
                Citizen.Wait(10)
            end
            
            PlayerData = QBCore.Functions.GetPlayerData()
        end
        Citizen.Wait(100)
    end
    
    -- Solicitar datos del clan al servidor
    TriggerServerEvent('fivemate-teams:server:getClanData')
    
    -- Inicializar HUD si está habilitado
    if Config.HUD.Enabled then
        StartClanHUD()
    end
end)

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
    end
end)

-- Recibir lista de miembros
RegisterNetEvent('fivemate-teams:client:receiveClanMembers')
AddEventHandler('fivemate-teams:client:receiveClanMembers', function(members)
    ClanMembers = members
end)

-- Recibir invitación
RegisterNetEvent('fivemate-teams:client:receiveInvitation')
AddEventHandler('fivemate-teams:client:receiveInvitation', function(inviteData)
    -- Verificar que tenemos todos los datos necesarios
    if not inviteData or not inviteData.clanName or not inviteData.inviterName then
        print('[Fivemate-Teams] Error: Datos de invitación incompletos')
        return
    end
    
    -- Usar Citizen.CreateThread para evitar bloqueos
    Citizen.CreateThread(function()
        local alert = lib.alertDialog({
            header = 'Invitación a Clan',
            content = string.format('**%s** te ha invitado a unirte al clan **%s [%s]**\n\n¿Deseas aceptar la invitación?', 
                inviteData.inviterName, inviteData.clanName, inviteData.clanTag or ''),
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Aceptar',
                cancel = 'Rechazar'
            }
        })
        
        if alert == 'confirm' then
            TriggerServerEvent('fivemate-teams:server:acceptInvitation', inviteData.clanId)
        end
    end)
end)

-- Miembro se conectó
RegisterNetEvent('fivemate-teams:client:memberOnline')
AddEventHandler('fivemate-teams:client:memberOnline', function(memberData)
    for i, member in ipairs(ClanMembers) do
        if member.citizenid == memberData.citizenid then
            ClanMembers[i].online = true
            ClanMembers[i].name = memberData.name
            break
        end
    end
end)

-- Miembro se desconectó
RegisterNetEvent('fivemate-teams:client:memberOffline')
AddEventHandler('fivemate-teams:client:memberOffline', function(memberData)
    for i, member in ipairs(ClanMembers) do
        if member.citizenid == memberData.citizenid then
            ClanMembers[i].online = false
            break
        end
    end
end)

-- ================================================
-- FUNCIONES DEL MENÚ
-- ================================================

-- Menú principal de clan
function OpenClanMenu()
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
    local options = {
        {
            title = string.format('Clan: %s [%s]', PlayerClan.name, PlayerClan.tag),
            description = string.format('Tu rol: %s', Config.Roles[PlayerClan.role].label),
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
    if PlayerClan.role == 'leader' or PlayerClan.role == 'sublider' then
        table.insert(options, {
            title = 'Invitar Jugador',
            description = 'Invitar a un jugador cercano',
            icon = 'user-plus',
            onSelect = function()
                InviteNearbyPlayer()
            end
        })
    end
    
    if PlayerClan.role == 'leader' or PlayerClan.role == 'sublider' then
        table.insert(options, {
            title = 'Expulsar Miembro',
            description = 'Expulsar a un miembro del clan',
            icon = 'user-minus',
            onSelect = function()
                OpenKickMenu()
            end
        })
    end
    
    if PlayerClan.role == 'leader' then
        table.insert(options, {
            title = 'Transferir Liderazgo',
            description = 'Transferir el liderazgo a otro miembro',
            icon = 'crown',
            onSelect = function()
                OpenTransferMenu()
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

    lib.registerContext({
        id = 'clan_menu',
        title = 'Gestión de Clan',
        options = options
    })

    lib.showContext('clan_menu')
end

-- Menú de miembros
function OpenMembersMenu()
    TriggerServerEvent('fivemate-teams:server:getClanMembers')
    
    Citizen.Wait(100) -- Esperar a recibir los datos
    
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
    TriggerServerEvent('fivemate-teams:server:getClanMembers')
    
    Citizen.Wait(100)
    
    local options = {}
    
    for _, member in ipairs(ClanMembers) do
        if member.role ~= 'leader' and member.citizenid ~= GetPlayerIdentifier() then
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
    
    -- Obtener todos los jugadores activos
    for _, player in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= playerPed and targetPed ~= 0 then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)
            
            if distance <= 10.0 then -- 10 metros de distancia
                local serverId = GetPlayerServerId(player)
                local playerName = GetPlayerName(player)
                
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
    Citizen.CreateThread(function()
        while true do
            local currentTime = GetGameTimer()
            
            -- Solo actualizar si han pasado suficientes milisegundos
            if currentTime - LastHudUpdate >= HudUpdateInterval then
                UpdateClanHUD()
                LastHudUpdate = currentTime
            end
            
            Citizen.Wait(1000) -- Verificar cada segundo
        end
    end)
end

-- Actualizar datos del HUD
function UpdateClanHUD()
    if not PlayerClan or not Config.HUD.Enabled then
        if IsHudActive then
            IsHudActive = false
            SendNUIMessage({
                action = 'hideHUD'
            })
        end
        return
    end
    
    -- Mostrar HUD si tenemos clan (incluso sin miembros cercanos para info persistente)
    if not IsHudActive then
        IsHudActive = true
        SendNUIMessage({
            action = 'showHUD'
        })
    end
    
    local hudData = {}
    local playerPed = PlayerPedId()
    
    -- Agregar información básica del clan
    table.insert(hudData, {
        name = string.format('Clan: %s [%s]', PlayerClan.name, PlayerClan.tag),
        role = 'info',
        distance = 0,
        health = 100,
        color = '#FFD700',
        isHeader = true
    })
    
    -- Agregar información del jugador actual
    local playerHealth = GetEntityHealth(playerPed)
    local playerMaxHealth = GetEntityMaxHealth(playerPed)
    local playerHealthPercent = math.floor((playerHealth / playerMaxHealth) * 100)
    
    table.insert(hudData, {
        name = 'Tú (' .. Config.Roles[PlayerClan.role].label .. ')',
        role = PlayerClan.role,
        distance = 0,
        health = playerHealthPercent,
        color = Config.Roles[PlayerClan.role].color,
        isSelf = true
    })
    
    -- Agregar miembros del clan online (sin calcular distancia)
    if ClanMembers and #ClanMembers > 0 then
        local onlineMembers = 0
        
        for _, member in ipairs(ClanMembers) do
            if member.online and member.source and member.citizenid ~= GetPlayerIdentifier() then
                local memberPed = GetPlayerPed(GetPlayerFromServerId(member.source))
                if memberPed and memberPed ~= 0 and memberPed ~= playerPed then
                    local health = GetEntityHealth(memberPed)
                    local maxHealth = GetEntityMaxHealth(memberPed)
                    local healthPercent = math.floor((health / maxHealth) * 100)
                    
                    table.insert(hudData, {
                        name = member.name,
                        role = member.role,
                        distance = 0, -- Sin calcular distancia para optimización
                        health = healthPercent,
                        color = Config.Roles[member.role].color
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
                isInfo = true
            })
        end
    else
        table.insert(hudData, {
            name = 'Eres el único miembro',
            role = 'info',
            distance = 0,
            health = 0,
            color = '#888888',
            isInfo = true
        })
    end
    
    -- Solo enviar si los datos han cambiado (optimización)
    local dataString = json.encode(hudData)
    if dataString ~= CachedHudData then
        CachedHudData = dataString
        SendNUIMessage({
            action = 'updateHUD',
            members = hudData
        })
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
            
            local hasTarget, targetPed = GetEntityPlayerIsFreeAimingAt(PlayerPedId())
            
            if hasTarget and targetPed ~= 0 then
                local targetPlayer = NetworkGetPlayerIndexFromPed(targetPed)
                if targetPlayer ~= -1 then
                    local targetServerId = GetPlayerServerId(targetPlayer)
                    
                    -- Verificar si el objetivo es miembro del clan
                    for _, member in ipairs(ClanMembers) do
                        if member.source == targetServerId and member.online then
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
            
            LastFriendlyFireCheck = currentTime
        end
        
        Citizen.Wait(50) -- Verificar cada 50ms en lugar de cada frame
    end
end)

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