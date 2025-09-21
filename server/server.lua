-- ================================================
-- Fivemate Teams - Server Side
-- Sistema de clanes compatible con ESX y QBCore
-- ================================================

local Framework = nil
local Players = {}

-- ================================================
-- INICIALIZACIÓN Y DETECCIÓN DE FRAMEWORK
-- ================================================

Citizen.CreateThread(function()
    -- Detectar framework automáticamente
    if GetResourceState('es_extended') == 'started' then
        Framework = 'ESX'
        ESX = exports['es_extended']:getSharedObject()
        print('^2[Fivemate-Teams]^7 ESX Framework detectado')
    elseif GetResourceState('qb-core') == 'started' then
        Framework = 'QBCore'
        QBCore = exports['qb-core']:GetCoreObject()
        print('^2[Fivemate-Teams]^7 QBCore Framework detectado')
    else
        print('^1[Fivemate-Teams]^7 ¡ERROR! No se detectó ningún framework compatible (ESX/QBCore)')
        return
    end
    
    Config.Framework = Framework
    
    -- Esperar un poco para que todo se inicialice
    Citizen.Wait(2000)
    
    -- Inicializar todos los jugadores ya conectados
    InitializeAllPlayers()
end)

-- Función para inicializar todos los jugadores conectados
function InitializeAllPlayers()
    local players = GetPlayers()
    print(string.format('^2[Fivemate-Teams]^7 Inicializando %d jugadores conectados...', #players))
    
    for _, playerId in ipairs(players) do
        local source = tonumber(playerId)
        if source then
            InitializePlayer(source)
            if Players[source] and Players[source].clan then
                TriggerClientEvent('fivemate-teams:client:updateClanData', source, Players[source].clan)
            end
        end
    end
    
    print('^2[Fivemate-Teams]^7 Inicialización de jugadores completada')
end

-- ================================================
-- FUNCIONES UTILITARIAS
-- ================================================

-- Obtener identificador del jugador según framework
function GetPlayerIdentifier(source)
    if Framework == 'ESX' then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or nil
    elseif Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(source)
        return Player and Player.PlayerData.citizenid or nil
    end
    return nil
end

-- Obtener nombre del jugador según framework
function GetPlayerName(source)
    if Framework == 'ESX' then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.getName() or 'Desconocido'
    elseif Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(source)
        return Player and Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname or 'Desconocido'
    end
    return 'Desconocido'
end

-- Enviar notificación al jugador
function SendNotification(source, message, type)
    type = type or 'success'
    
    if Config.Notifications.Type == 'ox_lib' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan System',
            description = message,
            type = type,
            duration = Config.Notifications.Duration
        })
    elseif Config.Notifications.Type == 'esx' and Framework == 'ESX' then
        TriggerClientEvent('esx:showNotification', source, message)
    elseif Config.Notifications.Type == 'qb' and Framework == 'QBCore' then
        TriggerClientEvent('QBCore:Notify', source, message, type)
    else
        -- Fallback a chat
        TriggerClientEvent('chat:addMessage', source, {
            color = type == 'error' and {255, 0, 0} or {0, 255, 0},
            multiline = true,
            args = {'[Clan]', message}
        })
    end
end

-- ================================================
-- FUNCIONES DE BASE DE DATOS CON CACHÉ
-- ================================================

-- Sistema de caché para reducir consultas a la base de datos
local ClanCache = {}
local MemberCache = {}
local ClanNameCache = {}
local CacheLifetime = 60000 -- 60 segundos en milisegundos

-- Limpiar caché periódicamente
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- Limpiar cada 5 minutos
        
        -- Limpiar caches que hayan expirado
        local currentTime = GetGameTimer()
        for id, data in pairs(ClanCache) do
            if currentTime - data.timestamp > CacheLifetime then
                ClanCache[id] = nil
            end
        end
        
        for id, data in pairs(MemberCache) do
            if currentTime - data.timestamp > CacheLifetime then
                MemberCache[id] = nil
            end
        end
        
        for name, data in pairs(ClanNameCache) do
            if currentTime - data.timestamp > CacheLifetime then
                ClanNameCache[name] = nil
            end
        end
        
        if Config.Debug then
            print(string.format("^3[Fivemate-Teams]^7 Caché limpiada - Clanes: %d, Miembros: %d, Nombres: %d", 
                tablelength(ClanCache), tablelength(MemberCache), tablelength(ClanNameCache)))
        end
    end
end)

