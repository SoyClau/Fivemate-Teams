Config = {}

-- ================================================
-- CONFIGURACIÓN GENERAL
-- ================================================

-- Framework automático (auto-detecta ESX o QBCore)
Config.Framework = nil -- Se detecta automáticamente

-- Configuración de clan
Config.Clan = {
    MaxMembers = 10, -- Máximo número de miembros por clan
    MinNameLength = 3, -- Mínimo caracteres para nombre
    MaxNameLength = 25, -- Máximo caracteres para nombre
    MinTagLength = 2, -- Mínimo caracteres para tag
    MaxTagLength = 6, -- Máximo caracteres para tag
}

-- Configuración de roles
Config.Roles = {
    leader = {
        label = 'Líder',
        color = '#FF6B6B', -- Rojo
        permissions = {'invite', 'kick', 'promote', 'demote', 'transfer', 'disband', 'delete_clan'}
    },
    sublider = {
        label = 'Sub-Líder', 
        color = '#4ECDC4', -- Cyan
        permissions = {'invite', 'kick', 'promote_member', 'demote_member'}
    },
    member = {
        label = 'Miembro',
        color = '#45B7D1', -- Azul
        permissions = {}
    }
}

-- Configuración del HUD
Config.HUD = {
    Enabled = true,
    Position = {x = 0.02, y = 0.3}, -- Posición en pantalla (0.0-1.0)
    MaxDistance = 500.0, -- Distancia máxima para mostrar miembros (reducida para optimización)
    RefreshRate = 2000, -- Actualización cada 2 segundos (optimizado)
    ShowOfflineMembers = true, -- Mostrar miembros offline
    PersistentInfo = true, -- Mostrar información del clan siempre que tengas uno
}
-- Configuración de protección
Config.Protection = {
    FriendlyFire = false, -- true = permite daño entre clan, false = no permite

}

-- Configuración de blips en el mapa
Config.Blips = {
    Enabled = true,         -- Activar/desactivar sistema de blips
    UpdateInterval = 2000,  -- Intervalo de actualización en ms
    Sprite = 1,             -- Ícono del blip (1 = punto)
    Color = 3,              -- Color del blip (3 = azul)
    Scale = 0.8,            -- Tamaño del blip
    Alpha = 250,            -- Transparencia del blip (0-255)
    ShowName = true,        -- Mostrar nombre sobre el blip
    ShortRange = true,      -- Blip visible a corta distancia
    Category = 7,           -- Categoría del blip (7 = jugador)
    ShowHeading = true,     -- Mostrar dirección del jugador
    
    -- Opciones avanzadas para blips dinámicos
    Flash = true,           -- Hacer que los blips parpadeen
    FlashInterval = 600,    -- Intervalo de parpadeo en ms
    FlashAlternateColor = 1, -- Color alternativo para parpadeo (1 = blanco)
    
    -- Personalización por rol
    RoleColors = {
        leader = 49,        -- Rojo para líder (49)
        sublider = 2,       -- Verde para sublíder (2)
        member = 3          -- Azul para miembro (3)
    },
    
    RoleScales = {
        leader = 1.0,       -- Tamaño para líder
        sublider = 0.9,     -- Tamaño para sublíder
        member = 0.8        -- Tamaño para miembro
    }
}

-- Configuración de comandos
Config.Commands = {
    ClanMenu = 'clanmenu', -- Comando para abrir menú
    ClanInfo = 'claninfo', -- Comando para ver info del clan
}

-- Configuración de teclas
Config.Keys = {
    OpenMenu = 'F6', -- Tecla para abrir menú (opcional)
}

-- Configuración de mensajes
Config.Messages = {
    Success = {
        ClanCreated = 'Clan creado exitosamente!',
        PlayerInvited = 'Jugador invitado al clan',
        PlayerKicked = 'Jugador expulsado del clan',
        LeadershipTransferred = 'Liderazgo transferido exitosamente',
        LeftClan = 'Has salido del clan',
        ClanDeleted = 'El clan ha sido eliminado permanentemente',
    },
    Error = {
        AlreadyInClan = 'Ya perteneces a un clan',
        NotInClan = 'No perteneces a ningún clan',
        ClanNameTaken = 'Este nombre de clan ya está en uso',
        ClanTagTaken = 'Este tag de clan ya está en uso',
        InvalidName = 'Nombre inválido (debe tener entre %s y %s caracteres)',
        InvalidTag = 'Tag inválido (debe tener entre %s y %s caracteres)',
        PlayerNotFound = 'Jugador no encontrado',
        PlayerAlreadyInClan = 'El jugador ya pertenece a un clan',
        NoPermission = 'No tienes permisos para hacer esto',
        CantKickYourself = 'No puedes expulsarte a ti mismo',
        CantTransferToYourself = 'No puedes transferir el liderazgo a ti mismo',
        MaxMembersReached = 'El clan ha alcanzado el límite máximo de miembros',
        CantDeleteClan = 'No tienes permiso para eliminar el clan',
    },
    Info = {
        ClanMembers = 'Miembros del Clan',
        NoMembers = 'No hay miembros online',
        ConfirmDeleteClan = '¿Estás seguro de que quieres eliminar permanentemente el clan? Esta acción no se puede deshacer y todos los miembros serán expulsados.',
    }
}

-- Configuración de notificaciones
Config.Notifications = {
    Type = 'ox_lib', -- 'ox_lib', 'esx', 'qb', 'custom'
    Duration = 5000, -- Duración en milisegundos
}

-- Debug
Config.Debug = false