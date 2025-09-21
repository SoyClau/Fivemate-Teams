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
-- FUNCIONES DE BASE DE DATOS
-- ================================================

-- Verificar si un jugador tiene clan
function GetPlayerClan(citizenid)
    if not citizenid then return nil end
    
    local result = MySQL.Sync.fetchAll('SELECT c.*, cm.role FROM clans c JOIN clan_members cm ON c.id = cm.clan_id WHERE cm.citizenid = ?', {citizenid})
    return result[1] or nil
end

-- Obtener miembros de un clan
function GetClanMembers(clanId)
    if not clanId then return {} end
    
    local result = MySQL.Sync.fetchAll('SELECT cm.*, c.name as clan_name FROM clan_members cm JOIN clans c ON cm.clan_id = c.id WHERE cm.clan_id = ?', {clanId})
    return result or {}
end

-- Verificar si un nombre/tag de clan está disponible
function IsClanNameAvailable(name, tag)
    local nameCheck = MySQL.Sync.fetchAll('SELECT id FROM clans WHERE name = ?', {name})
    local tagCheck = MySQL.Sync.fetchAll('SELECT id FROM clans WHERE tag = ?', {tag})
    
    return #nameCheck == 0, #tagCheck == 0
end

-- ================================================
-- EVENTOS DEL SERVIDOR
-- ================================================

-- Inicializar jugador cuando se conecta
AddEventHandler('playerJoining', function()
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    
    if citizenid then
        Players[source] = {
            citizenid = citizenid,
            name = GetPlayerName(source),
            clan = GetPlayerClan(citizenid)
        }
        
        -- Enviar información del clan al cliente
        if Players[source].clan then
            TriggerClientEvent('fivemate-teams:client:updateClanData', source, Players[source].clan)
            
            -- Notificar a otros miembros que este jugador se conectó
            local members = GetClanMembers(Players[source].clan.id)
            for _, member in pairs(members) do
                local memberSource = GetPlayerFromCitizenId(member.citizenid)
                if memberSource and memberSource ~= source then
                    TriggerClientEvent('fivemate-teams:client:memberOnline', memberSource, {
                        citizenid = citizenid,
                        name = Players[source].name
                    })
                end
            end
        end
    end
end)

-- Evento cuando un jugador se desconecta
AddEventHandler('playerDropped', function()
    local source = source
    
    if Players[source] and Players[source].clan then
        -- Notificar a otros miembros que este jugador se desconectó
        local members = GetClanMembers(Players[source].clan.id)
        for _, member in pairs(members) do
            local memberSource = GetPlayerFromCitizenId(member.citizenid)
            if memberSource then
                TriggerClientEvent('fivemate-teams:client:memberOffline', memberSource, {
                    citizenid = Players[source].citizenid,
                    name = Players[source].name
                })
            end
        end
    end
    
    Players[source] = nil
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
    
    -- Verificar permisos
    if not (Players[source].clan.role == 'leader' or Players[source].clan.role == 'sublider') then
        SendNotification(source, Config.Messages.Error.NoPermission, 'error')
        return
    end
    
    -- Verificar que el jugador objetivo existe y está conectado
    local targetPlayer = GetPlayerPed(targetId)
    if targetPlayer == 0 then
        SendNotification(source, Config.Messages.Error.PlayerNotFound, 'error')
        return
    end
    
    -- Asegurar que el jugador objetivo esté en la tabla Players
    InitializePlayer(targetId)
    
    local targetCitizenId = GetPlayerIdentifier(targetId)
    if not targetCitizenId then
        SendNotification(source, Config.Messages.Error.PlayerNotFound, 'error')
        return
    end
    
    -- Verificar si el jugador ya tiene clan
    if GetPlayerClan(targetCitizenId) then
        SendNotification(source, Config.Messages.Error.PlayerAlreadyInClan, 'error')
        return
    end
    
    -- Verificar límite de miembros
    local members = GetClanMembers(Players[source].clan.id)
    if #members >= Config.Clan.MaxMembers then
        SendNotification(source, Config.Messages.Error.MaxMembersReached, 'error')
        return
    end
    
    -- Enviar invitación de forma asíncrona para evitar timeouts
    Citizen.CreateThread(function()
        TriggerClientEvent('fivemate-teams:client:receiveInvitation', targetId, {
            clanId = Players[source].clan.id,
            clanName = Players[source].clan.name,
            clanTag = Players[source].clan.tag,
            inviterName = GetPlayerName(source)
        })
        
        SendNotification(source, Config.Messages.Success.PlayerInvited, 'success')
        SendNotification(targetId, string.format('Has recibido una invitación de clan de %s', GetPlayerName(source)), 'info')
    end)
end)