-- Función auxiliar para contar elementos en una tabla
function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- Verificar si un jugador tiene clan (con caché)
function GetPlayerClan(citizenid)
    if not citizenid then return nil end
    
    -- Verificar si está en caché
    if ClanCache[citizenid] and GetGameTimer() - ClanCache[citizenid].timestamp < CacheLifetime then
        return ClanCache[citizenid].data
    end
    
    -- No está en caché o expiró, consultar base de datos
    -- Optimización de consulta: uso de LEFT JOIN en lugar de JOIN para evitar errores si no hay coincidencia
    local query = [[
        SELECT c.*, cm.role 
        FROM clans c 
        LEFT JOIN clan_members cm ON c.id = cm.clan_id 
        WHERE cm.citizenid = ?
    ]]
    
    local result = MySQL.Sync.fetchAll(query, {citizenid})
    local clanData = result[1] or nil
    
    -- Guardar en caché
    ClanCache[citizenid] = {
        data = clanData,
        timestamp = GetGameTimer()
    }
    
    return clanData
end

-- Obtener miembros de un clan (con caché)
function GetClanMembers(clanId)
    if not clanId then return {} end
    
    -- Verificar si está en caché
    if MemberCache[clanId] and GetGameTimer() - MemberCache[clanId].timestamp < CacheLifetime then
        return MemberCache[clanId].data
    end
    
    -- No está en caché o expiró, consultar base de datos
    -- Consulta optimizada para obtener solo los datos necesarios
    local query = [[
        SELECT cm.citizenid, cm.role, c.name as clan_name
        FROM clan_members cm 
        JOIN clans c ON cm.clan_id = c.id 
        WHERE cm.clan_id = ?
    ]]
    
    local result = MySQL.Sync.fetchAll(query, {clanId})
    
    -- Guardar en caché
    MemberCache[clanId] = {
        data = result or {},
        timestamp = GetGameTimer()
    }
    
    return result or {}
end

-- Verificar si un nombre/tag de clan está disponible (con caché)
function IsClanNameAvailable(name, tag)
    -- Verificar si los nombres están en caché
    local currentTime = GetGameTimer()
    local nameKey = "name:" .. string.lower(name)
    local tagKey = "tag:" .. string.lower(tag)
    
    local nameAvailable = true
    local tagAvailable = true
    
    -- Verificar caché para el nombre
    if ClanNameCache[nameKey] and currentTime - ClanNameCache[nameKey].timestamp < CacheLifetime then
        nameAvailable = ClanNameCache[nameKey].available
    else
        -- Consultar base de datos para el nombre
        local nameCheck = MySQL.Sync.fetchScalar('SELECT COUNT(*) FROM clans WHERE LOWER(name) = ?', {string.lower(name)})
        nameAvailable = (nameCheck == 0)
        
        -- Guardar en caché
        ClanNameCache[nameKey] = {
            available = nameAvailable,
            timestamp = currentTime
        }
    end
    
    -- Verificar caché para el tag
    if ClanNameCache[tagKey] and currentTime - ClanNameCache[tagKey].timestamp < CacheLifetime then
        tagAvailable = ClanNameCache[tagKey].available
    else
        -- Consultar base de datos para el tag
        local tagCheck = MySQL.Sync.fetchScalar('SELECT COUNT(*) FROM clans WHERE LOWER(tag) = ?', {string.lower(tag)})
        tagAvailable = (tagCheck == 0)
        
        -- Guardar en caché
        ClanNameCache[tagKey] = {
            available = tagAvailable,
            timestamp = currentTime
        }
    end
    
    return nameAvailable, tagAvailable
end

-- Invalidar caché cuando hay cambios
function InvalidateCache(type, id)
    if type == 'clan' and id then
        ClanCache[id] = nil
        MemberCache[id] = nil
    elseif type == 'player' and id then
        ClanCache[id] = nil
    elseif type == 'all' then
        ClanCache = {}
        MemberCache = {}
        ClanNameCache = {}
    end
end

-- ================================================
-- EVENTOS DEL SERVIDOR
-- ================================================

-- Evento para limpiar recursos cuando se detiene el script
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    
    if Config.Debug then
        print("^2[Fivemate-Teams]^7 Deteniendo recurso - Limpiando memoria...")
    end
    
    -- Notificar a todos los clientes para que limpien sus datos
    TriggerClientEvent('fivemate-teams:client:cleanupResource', -1)
    
    -- Limpiar la tabla de jugadores
    local playerCount = 0
    for source, _ in pairs(Players) do
        CleanupPlayer(source)
        playerCount = playerCount + 1
    end
    
    -- Limpiar event handlers
    CleanupEventHandlers()
    
    -- Forzar recolección de basura
    collectgarbage("collect")
    
    if Config.Debug then
        print(string.format("^2[Fivemate-Teams]^7 Memoria limpiada correctamente: %d jugadores eliminados", playerCount))
    end
end)

