fx_version 'cerulean'
game 'gta5'

author 'Alejacros'
description 'Sentinel AI Police Career Simulator'
version '1.5.0-prealpha'

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
    'client/data/BehaviorProfiles.lua',
    'client/data/IncidentTemplates.lua',
    'client/data/PatrolMessages.lua',

    'client/bootstrap.lua',

    'client/managers/EntityManager.lua',
    'client/managers/SpawnPointManager.lua',
    'client/managers/SceneBuilder.lua',
    'client/managers/BehaviorManager.lua',

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
    'client/managers/PatrolManager.lua',
    'client/managers/PatrolEventManager.lua',
    'client/managers/CityLifeManager.lua',

    'client/managers/SceneDirectorManager.lua',
    'client/managers/IncidentVariantManager.lua',
    'client/managers/PoliceAIManager.lua',
    'client/managers/UseOfForceManager.lua',
    'client/managers/BodyCamManager.lua',
    'client/managers/ProcedureManager.lua',

    'client/managers/SuspectManager.lua',
    'client/managers/ArrestManager.lua',
    'client/managers/CustodyManager.lua',
    'client/managers/SceneManager.lua',
    'client/managers/MissionManager.lua',

    'client/managers/DispatchManager.lua',
    'client/managers/EvidenceManager.lua',
    'client/managers/InteractionManager.lua',
    'client/managers/MDTManager.lua',
    'client/managers/CaseReviewManager.lua',

    'client/managers/ActionDirector.lua',
    'client/directors/RobberyDirector.lua'
}

server_scripts {
    'server.lua',
    'server/save.lua'
}

dependencies {
    'chat'
}