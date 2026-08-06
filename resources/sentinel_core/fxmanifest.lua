fx_version 'cerulean'
game 'gta5'

author 'Alejacros'
description 'Sentinel AI Police Career Simulator'
version '0.9.0-prealpha'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

client_scripts {
    'config.lua',

    'client/data/Dispatches.lua',
    'client/data/Scenarios.lua',

    'client/bootstrap.lua',

    'client/managers/EntityManager.lua',
    'client/managers/PlayerManager.lua',
    'client/managers/CareerManager.lua',

    'client/managers/HistoryManager.lua',
    'client/managers/CaseManager.lua',
    'client/managers/SaveManager.lua',

    'client/managers/DevManager.lua',
    'client/managers/SpawnManager.lua',
    'client/managers/VehicleManager.lua',
    'client/managers/MenuManager.lua',
    'client/managers/HUDManager.lua',

    'client/managers/SceneDirectorManager.lua',
    'client/managers/SuspectManager.lua',
    'client/managers/ArrestManager.lua',
    'client/managers/SceneManager.lua',

    'client/managers/DispatchManager.lua',
    'client/managers/EvidenceManager.lua',
    'client/managers/InteractionManager.lua',
    'client/managers/MDTManager.lua'
}

server_scripts {
    'server.lua',
    'server/save.lua'
}

dependencies {
    'chat'
}