-- Inicializar jugador cuando se conecta
AddEventHandler('playerJoining', function()
    local source = source
    
    -- Usar Citizen.CreateThread para retrasar un poco la inicialización y asegurar que los datos están disponibles
    Citizen.CreateThread(function()
        -- Pequeño retraso para asegurar que el jugador está completamente conectado
        Citizen.Wait(1000)
        
        -- Verificar que el jugador sigue conectado después del retraso
        if not GetPlayerName(source) then
            if Config.Debug then
                print(string.format("^3[Fivemate-Teams]^7 Advertencia: El jugador %s se desconectó durante la inicialización", source))
            end
            return
        end
        
        -- Inicializar jugador de forma segura
        local player = InitializePlayer(source)
        if not player then
            if Config.Debug then
                print(string.format("^1[Fivemate-Teams]^7 Error: No se pudo inicializar al jugador %s", source))
            end
            return
        end
        
        -- Enviar información del clan al cliente
        if player.clan then
            TriggerClientEvent('fivemate-teams:client:updateClanData', source, player.clan)
            
            -- Notificar a otros miembros que este jugador se conectó
            local members = GetClanMembers(player.clan.id)
            if members and #members > 0 then
                for _, member in pairs(members) do
                    local memberSource = GetPlayerFromCitizenId(member.citizenid)
                    if memberSource and memberSource ~= source and Players[memberSource] then
                        TriggerClientEvent('fivemate-teams:client:memberOnline', memberSource, {
                            citizenid = player.citizenid,
                            name = player.name
                        })
                    end
                end
            end
        end
        
        if Config.Debug then
            print(string.format("^2[Fivemate-Teams]^7 Jugador %s completamente inicializado", source))
        end
    end)
end)

-- Evento cuando un jugador se desconecta
AddEventHandler('playerDropped', function(reason)
    local source = source
    
    -- Verificar que el jugador está en la tabla Players
    if not Players[source] then
        return
    end
    
    if Config.Debug then
        print(string.format("^3[Fivemate-Teams]^7 Jugador %s desconectado (%s)", source, reason or "Desconocido"))
    end
    
    -- Guardar temporalmente los datos del jugador para las notificaciones
    local playerData = {
        citizenid = Players[source].citizenid,
        name = Players[source].name,
        clan = Players[source].clan
    }
    
    -- Notificar a otros miembros que este jugador se desconectó
    if playerData.clan then
        -- Ejecutar en un hilo para evitar bloqueos
        Citizen.CreateThread(function()
            local members = GetClanMembers(playerData.clan.id)
            if members and #members > 0 then
                for _, member in pairs(members) do
                    local memberSource = GetPlayerFromCitizenId(member.citizenid)
                    if memberSource and memberSource ~= source and Players[memberSource] then
                        TriggerClientEvent('fivemate-teams:client:memberOffline', memberSource, {
                            citizenid = playerData.citizenid,
                            name = playerData.name
                        })
                    end
                end
            end
        end)
    end
    
    -- Limpiar datos del jugador para evitar memory leaks
    Players[source] = nil
    
    -- Forzar recolección de basura (GC) periódicamente para evitar memory leaks
    if #GetPlayers() % 10 == 0 then  -- Cada 10 desconexiones (menos frecuente para reducir impacto)
        collectgarbage("collect")
    end
end)

-- ================================================
-- EVENTOS DE CLAN
-- ================================================

