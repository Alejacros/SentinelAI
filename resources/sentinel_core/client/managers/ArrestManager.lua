local arrestLocked = false

local function loadAnimationDictionary(dictionary)
    RequestAnimDict(dictionary)

    local timeout = GetGameTimer() + 5000

    while not HasAnimDictLoaded(dictionary) do
        Wait(50)

        if GetGameTimer() >= timeout then
            return false
        end
    end

    return true
end

local function arrestSuspect()
    if arrestLocked then
        return
    end

    local suspect = GetActiveSuspect()

    if not suspect
        or not DoesEntityExist(suspect)
        or IsEntityDead(suspect)
        or not IsSuspectSurrendered() then

        return
    end

    arrestLocked = true

    ClearPedTasksImmediately(suspect)
    RemoveAllPedWeapons(suspect, true)

    SetEnableHandcuffs(suspect, true)
    SetBlockingOfNonTemporaryEvents(suspect, true)
    SetPedCanRagdoll(suspect, false)
    SetEntityInvincible(suspect, true)

    local animationDictionary = "mp_arresting"

    if loadAnimationDictionary(animationDictionary) then
        TaskPlayAnim(
            suspect,
            animationDictionary,
            "idle",
            8.0,
            -8.0,
            -1,
            49,
            0.0,
            false,
            false,
            false
        )

        RemoveAnimDict(animationDictionary)
    else
        TaskHandsUp(
            suspect,
            -1,
            PlayerPedId(),
            -1,
            true
        )
    end

    FreezeEntityPosition(suspect, true)

    MarkSuspectArrested()

    arrestLocked = false
end

CreateThread(function()
    while true do
        local sleep = 500

        if IsSuspectSurrendered() then
            local suspect = GetActiveSuspect()

            if suspect and DoesEntityExist(suspect) then
                local playerCoords =
                    GetEntityCoords(PlayerPedId())

                local suspectCoords =
                    GetEntityCoords(suspect)

                local distance =
                    #(playerCoords - suspectCoords)

                if distance <= 2.2 then
                    sleep = 0

                    BeginTextCommandDisplayHelp("STRING")

                    AddTextComponentSubstringPlayerName(
                        "Pulsa ~INPUT_CONTEXT~ para esposar al sospechoso."
                    )

                    EndTextCommandDisplayHelp(
                        0,
                        false,
                        true,
                        -1
                    )

                    if IsControlJustPressed(0, 38) then -- E
                        arrestSuspect()
                    end
                end
            end
        end

        Wait(sleep)
    end
end)