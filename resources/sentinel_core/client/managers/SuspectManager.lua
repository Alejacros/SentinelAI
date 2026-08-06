SuspectSystem = {
    Entity = nil,
    State = "NONE",
    PreviousDirectorState = nil,
    OutcomeRecorded = false,
    LastOrderAt = 0
}

local function notify(message, color)
    Sentinel.Notify(
        "CENTRAL",
        message,
        color or {255, 170, 60}
    )
end

local function resetSuspectSystem()
    SuspectSystem.Entity = nil
    SuspectSystem.State = "NONE"
    SuspectSystem.PreviousDirectorState = nil
    SuspectSystem.OutcomeRecorded = false
    SuspectSystem.LastOrderAt = 0
end

local function recordOutcome(outcome)
    if SuspectSystem.OutcomeRecorded then
        return
    end

    SuspectSystem.OutcomeRecorded = true

    if AddSuspectOutcomeToCurrentCase then
        AddSuspectOutcomeToCurrentCase(outcome)
    end
end

local function registerDirectorSuspect()
    if not SceneDirector
        or not SceneDirector.Suspect
        or not DoesEntityExist(
            SceneDirector.Suspect
        ) then

        return
    end

    if SuspectSystem.Entity
        == SceneDirector.Suspect then

        return
    end

    SuspectSystem.Entity =
        SceneDirector.Suspect

    SuspectSystem.PreviousDirectorState =
        SceneDirector.State

    SuspectSystem.OutcomeRecorded = false

    if SceneDirector.State
        == "SUSPECT_FLEEING" then

        SuspectSystem.State = "FLEEING"
    else
        SuspectSystem.State = "HOSTILE"
    end
end

local function surrenderSuspect()
    local suspect = SuspectSystem.Entity

    if not suspect
        or not DoesEntityExist(suspect)
        or IsEntityDead(suspect) then

        return
    end

    SuspectSystem.State = "SURRENDERED"

    ClearPedTasksImmediately(suspect)
    RemoveAllPedWeapons(suspect, true)

    SetBlockingOfNonTemporaryEvents(
        suspect,
        true
    )

    TaskHandsUp(
        suspect,
        -1,
        PlayerPedId(),
        -1,
        true
    )

    SceneDirector.State =
        "SUSPECT_SURRENDERED"

    SceneDirector.Objective =
        "El sospechoso se rindió. Acérquese y espóselo."

    notify(
        "El sospechoso se rindió. Acérquese y pulse E.",
        {80, 220, 140}
    )
end

local function resistArrest()
    local suspect = SuspectSystem.Entity

    if not suspect
        or not DoesEntityExist(suspect)
        or IsEntityDead(suspect) then

        return
    end

    SuspectSystem.State = "HOSTILE"

    GiveWeaponToPed(
        suspect,
        GetHashKey("WEAPON_PISTOL"),
        36,
        false,
        true
    )

    SetPedAccuracy(suspect, 12)
    SetPedCombatAbility(suspect, 1)
    SetPedCombatMovement(suspect, 1)
    SetBlockingOfNonTemporaryEvents(
        suspect,
        true
    )

    SceneDirector.State =
        "ACTIVE_THREAT"

    SceneDirector.Objective =
        "El sospechoso se resiste. Controle la amenaza."

    notify(
        "¡El sospechoso se resiste!",
        {255, 80, 80}
    )

    TaskCombatPed(
        suspect,
        PlayerPedId(),
        0,
        16
    )
end

local function orderSurrender()
    local now = GetGameTimer()

    if now < SuspectSystem.LastOrderAt then
        return
    end

    SuspectSystem.LastOrderAt =
        now + 2000

    local suspect =
        SuspectSystem.Entity

    if not suspect
        or not DoesEntityExist(suspect)
        or IsEntityDead(suspect) then

        return
    end

    ClearPedTasksImmediately(suspect)

    local surrenderChance = 85

    if SuspectSystem.State == "FLEEING" then
        surrenderChance = 75
    end

    if math.random(1, 100)
        <= surrenderChance then

        surrenderSuspect()
    else
        resistArrest()
    end
end

function GetActiveSuspect()
    if SuspectSystem.Entity
        and DoesEntityExist(
            SuspectSystem.Entity
        ) then

        return SuspectSystem.Entity
    end

    return nil
end

function IsSuspectSurrendered()
    return SuspectSystem.State
        == "SURRENDERED"
end

function IsSuspectArrested()
    return SuspectSystem.State
        == "ARRESTED"
end

function GetSuspectState()
    return SuspectSystem.State
end

function MarkSuspectArrested()
    SuspectSystem.State = "ARRESTED"

    recordOutcome("ARRESTED")

    if SceneDirector then
        SceneDirector.State = "SAFE"
        SceneDirector.Objective =
            "Sospechoso detenido. Entreviste al testigo."
    end

    notify(
        "Sospechoso bajo custodia. Continúe con la investigación.",
        {80, 220, 140}
    )
end

CreateThread(function()
    while true do
        Wait(250)

        registerDirectorSuspect()

        local suspect = GetActiveSuspect()

        if suspect then
            if IsEntityDead(suspect)
                and SuspectSystem.State
                    ~= "NEUTRALIZED"
                and SuspectSystem.State
                    ~= "ARRESTED" then

                SuspectSystem.State =
                    "NEUTRALIZED"

                recordOutcome(
                    "NEUTRALIZED"
                )

            elseif SceneDirector.State == "SAFE"
                and SuspectSystem.State == "FLEEING"
                and not SuspectSystem.OutcomeRecorded then

                SuspectSystem.State = "ESCAPED"
                recordOutcome("ESCAPED")
            end
        end

        if SceneDirector
            and SceneDirector.State == "IDLE"
            and SuspectSystem.State ~= "NONE"
            and not IsCustodyTransportActive() then

            resetSuspectSystem()
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 500
        local suspect = GetActiveSuspect()

        if suspect
            and not IsEntityDead(suspect)
            and (
                SuspectSystem.State == "HOSTILE"
                or SuspectSystem.State == "FLEEING"
            ) then

            local distance = #(
                GetEntityCoords(PlayerPedId())
                - GetEntityCoords(suspect)
            )

            if distance <= 30.0 then
                sleep = 0

                DrawMarker(
                    2,
                    GetEntityCoords(suspect).x,
                    GetEntityCoords(suspect).y,
                    GetEntityCoords(suspect).z + 2.1,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    180.0,
                    0.0,
                    0.45,
                    0.45,
                    0.45,
                    255,
                    40,
                    40,
                    255,
                    false,
                    true,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )

                BeginTextCommandDisplayHelp("STRING")

                AddTextComponentSubstringPlayerName(
                    "Pulsa ~INPUT_DETONATE~ para ordenar al sospechoso que se rinda."
                )

                EndTextCommandDisplayHelp(
                    0,
                    false,
                    true,
                    -1
                )

                if IsControlJustPressed(0, 47) then
                    orderSurrender()
                end
            end
        end

        Wait(sleep)
    end
end)