-- Crear clan
RegisterNetEvent('fivemate-teams:server:createClan')
AddEventHandler('fivemate-teams:server:createClan', function(clanData)
    local source = source
    local player = InitializePlayer(source)
    
    if not player then
        SendNotification(source, 'Error al obtener datos del jugador', 'error')
        return
    end
    
    -- Verificar si el jugador ya tiene clan
    if GetPlayerClan(player.citizenid) then
        SendNotification(source, Config.Messages.Error.AlreadyInClan, 'error')
        return
    end
    
    -- Validar datos
    if not clanData.name or #clanData.name < Config.Clan.MinNameLength or #clanData.name > Config.Clan.MaxNameLength then
        SendNotification(source, string.format(Config.Messages.Error.InvalidName, Config.Clan.MinNameLength, Config.Clan.MaxNameLength), 'error')
        return
    end
    
    if not clanData.tag or #clanData.tag < Config.Clan.MinTagLength or #clanData.tag > Config.Clan.MaxTagLength then
        SendNotification(source, string.format(Config.Messages.Error.InvalidTag, Config.Clan.MinTagLength, Config.Clan.MaxTagLength), 'error')
        return
    end
    
    -- Verificar disponibilidad
    local nameAvailable, tagAvailable = IsClanNameAvailable(clanData.name, clanData.tag)
    
    if not nameAvailable then
        SendNotification(source, Config.Messages.Error.ClanNameTaken, 'error')
        return
    end
    
    if not tagAvailable then
        SendNotification(source, Config.Messages.Error.ClanTagTaken, 'error')
        return
    end
    
    -- Crear clan
    local clanId = MySQL.Sync.insert('INSERT INTO clans (name, tag, leader) VALUES (?, ?, ?)', {
        clanData.name, clanData.tag, player.citizenid
    })
    
    if clanId then
        -- Agregar jugador como líder
        MySQL.Sync.insert('INSERT INTO clan_members (clan_id, citizenid, role) VALUES (?, ?, ?)', {
            clanId, player.citizenid, 'leader'
        })
        
        -- Actualizar datos del jugador
        Players[source].clan = {
            id = clanId,
            name = clanData.name,
            tag = clanData.tag,
            leader = player.citizenid,
            role = 'leader'
        }
        
        -- Invalidar caché
        InvalidateCache('player', player.citizenid)
        InvalidateCache('clan', clanId)
        
        -- Actualizar caché de nombres
        local nameKey = "name:" .. string.lower(clanData.name)
        local tagKey = "tag:" .. string.lower(clanData.tag)
        ClanNameCache[nameKey] = { available = false, timestamp = GetGameTimer() }
        ClanNameCache[tagKey] = { available = false, timestamp = GetGameTimer() }
        
        SendNotification(source, Config.Messages.Success.ClanCreated, 'success')
        TriggerClientEvent('fivemate-teams:client:updateClanData', source, Players[source].clan)
        
        if Config.Debug then
            print(string.format('^2[Fivemate-Teams]^7 Clan "%s" creado por %s', clanData.name, GetPlayerName(source)))
        end
    else
        SendNotification(source, 'Error al crear el clan', 'error')
    end
end)

-- Obtener datos del clan del jugador
RegisterNetEvent('fivemate-teams:server:getClanData')
AddEventHandler('fivemate-teams:server:getClanData', function()
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    
    if not citizenid then return end
    
    local clan = GetPlayerClan(citizenid)
    TriggerClientEvent('fivemate-teams:client:receiveClanData', source, clan)
end)

-- Sistema de notificación optimizado para miembros del clan
function NotifyClanMembers(clanId, eventName, data, excludeSource)
    if not clanId or not eventName or not data then
        if Config.Debug then
            print("^1[Fivemate-Teams]^7 Error: Datos incompletos en NotifyClanMembers")
        end
        return
    end
    
    -- Ejecutar en un hilo separado para no bloquear
    Citizen.CreateThread(function()
        local members = GetClanMembers(clanId)
        if not members or #members == 0 then
            if Config.Debug then
                print(string.format("^3[Fivemate-Teams]^7 No hay miembros en el clan %s para notificar", clanId))
            end
            return
        end
        
        local notifiedCount = 0
        for _, member in pairs(members) do
            -- Verificar que el miembro tenga un citizenid válido
            if member and member.citizenid then
                local memberSource = GetPlayerFromCitizenId(member.citizenid)
                
                -- Verificar que el jugador esté online y no sea el que se excluye
                if memberSource and memberSource ~= excludeSource and Players[memberSource] then
                    TriggerClientEvent(eventName, memberSource, data)
                    notifiedCount = notifiedCount + 1
                    
                    -- Pequeña pausa cada 5 notificaciones para evitar sobrecarga
                    if notifiedCount % 5 == 0 then
                        Citizen.Wait(50)
                    end
                end
            end
        end
        
        if Config.Debug then
            print(string.format("^2[Fivemate-Teams]^7 Notificados %d miembros del clan %s", notifiedCount, clanId))
        end
    end)
end

-- Obtener miembros del clan
RegisterNetEvent('fivemate-teams:server:getClanMembers')
AddEventHandler('fivemate-teams:server:getClanMembers', function()
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    
    if not citizenid then return end
    
    -- Asegurar que el jugador esté en la tabla Players
    if not Players[source] then
        Players[source] = {
            citizenid = citizenid,
            name = GetPlayerName(source),
            clan = GetPlayerClan(citizenid)
        }
    end
    
    if not Players[source].clan then
        SendNotification(source, Config.Messages.Error.NotInClan, 'error')
        return
    end
    
    local members = GetClanMembers(Players[source].clan.id)
    local memberList = {}
    
    for _, member in pairs(members) do
        local memberSource = GetPlayerFromCitizenId(member.citizenid)
        local memberName = memberSource and GetPlayerName(memberSource) or 'Desconocido'
        
        table.insert(memberList, {
            citizenid = member.citizenid,
            name = memberName,
            role = member.role,
            online = memberSource ~= nil,
            source = memberSource
        })
    end
    
    TriggerClientEvent('fivemate-teams:client:receiveClanMembers', source, memberList)
end)

