fx_version 'cerulean'
game 'gta5'

author 'Alejacros'
description 'Sentinel AI Core'
version '0.1.0-alpha'

client_scripts {

    'config.lua',

    'client/main.lua',

    'client/managers/PlayerManager.lua',
    'client/managers/MenuManager.lua',
    'client/managers/HUDManager.lua',
    'client/managers/VehicleManager.lua',
    'client/managers/SceneManager.lua',
    'client/managers/DispatchManager.lua'

}

server_scripts {
    'server.lua'
}

dependencies {
    'chat'
}




