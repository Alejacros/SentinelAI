fx_version 'cerulean'
game 'gta5'

author 'Alejacros'
description 'Sentinel AI Police Career Simulator'
version '0.3.1-prealpha'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

client_scripts {
    'config.lua',
    'client/data/Dispatches.lua',
    'client/bootstrap.lua',

    'client/managers/PlayerManager.lua',
    'client/managers/CareerManager.lua',
    'client/managers/DevManager.lua',
    'client/managers/SpawnManager.lua',
    'client/managers/VehicleManager.lua',
    'client/managers/MenuManager.lua',
    'client/managers/HUDManager.lua',
    'client/managers/SceneManager.lua',
    'client/managers/DispatchManager.lua',
    'client/managers/EvidenceManager.lua',
    'client/managers/InteractionManager.lua',
    'client/managers/MDTManager.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'chat'
}