-- Invitar jugador al clan
RegisterNetEvent('fivemate-teams:server:invitePlayer')
AddEventHandler('fivemate-teams:server:invitePlayer', function(targetId)
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    
    if not citizenid then 
        SendNotification(source, 'Error al obtener tu identificador', 'error')
        return 
    end
    
    -- Asegurar que el jugador esté en la tabla Players
    if not Players[source] then
        local player = InitializePlayer(source)
        if not player then
            SendNotification(source, 'Error al inicializar tus datos', 'error')
            return
        end
    end
    
    if not Players[source].clan then
        SendNotification(source, Config.Messages.Error.NotInClan, 'error')
        return
    end
    
    -- Verificar permisos
    if not (Players[source].clan.role == 'leader' or Players[source].clan.role == 'sublider') then
        SendNotification(source, Config.Messages.Error.NoPermission, 'error')
        return
    end
    
    -- Verificar que el jugador objetivo existe y está conectado
    local targetPed = GetPlayerPed(targetId)
    if targetPed == 0 then
        SendNotification(source, Config.Messages.Error.PlayerNotFound, 'error')
        return
    end
    
    -- Asegurar que el jugador objetivo esté en la tabla Players
    local targetPlayer = InitializePlayer(targetId)
    if not targetPlayer then
        SendNotification(source, 'No se pudo inicializar al jugador objetivo', 'error')
        return
    end
    
    local targetCitizenId = targetPlayer.citizenid
    if not targetCitizenId then
        SendNotification(source, Config.Messages.Error.PlayerNotFound, 'error')
        return
    end
    
    -- Verificar si el jugador ya tiene clan
    if targetPlayer.clan then
        SendNotification(source, Config.Messages.Error.PlayerAlreadyInClan, 'error')
        return
    end
    
    -- Verificar límite de miembros
    local members = GetClanMembers(Players[source].clan.id)
    if members and #members >= Config.Clan.MaxMembers then
        SendNotification(source, Config.Messages.Error.MaxMembersReached, 'error')
        return
    end
    
    -- Enviar invitación de forma asíncrona para evitar timeouts
    Citizen.CreateThread(function()
        -- Crear un ID único para esta invitación para evitar duplicados
        local invitationId = string.format("%s_%s_%s", 
            Players[source].clan.id, 
            citizenid, 
            targetCitizenId)
        
        -- Datos de la invitación
        local invitationData = {
            id = invitationId,
            clanId = Players[source].clan.id,
            clanName = Players[source].clan.name,
            clanTag = Players[source].clan.tag,
            inviterId = citizenid,
            inviterName = GetPlayerName(source),
            timestamp = os.time()
        }
        
        -- Enviar invitación al jugador objetivo
        TriggerClientEvent('fivemate-teams:client:receiveInvitation', targetId, invitationData)
        
        -- Enviar notificaciones
        SendNotification(source, Config.Messages.Success.PlayerInvited, 'success')
        SendNotification(targetId, string.format('Has recibido una invitación al clan %s de %s', 
            invitationData.clanName, invitationData.inviterName), 'info')
        
        if Config.Debug then
            print(string.format("^2[Fivemate-Teams]^7 Invitación enviada de %s a %s para unirse a %s", 
                invitationData.inviterName, GetPlayerName(targetId), invitationData.clanName))
        end
    end)
end)

