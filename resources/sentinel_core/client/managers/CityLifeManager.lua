print("[Sentinel AI] Cargando CityLifeManager...")

CityLifeManager = {
    Active = true,
    Civilians = {},

    RegisteredCount = 0,
    LastScanAt = 0
}

local SCAN_INTERVAL = 1500
local SCAN_RADIUS = 75.0
local CLEANUP_RADIUS = 130.0

local PANIC_RADIUS = 45.0
local WATCH_RADIUS = 28.0

local MAX_TRACKED_CIVILIANS = 25

-- =========================================================
-- UTILIDADES
-- =========================================================

local function distanceBetween(first, second)
    return #(first - second)
end

local function isValidPed(ped)
    if not ped
        or ped == 0
        or not DoesEntityExist(ped)
        or not IsEntityAPed(ped)
        or IsEntityDead(ped) then

        return false
    end

    if ped == PlayerPedId() then
        return false
    end

    if IsPedAPlayer(ped) then
        return false
    end

    return true
end

local function isPolicePed(ped)
    if not isValidPed(ped) then
        return false
    end

    if GetPedType(ped) == 6 then
        return true
    end

    local relationship =
        GetPedRelationshipGroupHash(ped)

    return relationship == GetHashKey("COP")
end

local function isSentinelEntity(ped)
    if PlayerData then
        if PlayerData.SceneNPC == ped then
            return true
        end
    end

    if SuspectSystem
        and SuspectSystem.Entity == ped then

        return true
    end

    if SceneDirector
        and SceneDirector.Suspect == ped then

        return true
    end

    if PoliceAIManager
        and type(PoliceAIManager.Officers)
            == "table" then

        for _, officer in ipairs(
            PoliceAIManager.Officers
        ) do
            if officer == ped then
                return true
            end
        end
    end

    if PatrolEventManager
        and PatrolEventManager.Entity == ped then

        return true
    end

    return false
end

local function canTrackPed(ped)
    return isValidPed(ped)
        and not isPolicePed(ped)
        and not isSentinelEntity(ped)
end

local function countTracked()
    local count = 0

    for _ in pairs(
        CityLifeManager.Civilians
    ) do
        count = count + 1
    end

    return count
end

-- =========================================================
-- REGISTRO
-- =========================================================

local function unregisterCivilian(ped)
    local data =
        CityLifeManager.Civilians[ped]

    if not data then
        return
    end

    if BehaviorManager
        and type(
            BehaviorManager.RemoveActor
        ) == "function" then

        BehaviorManager.RemoveActor(ped)
    end

    CityLifeManager.Civilians[ped] = nil
end

local function registerCivilian(ped)
    if CityLifeManager.Civilians[ped] then
        return false
    end

    if countTracked()
        >= MAX_TRACKED_CIVILIANS then

        return false
    end

    local actor = nil

    if BehaviorManager
        and type(
            BehaviorManager.RegisterActor
        ) == "function" then

        actor =
            BehaviorManager.RegisterActor(
                ped,
                "CIVIL"
            )
    end

    CityLifeManager.Civilians[ped] = {
        entity = ped,

        state = "NORMAL",

        registeredAt =
            GetGameTimer(),

        lastReactionAt = 0,

        actor = actor
    }

    CityLifeManager.RegisteredCount =
        CityLifeManager.RegisteredCount + 1

    return true
end

-- =========================================================
-- DETECCIÓN DEL ENTORNO
-- =========================================================

local function getActiveThreat()
    if SceneDirector
        and SceneDirector.Suspect
        and DoesEntityExist(
            SceneDirector.Suspect
        )
        and not IsEntityDead(
            SceneDirector.Suspect
        ) then

        return SceneDirector.Suspect
    end

    return nil
end

local function sceneIsDangerous()
    if not SceneDirector then
        return false
    end

    local dangerousStates = {
        ACTIVE_THREAT = true,
        ACTIVE_DISTURBANCE = true,
        SUSPECT_FLEEING = true
    }

    return dangerousStates[
        SceneDirector.State
    ] == true
end

local function nearbyGunfire(civilian)
    local player =
        PlayerPedId()

    if IsPedShooting(player) then
        local distance =
            distanceBetween(
                GetEntityCoords(civilian),
                GetEntityCoords(player)
            )

        if distance <= PANIC_RADIUS then
            return true
        end
    end

    local threat =
        getActiveThreat()

    if threat
        and IsPedShooting(threat) then

        local distance =
            distanceBetween(
                GetEntityCoords(civilian),
                GetEntityCoords(threat)
            )

        if distance <= PANIC_RADIUS then
            return true
        end
    end

    return false
end

-- =========================================================
-- COMPORTAMIENTO CIVIL
-- =========================================================

local function setCivilState(
    civilian,
    newState
)
    local data =
        CityLifeManager.Civilians[civilian]

    if not data
        or data.state == newState then

        return
    end

    data.state = newState
    data.lastReactionAt =
        GetGameTimer()

    if BehaviorManager
        and type(
            BehaviorManager.SetState
        ) == "function" then

        BehaviorManager.SetState(
            civilian,
            newState
        )
    end
end

