SuspectSystem = {
    Entity = nil,
    State = "NONE",
    PreviousDirectorState = nil,
    OutcomeRecorded = false,
    LastOrderAt = 0,
    OrderCount = 0,

    Profile = nil,
    CurrentDecision = nil,
    NextThink = 0,

    Memory = {
    Confidence = 100,
    HasSeenPlayer = false,
    HasBeenShot = false,
    LastHealth = 200
    }
}
local function Think()

    local suspect = GetActiveSuspect()

    if not suspect then
        return
    end

    if IsEntityDead(suspect) then
        return
    end

    if not SuspectSystem.Profile then
        return
    end

    if SuspectSystem.State ~= "HOSTILE"
        and SuspectSystem.State ~= "FLEEING" then

        return
    end

    local profile =
        SuspectSystem.Profile

    local decision

    if profile.name == "COWARD" then

        decision = "RUN"

    elseif profile.name == "VIOLENT" then

        decision = "ATTACK"

    else

        decision = "COVER"

    end

    if decision == SuspectSystem.CurrentDecision then
        return
    end

    SuspectSystem.CurrentDecision = decision

    print(
        ("[Suspect AI] %s -> %s")
        :format(
            profile.name,
            decision
        )
    )

    if decision == "RUN" then

        TaskSmartFleePed(
            suspect,
            PlayerPedId(),
            200.0,
            -1,
            false,
            false
        )

    elseif decision == "ATTACK" then

        TaskCombatPed(
            suspect,
            PlayerPedId(),
            0,
            16
        )

    elseif decision == "COVER" then

        TaskSeekCoverFromPed(
            suspect,
            PlayerPedId(),
            15000,
            false
        )

    end

end

local function notify(message, color)
    Sentinel.Notify(
        "CENTRAL",
        message,
        color or {255, 170, 60}
    )
end

local function resetSuspectSystem()
    if SuspectSystem.Entity
        and BehaviorManager then

        BehaviorManager.RemoveActor(
            SuspectSystem.Entity
        )
    end

    SuspectSystem.Entity = nil
    SuspectSystem.State = "NONE"
    SuspectSystem.PreviousDirectorState = nil
    SuspectSystem.OutcomeRecorded = false
    SuspectSystem.LastOrderAt = 0
    SuspectSystem.OrderCount = 0
end

local personalities = {

    {
        name = "COWARD",
        fear = 90,
        aggression = 10,
        courage = 20
    },

    {
        name = "VIOLENT",
        fear = 20,
        aggression = 90,
        courage = 80
    },

    {
        name = "PROFESSIONAL",
        fear = 35,
        aggression = 55,
        courage = 95
    }

}

