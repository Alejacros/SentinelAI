print("[Sentinel AI] Cargando PatrolManager...")

PatrolManager = {
    Active = false,

    NextMessageAt = 0,
    LastMessage = nil,

    LastPosition = nil,
    DistanceTravelled = 0.0,
    NextDistanceReward = 800.0,

    LastSpeedWarningAt = 0
}

local MIN_MESSAGE_DELAY = 45000
local MAX_MESSAGE_DELAY = 90000

local DISTANCE_REWARD_METERS = 800.0
local DISTANCE_REWARD_XP = 2

local MAX_VALID_MOVEMENT_STEP = 100.0
local SPEED_WARNING_KMH = 150.0
local SPEED_WARNING_COOLDOWN = 45000

local function notify(message, color)
    Sentinel.Notify(
        "CENTRAL",
        message,
        color or {90, 190, 255}
    )
end

local function scheduleNextMessage()
    PatrolManager.NextMessageAt =
        GetGameTimer()
        + math.random(
            MIN_MESSAGE_DELAY,
            MAX_MESSAGE_DELAY
        )
end

local function chooseDifferentMessage(messages)
    if type(messages) ~= "table"
        or #messages == 0 then

        return nil
    end

    if #messages == 1 then
        return messages[1]
    end

    local selected

    repeat
        selected =
            messages[
                math.random(#messages)
            ]
    until selected ~= PatrolManager.LastMessage

    return selected
end

local function getWeatherCategory()
    if IsNextWeatherType("RAIN")
        or IsNextWeatherType("THUNDER")
        or IsNextWeatherType("CLEARING") then

        return "RAIN"
    end

    return nil
end

local function getTimeCategory()
    local hour = GetClockHours()

    if hour >= 21
        or hour < 6 then

        return "NIGHT"
    end

    return nil
end

local function buildMessagePool()
    local pool = {}

    local function appendCategory(category)
        local messages =
            PatrolMessages
            and PatrolMessages[category]
            or nil

        if type(messages) ~= "table" then
            return
        end

        for _, message in ipairs(messages) do
            pool[#pool + 1] = message
        end
    end

    appendCategory("GENERAL")

    local timeCategory =
        getTimeCategory()

    if timeCategory then
        appendCategory(timeCategory)
    end

    local weatherCategory =
        getWeatherCategory()

    if weatherCategory then
        appendCategory(weatherCategory)
    end

    return pool
end

local function sendPatrolMessage()
    local message =
        chooseDifferentMessage(
            buildMessagePool()
        )

    if not message then
        return false
    end

    PatrolManager.LastMessage =
        message

    notify(message)

    if BodyCamManager
        and BodyCamManager.Active
        and type(BodyCamManager.Log) == "function" then

        BodyCamManager.Log(
            "Mensaje de central: "
                .. message,
            "RADIO"
        )
    end

    return true
end

local function awardPatrolXP()
    if type(AwardXP) == "function" then
        AwardXP(DISTANCE_REWARD_XP)
    end

    notify(
        (
            "Buen patrullaje, unidad. "
            .. "Presencia preventiva registrada. +%d XP"
        ):format(
            DISTANCE_REWARD_XP
        ),
        {80, 220, 140}
    )

    if BodyCamManager
        and BodyCamManager.Active
        and type(BodyCamManager.Log) == "function" then

        BodyCamManager.Log(
            (
                "Patrullaje preventivo completado: "
                .. "%d metros."
            ):format(
                DISTANCE_REWARD_METERS
            ),
            "PATROL"
        )
    end
end

local function updateDistance()
    local playerPed =
        PlayerPedId()

    local currentPosition =
        GetEntityCoords(playerPed)

    if not PatrolManager.LastPosition then
        PatrolManager.LastPosition =
            currentPosition

        return
    end

    local travelled =
        #(currentPosition - PatrolManager.LastPosition)

    PatrolManager.LastPosition =
        currentPosition

    -- Evita que el teletransporte otorgue XP.
    if travelled <= 0.1
        or travelled > MAX_VALID_MOVEMENT_STEP then

        return
    end

    PatrolManager.DistanceTravelled =
        PatrolManager.DistanceTravelled
        + travelled

    if PatrolManager.DistanceTravelled
        >= PatrolManager.NextDistanceReward then

        awardPatrolXP()

        PatrolManager.NextDistanceReward =
            PatrolManager.NextDistanceReward
            + DISTANCE_REWARD_METERS
    end
end

local function checkPatrolSpeed()
    local playerPed =
        PlayerPedId()

    if not IsPedInAnyVehicle(
        playerPed,
        false
    ) then

        return
    end

    local vehicle =
        GetVehiclePedIsIn(
            playerPed,
            false
        )

    if vehicle == 0
        or GetPedInVehicleSeat(
            vehicle,
            -1
        ) ~= playerPed then

        return
    end

    local speedKmh =
        GetEntitySpeed(vehicle) * 3.6

    if speedKmh < SPEED_WARNING_KMH then
        return
    end

    local now =
        GetGameTimer()

    if now <
        PatrolManager.LastSpeedWarningAt
        + SPEED_WARNING_COOLDOWN then

        return
    end

    PatrolManager.LastSpeedWarningAt =
        now

    local messages =
        PatrolMessages
        and PatrolMessages.HIGH_SPEED
        or nil

    local message =
        chooseDifferentMessage(messages)

    if message then
        PatrolManager.LastMessage =
            message

        notify(
            message,
            {255, 180, 0}
        )
    end
end

function PatrolManager.Start()
    if PatrolManager.Active then
        return false
    end

    PatrolManager.Active = true

    PatrolManager.LastPosition =
        GetEntityCoords(
            PlayerPedId()
        )

    scheduleNextMessage()

    print(
        "[Sentinel AI] Patrullaje vivo iniciado."
    )

    return true
end

function PatrolManager.Stop()
    if not PatrolManager.Active then
        return false
    end

    PatrolManager.Active = false
    PatrolManager.LastPosition = nil
    PatrolManager.NextMessageAt = 0

    print(
        "[Sentinel AI] Patrullaje vivo detenido."
    )

    return true
end

function PatrolManager.Reset()
    PatrolManager.Active = false

    PatrolManager.NextMessageAt = 0
    PatrolManager.LastMessage = nil

    PatrolManager.LastPosition = nil
    PatrolManager.DistanceTravelled = 0.0
    PatrolManager.NextDistanceReward =
        DISTANCE_REWARD_METERS

    PatrolManager.LastSpeedWarningAt = 0
end

function PatrolManager.GetStatus()
    return {
        active =
            PatrolManager.Active,

        distanceTravelled =
            PatrolManager.DistanceTravelled,

        nextRewardAt =
            PatrolManager.NextDistanceReward
    }
end

RegisterCommand(
    "patrolstatus",
    function()
        local status =
            PatrolManager.GetStatus()

        notify(
            (
                "Patrullaje: %s\n"
                .. "Distancia: %.0f m\n"
                .. "Próxima recompensa: %.0f m"
            ):format(
                status.active
                    and "ACTIVO"
                    or "INACTIVO",

                status.distanceTravelled,
                status.nextRewardAt
            ),
            {170, 140, 255}
        )
    end,
    false
)

CreateThread(function()
    while true do
        Wait(500)

        if not PlayerData then
            goto continue
        end

        local shouldPatrol =
            PlayerData.OnDuty == true
            and PlayerData.DispatchState
                == "WAITING"

        if shouldPatrol
            and not PatrolManager.Active then

            PatrolManager.Start()

        elseif not shouldPatrol
            and PatrolManager.Active then

            PatrolManager.Stop()
        end

        if PatrolManager.Active then
            updateDistance()
            checkPatrolSpeed()

            if GetGameTimer()
                >= PatrolManager.NextMessageAt then

                sendPatrolMessage()
                scheduleNextMessage()
            end
        end

        ::continue::
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        PatrolManager.Reset()
    end
)

print("[Sentinel AI] PatrolManager listo.")