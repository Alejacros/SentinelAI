local stationSpawn = vector4(441.2, -981.9, 30.7, 90.0)

local allowedBodyModels = {
    mp_f_freemode_01 = true,
    mp_m_freemode_01 = true
}

local function printPedDiagnostics(label, ped)
    local collisionDisabled = "native_unavailable"

    if type(GetEntityCollisionDisabled) == "function" then
        local success, result =
            pcall(GetEntityCollisionDisabled, ped)

        collisionDisabled = success
            and tostring(result)
            or ("error:" .. tostring(result))
    end

    print((
        "[Sentinel AI] PED DIAG | stage=%s | ped=%s | exists=%s | visible=%s | alpha=%s | frozen=%s | collisionDisabled=%s | model=%s"
    ):format(
        tostring(label),
        tostring(ped),
        tostring(DoesEntityExist(ped)),
        tostring(IsEntityVisible(ped)),
        tostring(GetEntityAlpha(ped)),
        tostring(IsEntityPositionFrozen(ped)),
        collisionDisabled,
        tostring(GetEntityModel(ped))
    ))
end

local function spawnAtStation(preserveAppearance)
    local ped = PlayerPedId()

    DoScreenFadeOut(500)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    RequestCollisionAtCoord(
        stationSpawn.x,
        stationSpawn.y,
        stationSpawn.z
    )

    SetFocusPosAndVel(
        stationSpawn.x,
        stationSpawn.y,
        stationSpawn.z,
        0.0,
        0.0,
        0.0
    )

    SetEntityCoordsNoOffset(
        ped,
        stationSpawn.x,
        stationSpawn.y,
        stationSpawn.z,
        false,
        false,
        false
    )

    FreezeEntityPosition(ped, true)

    local collisionTimeout =
        GetGameTimer() + 10000

    while not HasCollisionLoadedAroundEntity(ped)
        and GetGameTimer() < collisionTimeout do

        RequestCollisionAtCoord(
            stationSpawn.x,
            stationSpawn.y,
            stationSpawn.z
        )

        Wait(100)
    end

    NetworkResurrectLocalPlayer(
    stationSpawn.x,
    stationSpawn.y,
    stationSpawn.z,
    stationSpawn.w,
    true,
    false
)

Wait(0)

-- Este es EL PED definitivo después del resurrect.
ped = PlayerPedId()

printPedDiagnostics(
    "final_ped_recovered",
    ped
)

SetEntityCoordsNoOffset(
    ped,
    stationSpawn.x,
    stationSpawn.y,
    stationSpawn.z,
    false,
    false,
    false
)

SetEntityHeading(
    ped,
    stationSpawn.w
)

-- Inicializar AHORA los componentes del freemode,
-- sobre el PED definitivo.
if not preserveAppearance then
    SetPedDefaultComponentVariation(ped)
end

-- Normalizar completamente su estado visual/físico.
ResetEntityAlpha(ped)

SetEntityVisible(
    ped,
    true,
    false
)

SetEntityCollision(
    ped,
    true,
    true
)

SetEntityInvincible(
    ped,
    false
)

FreezeEntityPosition(
    ped,
    false
)

-- Por si el jugador quedó dentro de un fade de red.
NetworkFadeInEntity(
    ped,
    true
)

ClearFocus()

ClearPedTasksImmediately(ped)
ClearPedBloodDamage(ped)

SetEntityHealth(
    ped,
    GetEntityMaxHealth(ped)
)

printPedDiagnostics(
    "after_final_ped_setup",
    ped
)

Wait(500)

-- Una segunda normalización defensiva después
-- de que GTA tenga un frame para montar el freemode.
ped = PlayerPedId()

if not preserveAppearance then
    SetPedDefaultComponentVariation(ped)
end
ResetEntityAlpha(ped)
SetEntityVisible(ped, true, false)
SetEntityCollision(ped, true, true)
FreezeEntityPosition(ped, false)

printPedDiagnostics(
    "after_500ms",
    ped
)

DoScreenFadeIn(500)
end

function SpawnPlayerCharacter()
    local character = PlayerData
        and PlayerData.Character

    if type(character) ~= "table"
        or character.created ~= true
        or type(character.appearance) ~= "table" then

        return false
    end

    local appearance = character.appearance
    local hasAppearanceData =
        type(appearance.data) == "table"
    local fullAppearanceApplied = false

    if hasAppearanceData
        and AppearanceManager.IsAvailable() then

        fullAppearanceApplied =
            AppearanceManager.Apply(appearance) == true
    end

    if not fullAppearanceApplied then
        local fallbackApplied =
            AppearanceManager.ApplyFallback(
                appearance.bodyModel
            )

        if not fallbackApplied then
            return false
        end
    end

    local ped = PlayerPedId()

    if not ped
        or ped == 0
        or not DoesEntityExist(ped) then

        return false
    end

    if not hasAppearanceData
        and AppearanceManager.IsAvailable() then

        local captured = AppearanceManager.Capture()

        if type(captured) == "table"
            and captured.model == appearance.bodyModel then

            appearance.version = 1
            appearance.data = captured
            SaveProgress(false, "APPEARANCE_CAPTURED")
            fullAppearanceApplied = true
        end
    end

    PlayerData.OnDuty = false
    PlayerData.DispatchState = "OFF_DUTY"
    PlayerData.Unit = nil

    spawnAtStation(fullAppearanceApplied)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    print(
        "[Sentinel AI] Personaje cargado. Spawn inicial completado."
    )

    return true
end

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(500)
    end

    while not PlayerData.CharacterLoaded do
        Wait(100)
    end

    local character = PlayerData.Character

    if type(character) == "table"
        and character.created == true then

        SpawnPlayerCharacter()
    else
        local ped = PlayerPedId()

        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)

        TriggerEvent(
            "sentinel:characterCreationRequired"
        )
    end
end)

CreateThread(function()
    while true do
        Wait(500)

        local ped = PlayerPedId()

        if IsEntityDead(ped) then
            Wait(2000)
            spawnAtStation()
        end
    end
end)
