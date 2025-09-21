fx_version 'cerulean'
game 'gta5'

name 'Fivemate-Teams'
description 'Sistema de clanes/equipos para FiveM - Compatible con ESX y QBCore'
author 'Fivemate'
version '1.0.0'

-- Dependencias
dependencies {
    'oxmysql',
    'ox_lib'
}

-- Compartido
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

-- Cliente
client_scripts {
    'client/client.lua',
    'client/blips.lua'
}

-- Servidor
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

-- Archivos UI (si decides agregar más tarde)
ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

lua54 'yes'