local function AssignProfile()

    local profile =
        personalities[
            math.random(#personalities)
        ]

    SuspectSystem.Profile = profile
    SuspectSystem.Memory = {

    Confidence = math.random(70,100),

    HasSeenPlayer = false,

    HasBeenShot = false,

    LastHealth = 200

}
    SuspectSystem.CurrentDecision = nil

    print(
        ("[Suspect AI] Nuevo perfil -> %s | Fear:%d | Agg:%d | Courage:%d")
        :format(
            profile.name,
            profile.fear,
            profile.aggression,
            profile.courage
        )
    )

end

local function recordOutcome(outcome)
    if SuspectSystem.OutcomeRecorded then
        return
    end

    SuspectSystem.OutcomeRecorded = true

    if AddSuspectOutcomeToCurrentCase then
        AddSuspectOutcomeToCurrentCase(
            outcome
        )
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

        AssignProfile()

    SuspectSystem.PreviousDirectorState =
        SceneDirector.State

    SuspectSystem.OutcomeRecorded = false
    SuspectSystem.OrderCount = 0

    if SceneDirector.State
        == "SUSPECT_FLEEING" then

        SuspectSystem.State = "FLEEING"
    else
        SuspectSystem.State = "HOSTILE"
    end

    local actor =
        BehaviorManager.RegisterActor(
            SuspectSystem.Entity,
            "SUSPECT"
        )

    if actor then
        BehaviorManager.SetState(
            SuspectSystem.Entity,
            SuspectSystem.State
        )

        print(
            "[Sentinel AI] Sospechoso creado: "
                .. BehaviorManager
                    .GetDebugDescription(
                        SuspectSystem.Entity
                    )
        )
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

    BehaviorManager.SetState(
        suspect,
        "SURRENDERED"
    )

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

    BehaviorManager.SetState(
        suspect,
        "RESISTING"
    )

    GiveWeaponToPed(
        suspect,
        GetHashKey("WEAPON_PISTOL"),
        36,
        false,
        true
    )

    local actor =
        BehaviorManager.GetActor(suspect)

    local accuracy = 12

    if actor then
        accuracy = math.floor(
            6 + actor.aggression * 0.18
        )
    end

    SetPedAccuracy(
        suspect,
        math.min(28, accuracy)
    )

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

    SuspectSystem.OrderCount =
        SuspectSystem.OrderCount + 1

    local suspect =
        SuspectSystem.Entity

    if not suspect
        or not DoesEntityExist(suspect)
        or IsEntityDead(suspect) then

        return
    end

    local playerPed = PlayerPedId()

    local playerAiming =
        IsPlayerFreeAimingAtEntity(
            PlayerId(),
            suspect
        )

    local health =
        GetEntityHealth(suspect)

    local surrendered, chance =
        BehaviorManager.DecideSurrender(
            suspect,
            {
                health = health,
                playerAiming = playerAiming,
                fleeing =
                    SuspectSystem.State
                        == "FLEEING",
                alreadyOrdered =
                    SuspectSystem.OrderCount > 1
            }
        )

    print(
        (
            "[Sentinel AI] Orden de rendición: %d%% | resultado: %s"
        ):format(
            chance,
            surrendered
                and "RENDICIÓN"
                or "RESISTENCIA"
        )
    )

    ClearPedTasksImmediately(suspect)

    if surrendered then
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

    local suspect =
        GetActiveSuspect()

    if suspect then
        BehaviorManager.SetState(
            suspect,
            "ARRESTED"
        )
    end

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
if not SuspectSystem.NextThink
    or GetGameTimer() >= SuspectSystem.NextThink then

    SuspectSystem.NextThink =
        GetGameTimer() + 2000

    Think()

end
        registerDirectorSuspect()

        local suspect =
            GetActiveSuspect()

        if suspect then
            if IsEntityDead(suspect)
                and SuspectSystem.State
                    ~= "NEUTRALIZED"
                and SuspectSystem.State
                    ~= "ARRESTED" then

                SuspectSystem.State =
                    "NEUTRALIZED"

                BehaviorManager.SetState(
                    suspect,
                    "NEUTRALIZED"
                )

                recordOutcome(
                    "NEUTRALIZED"
                )

            elseif SceneDirector.State == "SAFE"
                and SuspectSystem.State == "FLEEING"
                and not SuspectSystem
                    .OutcomeRecorded then

                SuspectSystem.State =
                    "ESCAPED"

                BehaviorManager.SetState(
                    suspect,
                    "ESCAPED"
                )

                recordOutcome(
                    "ESCAPED"
                )
            end
        end

        if SceneDirector
            and SceneDirector.State == "IDLE"
            and SuspectSystem.State ~= "NONE"
            and (
                not IsCustodyTransportActive
                or not IsCustodyTransportActive()
            ) then

            resetSuspectSystem()
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 500

        local suspect =
            GetActiveSuspect()

        if suspect
            and not IsEntityDead(suspect)
            and (
                SuspectSystem.State == "HOSTILE"
                or SuspectSystem.State == "FLEEING"
            ) then

            local suspectCoords =
                GetEntityCoords(suspect)

            local distance = #(
                GetEntityCoords(PlayerPedId())
                - suspectCoords
            )

            if distance <= 30.0 then
                sleep = 0

                DrawMarker(
                    2,
                    suspectCoords.x,
                    suspectCoords.y,
                    suspectCoords.z + 2.1,
                    0.0, 0.0, 0.0,
                    0.0, 180.0, 0.0,
                    0.45, 0.45, 0.45,
                    255, 40, 40, 255,
                    false,
                    true,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )

                BeginTextCommandDisplayHelp(
                    "STRING"
                )

                AddTextComponentSubstringPlayerName(
                    "Pulsa ~INPUT_DETONATE~ para ordenar al sospechoso que se rinda."
                )

                EndTextCommandDisplayHelp(
                    0,
                    false,
                    true,
                    -1
                )

                if IsControlJustPressed(
                    0,
                    47
                ) then

                    orderSurrender()
                end
            end
        end

        Wait(sleep)
    end
end)