-- Aceptar invitación
RegisterNetEvent('fivemate-teams:server:acceptInvitation')
AddEventHandler('fivemate-teams:server:acceptInvitation', function(invitationData)
    local source = source
    
    -- Validar que recibimos datos válidos
    if not invitationData or not invitationData.id or not invitationData.clanId then
        SendNotification(source, 'Datos de invitación inválidos', 'error')
        return
    end
    
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then
        SendNotification(source, 'Error al obtener tu identificador', 'error')
        return
    end
    
    -- Verificar si el jugador ya tiene clan
    local existingClan = GetPlayerClan(citizenid)
    if existingClan then
        SendNotification(source, Config.Messages.Error.AlreadyInClan, 'error')
        return
    end
    
    -- Verificar que el clan existe
    local clanId = invitationData.clanId
    local clanExists = MySQL.Sync.fetchScalar('SELECT COUNT(*) FROM clans WHERE id = ?', {clanId})
    
    if not clanExists or clanExists == 0 then
        SendNotification(source, 'El clan ya no existe', 'error')
        return
    end
    
    -- Verificar límite de miembros
    local memberCount = MySQL.Sync.fetchScalar('SELECT COUNT(*) FROM clan_members WHERE clan_id = ?', {clanId})
    if memberCount and memberCount >= Config.Clan.MaxMembers then
        SendNotification(source, Config.Messages.Error.MaxMembersReached, 'error')
        return
    end
    
    -- Agregar al clan
    local success = MySQL.Sync.insert('INSERT INTO clan_members (clan_id, citizenid, role) VALUES (?, ?, ?)', {
        clanId, citizenid, 'member'
    })
    
    if success then
        -- Actualizar datos del jugador
        local clan = MySQL.Sync.fetchAll('SELECT * FROM clans WHERE id = ?', {clanId})[1]
        if not clan then
            SendNotification(source, 'Error al obtener datos del clan', 'error')
            return
        end
        
        -- Inicializar jugador si es necesario
        InitializePlayer(source)
        
        -- Actualizar datos del clan en la memoria
        Players[source].clan = {
            id = clan.id,
            name = clan.name,
            tag = clan.tag,
            leader = clan.leader,
            role = 'member'
        }
        
        -- Enviar notificación al jugador
        SendNotification(source, string.format('Te has unido al clan %s!', clan.name), 'success')
        
        -- Actualizar datos del cliente
        TriggerClientEvent('fivemate-teams:client:updateClanData', source, Players[source].clan)
        
        -- Notificar a otros miembros usando nuestro nuevo sistema de notificación
        NotifyClanMembers(clanId, 'fivemate-teams:client:memberJoined', {
            citizenid = citizenid,
            name = GetPlayerName(source),
            message = string.format('%s se ha unido al clan', GetPlayerName(source))
        }, source)
        
        if Config.Debug then
            print(string.format("^2[Fivemate-Teams]^7 %s se ha unido al clan %s [%s]", 
                GetPlayerName(source), clan.name, clan.tag))
        end
    else
        SendNotification(source, 'Error al unirse al clan', 'error')
    end
end)

-- Expulsar jugador del clan
RegisterNetEvent('fivemate-teams:server:kickPlayer')
AddEventHandler('fivemate-teams:server:kickPlayer', function(targetCitizenId)
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    
    if not Players[source] or not Players[source].clan then
        SendNotification(source, Config.Messages.Error.NotInClan, 'error')
        return
    end
    
    -- Verificar permisos
    if not (Players[source].clan.role == 'leader' or Players[source].clan.role == 'sublider') then
        SendNotification(source, Config.Messages.Error.NoPermission, 'error')
        return
    end
    
    -- No puede expulsarse a sí mismo
    if targetCitizenId == citizenid then
        SendNotification(source, Config.Messages.Error.CantKickYourself, 'error')
        return
    end
    
    local clanId = Players[source].clan.id
    
    -- Expulsar del clan
    local affected = MySQL.Sync.execute('DELETE FROM clan_members WHERE clan_id = ? AND citizenid = ?', {
        clanId, targetCitizenId
    })
    
    if affected > 0 then
        -- Invalidar caché
        InvalidateCache('player', targetCitizenId)
        InvalidateCache('clan', clanId)
        
        SendNotification(source, Config.Messages.Success.PlayerKicked, 'success')
        
        -- Notificar al jugador expulsado si está online
        local targetSource = GetPlayerFromCitizenId(targetCitizenId)
        if targetSource then
            Players[targetSource].clan = nil
            SendNotification(targetSource, 'Has sido expulsado del clan', 'error')
            TriggerClientEvent('fivemate-teams:client:updateClanData', targetSource, nil)
        end
        
        -- Notificar a otros miembros
        NotifyClanMembers(clanId, 'fivemate-teams:client:memberRemoved', {
            citizenid = targetCitizenId,
            message = 'Un miembro ha sido expulsado del clan'
        }, targetSource)
    else
        SendNotification(source, 'No se pudo expulsar al jugador', 'error')
    end
end)

-- Salir del clan
RegisterNetEvent('fivemate-teams:server:leaveClan')
AddEventHandler('fivemate-teams:server:leaveClan', function()
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    
    if not Players[source] or not Players[source].clan then
        SendNotification(source, Config.Messages.Error.NotInClan, 'error')
        return
    end
    
    local clanId = Players[source].clan.id
    local isLeader = Players[source].clan.role == 'leader'
    
    -- Si es líder, debe transferir el liderazgo primero
    if isLeader then
        local members = GetClanMembers(clanId)
        local otherMembers = 0
        
        for _, member in pairs(members) do
            if member.citizenid ~= citizenid then
                otherMembers = otherMembers + 1
            end
        end
        
        if otherMembers > 0 then
            SendNotification(source, 'Debes transferir el liderazgo antes de salir del clan', 'error')
            return
        else
            -- Es el único miembro, eliminar el clan
            MySQL.Sync.execute('DELETE FROM clans WHERE id = ?', {clanId})
            
            -- Invalidar caché
            InvalidateCache('all')
        end
    else
        -- Salir del clan
        MySQL.Sync.execute('DELETE FROM clan_members WHERE clan_id = ? AND citizenid = ?', {
            clanId, citizenid
        })
        
        -- Invalidar caché
        InvalidateCache('player', citizenid)
        InvalidateCache('clan', clanId)
        
        -- Notificar a otros miembros
        NotifyClanMembers(clanId, 'fivemate-teams:client:memberLeft', {
            citizenid = citizenid,
            name = GetPlayerName(source),
            message = string.format('%s ha abandonado el clan', GetPlayerName(source))
        }, source)
    end
    
    Players[source].clan = nil
    SendNotification(source, Config.Messages.Success.LeftClan, 'success')
    TriggerClientEvent('fivemate-teams:client:updateClanData', source, nil)
end)