local function panicCivilian(
    civilian,
    threat
)
    if not isValidPed(civilian) then
        return
    end

    setCivilState(
        civilian,
        "PANIC"
    )

    ClearPedTasks(civilian)

    if threat
        and DoesEntityExist(threat) then

        TaskSmartFleePed(
            civilian,
            threat,
            120.0,
            30000,
            false,
            false
        )
    else
        TaskSmartFleePed(
            civilian,
            PlayerPedId(),
            90.0,
            20000,
            false,
            false
        )
    end
end

local function watchScene(civilian)
    if not isValidPed(civilian) then
        return
    end

    setCivilState(
        civilian,
        "WATCHING"
    )

    TaskTurnPedToFaceEntity(
        civilian,
        PlayerPedId(),
        2500
    )
end

local function returnToNormal(
    civilian
)
    if not isValidPed(civilian) then
        return
    end

    local data =
        CityLifeManager.Civilians[
            civilian
        ]

    if not data
        or data.state == "NORMAL" then

        return
    end

    setCivilState(
        civilian,
        "NORMAL"
    )

    ClearPedTasks(civilian)

    TaskWanderStandard(
        civilian,
        10.0,
        10
    )
end

local function updateCivilian(
    civilian
)
    if not isValidPed(civilian) then
        unregisterCivilian(civilian)
        return
    end

    local playerCoords =
        GetEntityCoords(PlayerPedId())

    local civilianCoords =
        GetEntityCoords(civilian)

    local distance =
        distanceBetween(
            playerCoords,
            civilianCoords
        )

    if distance > CLEANUP_RADIUS then
        unregisterCivilian(civilian)
        return
    end

    local threat =
        getActiveThreat()

    if nearbyGunfire(civilian) then
        panicCivilian(
            civilian,
            threat
        )

        return
    end

    if sceneIsDangerous()
        and threat
        and DoesEntityExist(threat) then

        local threatDistance =
            distanceBetween(
                civilianCoords,
                GetEntityCoords(threat)
            )

        if threatDistance
            <= PANIC_RADIUS then

            panicCivilian(
                civilian,
                threat
            )

            return
        end
    end

    local data =
        CityLifeManager.Civilians[
            civilian
        ]

    if not sceneIsDangerous()
        and data
        and data.state == "PANIC"
        and GetGameTimer()
            - data.lastReactionAt
            >= 12000 then

        returnToNormal(civilian)
        return
    end

    if PlayerData
        and PlayerData.DispatchState
            == "ON_SCENE"
        and distance <= WATCH_RADIUS
        and data
        and data.state == "NORMAL" then

        -- Solo una pequeña posibilidad para
        -- evitar que toda la calle se quede mirando.
        if math.random(1, 100) <= 8 then
            watchScene(civilian)
        end
    end
end

-- =========================================================
-- SCANNER
-- =========================================================

local function scanNearbyCivilians()
    if not CityLifeManager.Active then
        return
    end

    local playerCoords =
        GetEntityCoords(PlayerPedId())

    local peds =
        GetGamePool("CPed")

    for _, ped in ipairs(peds) do
        if countTracked()
            >= MAX_TRACKED_CIVILIANS then

            break
        end

        if canTrackPed(ped)
            and not CityLifeManager
                .Civilians[ped] then

            local coords =
                GetEntityCoords(ped)

            local distance =
                distanceBetween(
                    playerCoords,
                    coords
                )

            if distance <= SCAN_RADIUS then
                registerCivilian(ped)
            end
        end
    end
end

-- =========================================================
-- API
-- =========================================================

function CityLifeManager.GetCivilianCount()
    return countTracked()
end

function CityLifeManager.Reset()
    local civilians = {}

    for ped in pairs(
        CityLifeManager.Civilians
    ) do
        civilians[#civilians + 1] =
            ped
    end

    for _, ped in ipairs(civilians) do
        unregisterCivilian(ped)
    end

    CityLifeManager.Civilians = {}
end

function CityLifeManager.SetActive(
    enabled
)
    CityLifeManager.Active =
        enabled == true

    if not CityLifeManager.Active then
        CityLifeManager.Reset()
    end
end

RegisterCommand(
    "citylife",
    function()
        Sentinel.Notify(
            "CITY LIFE",
            (
                "Civiles supervisados: %d\nSistema: %s"
            ):format(
                CityLifeManager
                    .GetCivilianCount(),

                CityLifeManager.Active
                    and "ACTIVO"
                    or "INACTIVO"
            ),
            {170, 140, 255}
        )
    end,
    false
)

RegisterCommand(
    "citylifetoggle",
    function()
        CityLifeManager.SetActive(
            not CityLifeManager.Active
        )

        Sentinel.Notify(
            "CITY LIFE",
            CityLifeManager.Active
                and "Simulación civil activada."
                or "Simulación civil desactivada.",
            {90, 190, 255}
        )
    end,
    false
)

-- =========================================================
-- THREADS
-- =========================================================

CreateThread(function()
    while true do
        Wait(SCAN_INTERVAL)

        if CityLifeManager.Active then
            scanNearbyCivilians()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(750)

        if CityLifeManager.Active then
            local civilians = {}

            for ped in pairs(
                CityLifeManager.Civilians
            ) do
                civilians[
                    #civilians + 1
                ] = ped
            end

            for _, civilian in ipairs(
                civilians
            ) do
                updateCivilian(civilian)
            end
        end
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        CityLifeManager.Reset()
    end
)

print("[Sentinel AI] CityLifeManager listo.")