# 🏴‍☠️ Fivemate Teams - Sistema de Clanes para FiveM

Un sistema completo de clanes/equipos para FiveM compatible con **ESX** y **QBCore**, desarrollado con **ox_lib** para menús modernos e interacciones fluidas.

## ✨ Características

### 🎯 Funcionalidades Principales
- ✅ **Compatible con ESX y QBCore** - Detección automática de framework
- ✅ **Creación de clanes** con validación de nombres únicos
- ✅ **Sistema de roles** (Líder, Sub-Líder, Miembro)
- ✅ **Gestión de miembros** (Invitar, expulsar, transferir liderazgo)
- ✅ **HUD en tiempo real** mostrando miembros cercanos
- ✅ **Protección contra fuego amigo** configurable
- ✅ **Menús intuitivos** usando ox_lib
- ✅ **Base de datos MySQL** con oxmysql

### 🛡️ Sistema de Roles
| Rol | Permisos | Color |
|-----|----------|-------|
| **Líder** | Todos los permisos + transferir liderazgo | 🔴 Rojo |
| **Sub-Líder** | Invitar, expulsar, promover miembros | 🔵 Cyan |
| **Miembro** | Permisos básicos | 🟦 Azul |

### 📊 HUD Inteligente
- 📍 **Distancia en tiempo real** a miembros del clan
- ❤️ **Indicador de vida** con barra de progreso
- 🎨 **Colores por rol** para fácil identificación
- 👁️ **Auto-ocultar** cuando no hay miembros cercanos

## 📦 Instalación

### 1. Requisitos Previos
```bash
# Dependencias necesarias
- oxmysql
- ox_lib
- ESX o QBCore framework
```

### 2. Descargar e Instalar
1. Descarga o clona este repositorio
2. Coloca la carpeta `Fivemate-Teams` en tu directorio `resources`
3. Ejecuta el archivo SQL en tu base de datos:

```sql
-- Ejecutar en tu base de datos MySQL
source sql/clans.sql
```

### 3. Configurar server.cfg
```cfg
# Agregar a tu server.cfg
ensure oxmysql
ensure ox_lib
ensure Fivemate-Teams
```

### 4. Reiniciar el Servidor
```bash
restart Fivemate-Teams
# o
refresh && start Fivemate-Teams
```

## ⚙️ Configuración

Edita el archivo `config.lua` para personalizar el sistema:

```lua
Config.Clan = {
    MaxMembers = 10,      -- Máximo miembros por clan
    MinNameLength = 3,    -- Mínimo caracteres nombre
    MaxNameLength = 25,   -- Máximo caracteres nombre
    MinTagLength = 2,     -- Mínimo caracteres tag
    MaxTagLength = 6,     -- Máximo caracteres tag
}

Config.Protection = {
    FriendlyFire = false, -- true = permite daño entre clan
    ProtectVehicles = true -- Proteger vehículos del clan
}

Config.HUD = {
    Enabled = true,
    MaxDistance = 1000.0, -- Distancia máxima para mostrar
    RefreshRate = 1000,   -- Actualización en ms
}
```

## 🎮 Uso del Sistema

### Comandos Disponibles
```bash
/clanmenu    # Abrir menú principal de clan
/claninfo    # Ver información del clan actual
```

### Teclas Predeterminadas
- **F6** - Abrir menú de clan (configurable)

### Flujo de Uso

#### 1. Crear un Clan
1. Ejecuta `/clanmenu` sin tener clan
2. Introduce nombre del clan (3-25 caracteres)
3. Introduce tag del clan (2-6 caracteres)
4. ¡Clan creado! Serás automáticamente el líder

#### 2. Gestionar Miembros
1. Abre `/clanmenu` siendo miembro de un clan
2. Selecciona "Invitar Jugador" (requiere permisos)
3. Elige un jugador cercano de la lista
4. El jugador recibirá una invitación