-- Eliminar clan
RegisterNetEvent('fivemate-teams:server:deleteClan')
AddEventHandler('fivemate-teams:server:deleteClan', function()
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    
    -- Verificar que el jugador pertenece a un clan
    if not Players[source] or not Players[source].clan then
        SendNotification(source, Config.Messages.Error.NotInClan, 'error')
        return
    end
    
    local clanId = Players[source].clan.id
    local clanName = Players[source].clan.name
    local clanTag = Players[source].clan.tag
    
    -- Verificar que el jugador es el líder del clan
    if Players[source].clan.role ~= 'leader' then
        SendNotification(source, Config.Messages.Error.CantDeleteClan, 'error')
        return
    end
    
    -- Obtener todos los miembros del clan
    local members = GetClanMembers(clanId)
    
    -- Obtener sources de todos los miembros online para notificaciones
    local onlineMembers = {}
    for _, member in pairs(members) do
        if member.citizenid ~= citizenid then
            local memberSource = GetPlayerFromCitizenId(member.citizenid)
            if memberSource then
                table.insert(onlineMembers, memberSource)
                -- Actualizar datos del jugador
                Players[memberSource].clan = nil
            end
        end
    end
    
    -- Eliminar todos los miembros del clan
    MySQL.Sync.execute('DELETE FROM clan_members WHERE clan_id = ?', {clanId})
    
    -- Eliminar el clan
    MySQL.Sync.execute('DELETE FROM clans WHERE id = ?', {clanId})
    
    -- Invalidar caché
    InvalidateCache('all')
    
    -- Notificar a todos los miembros online
    for _, memberSource in ipairs(onlineMembers) do
        -- Enviar notificación
        SendNotification(memberSource, string.format('El clan %s [%s] ha sido eliminado por el líder', clanName, clanTag), 'error')
        -- Actualizar datos del cliente
        TriggerClientEvent('fivemate-teams:client:updateClanData', memberSource, nil)
    end
    
    -- Notificar al líder
    Players[source].clan = nil
    SendNotification(source, Config.Messages.Success.ClanDeleted, 'success')
    TriggerClientEvent('fivemate-teams:client:updateClanData', source, nil)
end)

-- ================================================
-- FUNCIONES AUXILIARES
-- ================================================

-- Inicializar jugador en la tabla Players si no existe
function InitializePlayer(source)
    if not source then return nil end
    
    -- Si el jugador ya está inicializado, devolver los datos existentes
    if Players[source] then
        return Players[source]
    end
    
    -- Obtener identificador del jugador
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then
        if Config.Debug then
            print(string.format("^1[Fivemate-Teams]^7 Error: No se pudo obtener citizenid para el jugador %s", source))
        end
        return nil
    end
    
    -- Obtener datos del clan de forma segura
    local clanData = GetPlayerClan(citizenid)
    
    -- Crear entrada en la tabla Players
    Players[source] = {
        citizenid = citizenid,
        name = GetPlayerName(source),
        clan = clanData
    }
    
    if Config.Debug then
        print(string.format("^2[Fivemate-Teams]^7 Jugador %s inicializado correctamente (Clan: %s)", 
            source, clanData and clanData.name or "Ninguno"))
    end
    
    return Players[source]
end

-- Función para limpiar un jugador de forma segura
function CleanupPlayer(source)
    if not Players[source] then return end
    
    if Config.Debug then
        print(string.format("^3[Fivemate-Teams]^7 Limpiando datos del jugador %s", source))
    end
    
    -- Guardar datos temporalmente para notificaciones
    local tempData = {
        citizenid = Players[source].citizenid,
        name = Players[source].name,
        clan = Players[source].clan
    }
    
    -- Eliminar de la tabla
    Players[source] = nil
    
    return tempData
end

-- Función para registrar event handlers de forma limpia
local registeredHandlers = {}

function RegisterSafeEventHandler(eventName, callback)
    local handler = AddEventHandler(eventName, callback)
    table.insert(registeredHandlers, handler)
    return handler
end

