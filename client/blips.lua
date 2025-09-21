-- ================================================
-- Fivemate Teams - Sistema de Blips de Clan
-- ================================================

local clanMemberBlips = {}
local blipFlashStates = {}
local isBlipFlashing = false

-- Inicializar sistema de blips
function InitClanMemberBlips()
    -- Primero limpiar los blips existentes
    ClearAllClanBlips()
    
    -- Comenzar el bucle para actualizar los blips
    Citizen.CreateThread(function()
        while true do
            UpdateClanBlips()
            Citizen.Wait(Config.Blips.UpdateInterval or 2000) -- Usar el intervalo de configuración
        end
    end)
    
    -- Iniciar el bucle para el efecto de parpadeo si está habilitado
    if Config.Blips.Flash then
        Citizen.CreateThread(function()
            while true do
                ToggleBlipsFlash()
                Citizen.Wait(Config.Blips.FlashInterval or 600) -- Intervalo de parpadeo
            end
        end)
    end
    
    if Config.Debug then
        print("[Fivemate-Teams] Sistema de blips dinámicos iniciado")
    end
end

-- Actualizar los blips de los miembros del clan
function UpdateClanBlips()
    -- Verificar si el jugador está en un clan
    if not PlayerClan then
        ClearAllClanBlips()
        return
    end
    
    -- Obtener los miembros del clan
    if not ClanMembers or type(ClanMembers) ~= "table" or #ClanMembers == 0 then
        return
    end
    
    -- Obtener el id del jugador local
    local playerId = GetPlayerIdentifier()
    if not playerId then return end
    
    -- Actualizar/crear blips para cada miembro online
    for _, member in ipairs(ClanMembers) do
        -- Solo procesar miembros online que no sean el jugador local
        if member and member.online and member.citizenid and member.citizenid ~= playerId and member.source then
            local memberPed = GetPlayerPed(GetPlayerFromServerId(member.source))
            
            -- Solo crear blip si el jugador existe
            if memberPed and memberPed ~= 0 and DoesEntityExist(memberPed) then
                -- Verificar si ya existe un blip para este miembro
                if clanMemberBlips[member.citizenid] then
                    -- Actualizar posición del blip existente
                    local coords = GetEntityCoords(memberPed)
                    SetBlipCoords(clanMemberBlips[member.citizenid], coords.x, coords.y, coords.z)
                    
                    -- Actualizar rotación si está habilitado
                    if Config.Blips.ShowHeading then
                        local heading = GetEntityHeading(memberPed)
                        SetBlipRotation(clanMemberBlips[member.citizenid], math.ceil(heading))
                    end
                    
                    -- Actualizar visibilidad para miembros que se acaban de conectar
                    if not blipFlashStates[member.citizenid] and Config.Blips.Flash then
                        blipFlashStates[member.citizenid] = {
                            flashing = true,
                            originalColor = Config.Blips.RoleColors[member.role] or Config.Blips.Color,
                            flashColor = Config.Blips.FlashAlternateColor,
                            flashCount = 0 -- Contador para limitar el parpadeo inicial
                        }
                    end
                else
                    -- Crear un nuevo blip
                    CreateMemberBlip(member)
                    
                    -- Inicializar estado de parpadeo para el nuevo blip
                    if Config.Blips.Flash then
                        blipFlashStates[member.citizenid] = {
                            flashing = true,
                            originalColor = Config.Blips.RoleColors[member.role] or Config.Blips.Color,
                            flashColor = Config.Blips.FlashAlternateColor,
                            flashCount = 0
                        }
                    end
                end
            elseif clanMemberBlips[member.citizenid] then
                -- Si el ped no existe pero el blip sí, eliminar el blip
                RemoveBlip(clanMemberBlips[member.citizenid])
                clanMemberBlips[member.citizenid] = nil
                blipFlashStates[member.citizenid] = nil
            end
        end
    end
    
    -- Eliminar blips de miembros que ya no están en el clan o están offline
    for citizenid, blip in pairs(clanMemberBlips) do
        local stillExists = false
        for _, member in ipairs(ClanMembers) do
            if member.citizenid == citizenid and member.online then
                stillExists = true
                break
            end
        end
        
        if not stillExists then
            RemoveBlip(blip)
            clanMemberBlips[citizenid] = nil
            blipFlashStates[citizenid] = nil
        end
    end
