fx_version 'cerulean'
game 'gta5'

author 'Alejacros'
description 'Sentinel AI Police Career Simulator'
version '0.3.0-prealpha'

shared_scripts {
    'shared/version.lua',
    'shared/career.lua',
    'client/data/DispatchConfig.lua',
    'client/data/Dispatches.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/icons.svg'
}

client_scripts {
    'config.lua',

    'client/data/Scenarios.lua',
    'client/data/BehaviorProfiles.lua',
    'client/data/IncidentTemplates.lua',
    'client/data/Agencies.lua',
    'client/data/PatrolMessages.lua',
    'client/data/PoliceUniforms.lua',
    'client/data/PoliceFleet.lua',
    'client/data/PoliceGarages.lua',
    'client/data/SentinelCommands.lua',
    'client/data/TerminalModules.lua',
    'client/data/WidgetLayout.lua',

    'client/bootstrap.lua',

    'client/managers/EntityManager.lua',
    'client/managers/SpawnPointManager.lua',
    'client/managers/SceneBuilder.lua',
    'client/managers/BehaviorManager.lua',

    'client/managers/PlayerManager.lua',
    'client/managers/CareerManager.lua',
    'client/managers/PermissionManager.lua',
    'client/managers/PoliceAlertManager.lua',
    'client/managers/WidgetLayoutManager.lua',
    'client/managers/IncidentManager.lua',
    'client/managers/AssignmentManager.lua',

    'client/managers/HistoryManager.lua',
    'client/managers/CaseManager.lua',
    'client/managers/SaveManager.lua',
    'client/managers/AppearanceManager.lua',
    'client/managers/CharacterManager.lua',
    'client/managers/SpawnManager.lua',

    'client/managers/DevManager.lua',
    'client/managers/CommandManager.lua',
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
    'client/managers/PoliceTerminalManager.lua',
    'client/managers/MDTManager.lua',
    'client/managers/CaseReviewManager.lua',

    'client/managers/ActionDirector.lua',
    'client/directors/RobberyDirector.lua'
}

server_scripts {
    'server.lua',
    'server/save.lua',
    'server/dispatch.lua'
}

dependencies {
    'chat'
}