-- Función para limpiar todos los event handlers registrados
function CleanupEventHandlers()
    for _, handler in ipairs(registeredHandlers) do
        RemoveEventHandler(handler)
    end
    registeredHandlers = {}
end

-- Obtener source del jugador por citizenid
function GetPlayerFromCitizenId(citizenid)
    if not citizenid then return nil end
    
    -- Iterar sobre la tabla Players para encontrar el jugador
    for source, data in pairs(Players) do
        if data and data.citizenid and data.citizenid == citizenid then
            -- Verificar que el jugador sigue conectado
            if GetPlayerPing(source) > 0 then
                return source
            end
        end
    end
    
    -- Si no se encuentra en la tabla Players, buscar por todos los jugadores conectados
    -- Esto es útil en caso de que la tabla Players no esté sincronizada correctamente
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local source = tonumber(playerId)
        if source then
            local currentCitizenId = GetPlayerIdentifier(source)
            if currentCitizenId and currentCitizenId == citizenid then
                -- Actualizar la tabla Players si no está actualizada
                if not Players[source] or Players[source].citizenid ~= citizenid then
                    InitializePlayer(source)
                end
                return source
            end
        end
    end
    
    return nil
end

-- ================================================
-- EVENTOS ADICIONALES PARA COMPATIBILIDAD
-- ================================================

-- Evento para cuando un jugador está completamente cargado (ESX)
if Framework == 'ESX' then
    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(source, xPlayer)
        local citizenid = xPlayer.identifier
        
        Players[source] = {
            citizenid = citizenid,
            name = xPlayer.getName(),
            clan = GetPlayerClan(citizenid)
        }
        
        -- Enviar información del clan al cliente
        if Players[source].clan then
            TriggerClientEvent('fivemate-teams:client:updateClanData', source, Players[source].clan)
        end
    end)
end

-- Evento para cuando un jugador está completamente cargado (QBCore)
if Framework == 'QBCore' then
    RegisterNetEvent('QBCore:Server:PlayerLoaded')
    AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
        local source = Player.PlayerData.source
        local citizenid = Player.PlayerData.citizenid
        
        Players[source] = {
            citizenid = citizenid,
            name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
            clan = GetPlayerClan(citizenid)
        }
        
        -- Enviar información del clan al cliente
        if Players[source].clan then
            TriggerClientEvent('fivemate-teams:client:updateClanData', source, Players[source].clan)
        end
    end)
end

-- ================================================
-- COMANDOS
-- ================================================

-- Comando para información del clan
RegisterCommand(Config.Commands.ClanInfo, function(source)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return end
    
    local clan = GetPlayerClan(citizenid)
    if clan then
        SendNotification(source, string.format('Clan: %s [%s] | Rol: %s', clan.name, clan.tag, Config.Roles[clan.role].label), 'info')
    else
        SendNotification(source, Config.Messages.Error.NotInClan, 'error')
    end
end)

-- Comando de debug para inicializar jugadores (solo si debug está activado)
if Config.Debug then
    RegisterCommand('clan_debug_init', function(source)
        if source == 0 then -- Solo desde consola del servidor
            InitializeAllPlayers()
            print('^2[Fivemate-Teams]^7 Debug: Jugadores re-inicializados')
        end
    end)
    
    RegisterCommand('clan_debug_players', function(source)
        if source == 0 then -- Solo desde consola del servidor
            print('^2[Fivemate-Teams]^7 Jugadores en memoria:')
            for playerId, data in pairs(Players) do
                print(string.format('^3ID: %s^7 | ^3Ciudadano: %s^7 | ^3Nombre: %s^7 | ^3Clan: %s^7', 
                    playerId, data.citizenid, data.name, data.clan and data.clan.name or 'Sin clan'))
            end
        end
    end)
end

-- Rechazar invitación
RegisterNetEvent('fivemate-teams:server:rejectInvitation')
AddEventHandler('fivemate-teams:server:rejectInvitation', function(invitationData)
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    
    if not citizenid or not invitationData or not invitationData.inviterId then
        return
    end
    
    -- Notificar al invitador que la invitación fue rechazada
    local inviterSource = GetPlayerFromCitizenId(invitationData.inviterId)
    if inviterSource then
        SendNotification(inviterSource, string.format('%s ha rechazado tu invitación al clan', GetPlayerName(source)), 'info')
        
        if Config.Debug then
            print(string.format("^3[Fivemate-Teams]^7 %s rechazó la invitación al clan %s de %s", 
                GetPlayerName(source), invitationData.clanName, invitationData.inviterName))
        end
    end
end)

-- Export para otros recursos
exports('GetPlayerClan', GetPlayerClan)
exports('GetClanMembers', GetClanMembers)

if Config.Debug then
    print('^2[Fivemate-Teams]^7 Sistema de clanes cargado correctamente')
end