-- Aceptar invitación
RegisterNetEvent('fivemate-teams:server:acceptInvitation')
AddEventHandler('fivemate-teams:server:acceptInvitation', function(clanId)
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    
    if not citizenid then return end
    
    -- Verificar si el jugador ya tiene clan
    if GetPlayerClan(citizenid) then
        SendNotification(source, Config.Messages.Error.AlreadyInClan, 'error')
        return
    end
    
    -- Agregar al clan
    local success = MySQL.Sync.insert('INSERT INTO clan_members (clan_id, citizenid, role) VALUES (?, ?, ?)', {
        clanId, citizenid, 'member'
    })
    
    if success then
        -- Actualizar datos del jugador
        local clan = MySQL.Sync.fetchAll('SELECT * FROM clans WHERE id = ?', {clanId})[1]
        Players[source].clan = {
            id = clan.id,
            name = clan.name,
            tag = clan.tag,
            leader = clan.leader,
            role = 'member'
        }
        
        SendNotification(source, string.format('Te has unido al clan %s!', clan.name), 'success')
        TriggerClientEvent('fivemate-teams:client:updateClanData', source, Players[source].clan)
        
        -- Notificar a otros miembros
        local members = GetClanMembers(clanId)
        for _, member in pairs(members) do
            local memberSource = GetPlayerFromCitizenId(member.citizenid)
            if memberSource and memberSource ~= source then
                SendNotification(memberSource, string.format('%s se ha unido al clan', GetPlayerName(source)), 'info')
            end
        end
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
    
    -- Expulsar del clan
    local affected = MySQL.Sync.execute('DELETE FROM clan_members WHERE clan_id = ? AND citizenid = ?', {
        Players[source].clan.id, targetCitizenId
    })
    
    if affected > 0 then
        SendNotification(source, Config.Messages.Success.PlayerKicked, 'success')
        
        -- Notificar al jugador expulsado si está online
        local targetSource = GetPlayerFromCitizenId(targetCitizenId)
        if targetSource then
            Players[targetSource].clan = nil
            SendNotification(targetSource, 'Has sido expulsado del clan', 'error')
            TriggerClientEvent('fivemate-teams:client:updateClanData', targetSource, nil)
        end
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
    
    -- Si es líder, debe transferir el liderazgo primero
    if Players[source].clan.role == 'leader' then
        local members = GetClanMembers(Players[source].clan.id)
        if #members > 1 then
            SendNotification(source, 'Debes transferir el liderazgo antes de salir del clan', 'error')
            return
        else
            -- Es el único miembro, eliminar el clan
            MySQL.Sync.execute('DELETE FROM clans WHERE id = ?', {Players[source].clan.id})
        end
    else
        -- Salir del clan
        MySQL.Sync.execute('DELETE FROM clan_members WHERE clan_id = ? AND citizenid = ?', {
            Players[source].clan.id, citizenid
        })
    end
    
    Players[source].clan = nil
    SendNotification(source, Config.Messages.Success.LeftClan, 'success')
    TriggerClientEvent('fivemate-teams:client:updateClanData', source, nil)
end)

-- ================================================
-- FUNCIONES AUXILIARES
-- ================================================

-- Inicializar jugador en la tabla Players si no existe
function InitializePlayer(source)
    if not Players[source] then
        local citizenid = GetPlayerIdentifier(source)
        if citizenid then
            Players[source] = {
                citizenid = citizenid,
                name = GetPlayerName(source),
                clan = GetPlayerClan(citizenid)
            }
        end
    end
    return Players[source]
end

-- Obtener source del jugador por citizenid
function GetPlayerFromCitizenId(citizenid)
    for source, data in pairs(Players) do
        if data.citizenid == citizenid then
            return source
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

-- Export para otros recursos
exports('GetPlayerClan', GetPlayerClan)
exports('GetClanMembers', GetClanMembers)

if Config.Debug then
    print('^2[Fivemate-Teams]^7 Sistema de clanes cargado correctamente')
end