end

-- Crear un blip para un miembro específico
function CreateMemberBlip(member)
    if not member or not member.source then return end
    
    local memberPed = GetPlayerPed(GetPlayerFromServerId(member.source))
    if not memberPed or memberPed == 0 or not DoesEntityExist(memberPed) then return end
    
    local coords = GetEntityCoords(memberPed)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    
    -- Configurar propiedades del blip según el rol del miembro
    local blipColor = Config.Blips.Color or 3  -- Color por defecto (azul)
    local blipScale = Config.Blips.Scale or 0.8
    
    -- Personalizar por rol usando la configuración
    if Config.Blips.RoleColors and Config.Blips.RoleColors[member.role] then
        blipColor = Config.Blips.RoleColors[member.role]
    elseif member.role == "leader" then
        blipColor = 49  -- Rojo para líder
        blipScale = 1.0
    elseif member.role == "sublider" then
        blipColor = 2   -- Verde para sublíder
        blipScale = 0.9
    end
    
    if Config.Blips.RoleScales and Config.Blips.RoleScales[member.role] then
        blipScale = Config.Blips.RoleScales[member.role]
    end
    
    SetBlipSprite(blip, Config.Blips.Sprite or 1)
    SetBlipColour(blip, blipColor)
    SetBlipScale(blip, blipScale)
    SetBlipAlpha(blip, Config.Blips.Alpha or 250)
    SetBlipAsShortRange(blip, Config.Blips.ShortRange or true)
    
    if Config.Blips.ShowHeading then
        ShowHeadingIndicatorOnBlip(blip, true)
    end
    
    if Config.Blips.Category then
        SetBlipCategory(blip, Config.Blips.Category)
    end
    
    if Config.Blips.ShowName then
        BeginTextCommandSetBlipName("STRING")
        -- Mostrar nombre y rol
        local roleName = Config.Roles[member.role] and Config.Roles[member.role].label or member.role
        AddTextComponentString(member.name .. " (" .. roleName .. ")")
        EndTextCommandSetBlipName(blip)
    end
    
    -- Guardar referencia al blip
    clanMemberBlips[member.citizenid] = blip
    
    -- Configurar estado de parpadeo para nuevos blips
    if Config.Blips.Flash then
        blipFlashStates[member.citizenid] = {
            flashing = true,
            originalColor = blipColor,
            flashColor = Config.Blips.FlashAlternateColor or 1,
            flashCount = 0
        }
    end
    
    return blip
end

-- Función para hacer parpadear los blips
function ToggleBlipsFlash()
    if not Config.Blips.Flash then return end
    
    for citizenid, state in pairs(blipFlashStates) do
        if state.flashing and clanMemberBlips[citizenid] and DoesBlipExist(clanMemberBlips[citizenid]) then
            -- Alternar entre colores para crear efecto de parpadeo
            local currentColor = GetBlipColour(clanMemberBlips[citizenid])
            local newColor
            
            if currentColor == state.originalColor then
                newColor = state.flashColor
            else
                newColor = state.originalColor
                -- Incrementar contador de parpadeos
                state.flashCount = state.flashCount + 1
                
                -- Detener parpadeo después de 10 ciclos (5 segundos aproximadamente)
                if state.flashCount > 10 then
                    state.flashing = false
                    newColor = state.originalColor
                end
            end
            
            SetBlipColour(clanMemberBlips[citizenid], newColor)
        end
    end
end

-- Limpiar todos los blips
function ClearAllClanBlips()
    for citizenid, blip in pairs(clanMemberBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    clanMemberBlips = {}
    blipFlashStates = {}
end

-- Registrar eventos necesarios
RegisterNetEvent("fivemate-teams:client:updateClanData")
AddEventHandler("fivemate-teams:client:updateClanData", function(clanData)
    -- Cuando los datos del clan cambian, limpiar y reiniciar los blips
    ClearAllClanBlips()
end)

-- Eliminar blips al detener el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    
    ClearAllClanBlips()
end)

-- Exportar funciones
exports('InitClanMemberBlips', InitClanMemberBlips)
exports('UpdateClanBlips', UpdateClanBlips)
exports('ClearAllClanBlips', ClearAllClanBlips)