#### 3. Ver Miembros en el HUD
- El HUD se activa automáticamente cuando hay miembros cercanos
- Muestra: nombre, rol, distancia y vida de cada miembro
- Se actualiza cada segundo

## 🗃️ Estructura de Base de Datos

### Tabla `clans`
```sql
- id (INT, PRIMARY KEY)
- name (VARCHAR(50), UNIQUE)
- tag (VARCHAR(10), UNIQUE)
- leader (VARCHAR(50))
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

### Tabla `clan_members`
```sql
- id (INT, PRIMARY KEY)
- clan_id (INT, FOREIGN KEY)
- citizenid (VARCHAR(50))
- role (ENUM: leader, sublider, member)
- joined_at (TIMESTAMP)
```

## 🔧 API para Desarrolladores

### Exports Disponibles

#### Cliente
```lua
-- Obtener clan del jugador
local clan = exports['Fivemate-Teams']:GetPlayerClan()

-- Obtener miembros del clan
local members = exports['Fivemate-Teams']:GetClanMembers()

-- Abrir menú de clan
exports['Fivemate-Teams']:OpenClanMenu()
```

#### Servidor
```lua
-- Obtener clan de un jugador
local clan = exports['Fivemate-Teams']:GetPlayerClan(citizenid)

-- Obtener miembros de un clan
local members = exports['Fivemate-Teams']:GetClanMembers(clanId)
```

### Eventos Personalizados

#### Cliente → Servidor
```lua
-- Crear clan
TriggerServerEvent('fivemate-teams:server:createClan', clanData)

-- Invitar jugador
TriggerServerEvent('fivemate-teams:server:invitePlayer', targetId)

-- Expulsar jugador
TriggerServerEvent('fivemate-teams:server:kickPlayer', citizenid)
```

#### Servidor → Cliente
```lua
-- Actualizar datos del clan
TriggerClientEvent('fivemate-teams:client:updateClanData', source, clanData)

-- Recibir invitación
TriggerClientEvent('fivemate-teams:client:receiveInvitation', source, inviteData)
```

## 🛠️ Solución de Problemas

### Problemas Comunes

#### "Framework no detectado"
```bash
# Verificar que ESX o QBCore esté iniciado antes
ensure es_extended  # Para ESX
# o
ensure qb-core      # Para QBCore

ensure Fivemate-Teams
```

#### "Error de base de datos"
```bash
# Verificar oxmysql configurado correctamente
# Ejecutar el archivo SQL completo
# Verificar permisos de la base de datos
```

#### "Menús no aparecen"
```bash
# Verificar ox_lib instalado
ensure ox_lib
restart Fivemate-Teams
```

### Debug Mode
Activa el modo debug en `config.lua`:
```lua
Config.Debug = true
```

## 📝 Changelog

### v1.0.0 (2025-09-21)
- ✅ Lanzamiento inicial
- ✅ Compatibilidad ESX/QBCore
- ✅ Sistema completo de clanes
- ✅ HUD en tiempo real
- ✅ Protección fuego amigo
- ✅ Menús ox_lib

## 🤝 Contribuir

1. Fork del repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## 📜 Licencia

Este proyecto está bajo la Licencia MIT. Ver archivo `LICENSE` para más detalles.

## 🆘 Soporte

- **Discord**: [Tu servidor de Discord]
- **Issues**: [GitHub Issues](https://github.com/tu-usuario/Fivemate-Teams/issues)
- **Documentación**: [Wiki del proyecto]

## 💝 Créditos

- **Desarrollado por**: Fivemate Development Team
- **Framework**: ESX/QBCore
- **UI Library**: ox_lib
- **Database**: oxmysql

---

### 🎯 Roadmap Futuro
- [ ] Sistema de territorios
- [ ] Guerra entre clanes
- [ ] Estadísticas avanzadas
- [ ] Integración con economía
- [ ] Sistema de alianzas
- [ ] Personalización de colores
- [ ] Chat privado del clan
- [ ] Sistema de rangos avanzado

**¡Gracias por usar Fivemate Teams! 🚀**