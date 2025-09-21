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
        permissions = {'invite', 'kick', 'promote', 'demote', 'transfer', 'disband'}
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
    MaxDistance = 500.0, -- Distancia máxima para mostrar miembros (solo para HUD)
    RefreshRate = 2000, -- Actualización cada 2 segundos (optimizado)
    ShowOfflineMembers = false, -- Mostrar miembros offline
    PersistentInfo = true, -- Mostrar información del clan siempre que tengas uno
    ShowDistance = false, -- No mostrar distancia para optimización
}

-- Configuración de protección
Config.Protection = {
    FriendlyFire = false, -- true = permite daño entre clan, false = no permite
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
    },
    Info = {
        ClanMembers = 'Miembros del Clan',
        NoMembers = 'No hay miembros online',
        Health = 'Vida: %s%%',
    }
}

-- Configuración de notificaciones
Config.Notifications = {
    Type = 'ox_lib', -- 'ox_lib', 'esx', 'qb', 'custom'
    Duration = 5000, -- Duración en milisegundos
}

-- Debug
Config.Debug = false