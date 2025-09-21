-- ================================================
-- Fivemate Teams - Clan System Database
-- Compatible with ESX and QBCore
-- ================================================

-- Tabla principal de clanes
CREATE TABLE IF NOT EXISTS `clans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `tag` varchar(10) NOT NULL,
  `leader` varchar(50) NOT NULL, -- citizenid for QBCore, identifier for ESX
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_name` (`name`),
  UNIQUE KEY `unique_tag` (`tag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de miembros del clan
CREATE TABLE IF NOT EXISTS `clan_members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `clan_id` int(11) NOT NULL,
  `citizenid` varchar(50) NOT NULL, -- citizenid for QBCore, identifier for ESX
  `role` enum('leader','sublider','member') DEFAULT 'member',
  `joined_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_member` (`clan_id`, `citizenid`),
  KEY `clan_id` (`clan_id`),
  KEY `citizenid` (`citizenid`),
  CONSTRAINT `fk_clan_members_clan` FOREIGN KEY (`clan_id`) REFERENCES `clans` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;