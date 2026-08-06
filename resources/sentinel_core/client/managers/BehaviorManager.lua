BehaviorManager = {
    Actors = {},
    NextId = 1
}

local profileNames = {
    "COWARD",
    "NERVOUS",
    "OPPORTUNIST",
    "AGGRESSIVE",
    "DESPERATE"
}

local function clamp(value, minimum, maximum)
    return math.max(
        minimum,
        math.min(maximum, value)
    )
end

local function randomRange(range)
    if type(range) ~= "table" then
        return 0
    end

    return math.random(
        tonumber(range[1]) or 0,
        tonumber(range[2]) or 100
    )
end

local function getActorKey(entity)
    return tostring(entity)
end

local function selectRandomProfile()
    local profileName =
        profileNames[math.random(#profileNames)]

    return profileName,
        BehaviorProfiles[profileName]
end

function BehaviorManager.RegisterActor(
    entity,
    role,
    forcedProfile
)
    if not entity
        or entity == 0
        or not DoesEntityExist(entity) then

        return nil
    end

    local profileName = forcedProfile
    local profile = forcedProfile
        and BehaviorProfiles[forcedProfile]
        or nil

    if not profile then
        profileName, profile =
            selectRandomProfile()
    end

    local actor = {
        id = BehaviorManager.NextId,
        entity = entity,
        role = role or "CIVILIAN",

        profile = profileName,
        profileLabel = profile.label,

        fear = randomRange(profile.fear),
        aggression = randomRange(profile.aggression),
        courage = randomRange(profile.courage),

        surrenderBonus =
            tonumber(profile.surrenderBonus) or 0,

        state = "IDLE",
        memories = {},
        createdAt = GetGameTimer(),
        lastDecisionAt = 0
    }

    BehaviorManager.NextId =
        BehaviorManager.NextId + 1

    BehaviorManager.Actors[
        getActorKey(entity)
    ] = actor

    return actor
end

function BehaviorManager.GetActor(entity)
    if not entity then
        return nil
    end

    return BehaviorManager.Actors[
        getActorKey(entity)
    ]
end

function BehaviorManager.RemoveActor(entity)
    if not entity then
        return false
    end

    BehaviorManager.Actors[
        getActorKey(entity)
    ] = nil

    return true
end

function BehaviorManager.SetState(entity, state)
    local actor =
        BehaviorManager.GetActor(entity)

    if not actor then
        return false
    end

    actor.state = state or "IDLE"
    actor.lastDecisionAt = GetGameTimer()

    return true
end

function BehaviorManager.Remember(
    entity,
    memoryType,
    value
)
    local actor =
        BehaviorManager.GetActor(entity)

    if not actor then
        return false
    end

    actor.memories[
        memoryType
    ] = {
        value = value,
        time = GetGameTimer()
    }

    return true
end

function BehaviorManager.AdjustEmotion(
    entity,
    emotion,
    amount
)
    local actor =
        BehaviorManager.GetActor(entity)

    if not actor
        or actor[emotion] == nil then

        return false
    end

    actor[emotion] = clamp(
        actor[emotion] + (tonumber(amount) or 0),
        0,
        100
    )

    return true
end

function BehaviorManager.GetSurrenderChance(
    entity,
    context
)
    local actor =
        BehaviorManager.GetActor(entity)

    if not actor then
        return 60
    end

    context = context or {}

    local chance = 40

    chance = chance
        + actor.fear * 0.45

    chance = chance
        - actor.aggression * 0.35

    chance = chance
        - actor.courage * 0.15

    chance = chance
        + actor.surrenderBonus

    local health =
        tonumber(context.health) or 200

    if health <= 120 then
        chance = chance + 20
    elseif health <= 160 then
        chance = chance + 10
    end

    if context.playerAiming then
        chance = chance + 12
    end

    if context.fleeing then
        chance = chance - 8
    end

    if context.alreadyOrdered then
        chance = chance + 8
    end

    return math.floor(
        clamp(chance, 5, 95)
    )
end

function BehaviorManager.DecideSurrender(
    entity,
    context
)
    local actor =
        BehaviorManager.GetActor(entity)

    if not actor then
        actor = BehaviorManager.RegisterActor(
            entity,
            "SUSPECT"
        )
    end

    if not actor then
        return false, 0
    end

    local chance =
        BehaviorManager.GetSurrenderChance(
            entity,
            context
        )

    local roll = math.random(1, 100)
    local surrendered = roll <= chance

    actor.lastDecisionAt = GetGameTimer()

    BehaviorManager.Remember(
        entity,
        "LAST_SURRENDER_DECISION",
        {
            chance = chance,
            roll = roll,
            surrendered = surrendered
        }
    )

    if surrendered then
        actor.state = "SURRENDERED"
    else
        actor.state = "RESISTING"

        BehaviorManager.AdjustEmotion(
            entity,
            "aggression",
            8
        )

        BehaviorManager.AdjustEmotion(
            entity,
            "fear",
            5
        )
    end

    return surrendered, chance
end

function BehaviorManager.GetDebugDescription(entity)
    local actor =
        BehaviorManager.GetActor(entity)

    if not actor then
        return "Actor sin perfil"
    end

    return string.format(
        "%s | Miedo %d | Agresividad %d | Valentía %d",
        actor.profileLabel,
        actor.fear,
        actor.aggression,
        actor.courage
    )
end

function BehaviorManager.CleanupMissingActors()
    for key, actor in pairs(
        BehaviorManager.Actors
    ) do
        if not actor.entity
            or not DoesEntityExist(
                actor.entity
            ) then

            BehaviorManager.Actors[key] = nil
        end
    end
end

RegisterCommand(
    "suspectbrain",
    function()
        local suspect =
            GetActiveSuspect
            and GetActiveSuspect()
            or nil

        if not suspect then
            Sentinel.Notify(
                "DEV",
                "No existe un sospechoso activo.",
                {255, 180, 0}
            )

            return
        end

        Sentinel.Notify(
            "DEV",
            BehaviorManager.GetDebugDescription(
                suspect
            ),
            {170, 140, 255}
        )
    end,
    false
)

CreateThread(function()
    while true do
        Wait(5000)
        BehaviorManager.CleanupMissingActors()
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        BehaviorManager.Actors = {}
    end
)