print("[Sentinel AI] Cargando EvidenceManager...")

EvidenceManager = {
    Active = nil,
    Locked = false
}

local evidenceTypes = {
    {
        name = "Billetera",
        model = "prop_ld_wallet_pickup"
    },
    {
        name = "Paquete sospechoso",
        model = "prop_cs_package_01"
    },
    {
        name = "Teléfono celular",
        model = "prop_npc_phone_02"
    }
}

local function notify(message, color)
    Sentinel.Notify(
        "EVIDENCIA",
        message,
        color or {0, 220, 255}
    )
end

local function loadModel(model)
    if not IsModelInCdimage(model)
        or not IsModelValid(model) then

        print(
            "[Sentinel AI] Modelo de evidencia inválido: "
                .. tostring(model)
        )

        return false
    end

    RequestModel(model)

    local timeout = GetGameTimer() + 5000

    while not HasModelLoaded(model) do
        Wait(50)

        if GetGameTimer() >= timeout then
            return false
        end
    end

    return true
end

local function horizontalDistance(first, second)
    local deltaX = first.x - second.x
    local deltaY = first.y - second.y

    return math.sqrt(
        deltaX * deltaX
        + deltaY * deltaY
    )
end

local function findSpawnPosition()
    local playerPed = PlayerPedId()

    local position =
        GetOffsetFromEntityInWorldCoords(
            playerPed,
            0.0,
            2.0,
            0.0
        )

    RequestCollisionAtCoord(
        position.x,
        position.y,
        position.z
    )

    for height = 5.0, 60.0, 5.0 do
        local foundGround, groundZ =
            GetGroundZFor_3dCoord(
                position.x,
                position.y,
                position.z + height,
                false
            )

        if foundGround then
            return vector3(
                position.x,
                position.y,
                groundZ + 0.08
            )
        end
    end

    local playerCoords =
        GetEntityCoords(playerPed)

    return vector3(
        position.x,
        position.y,
        playerCoords.z
    )
end

function EvidenceManager.Remove()
    local evidence =
        EvidenceManager.Active

    if evidence then
        if evidence.blip
            and DoesBlipExist(evidence.blip) then

            RemoveBlip(evidence.blip)
        end

        if evidence.object
            and DoesEntityExist(evidence.object) then

            SetEntityAsMissionEntity(
                evidence.object,
                true,
                true
            )

            DeleteEntity(evidence.object)
        end
    end

    EvidenceManager.Active = nil
    EvidenceManager.Locked = false
end

function EvidenceManager.Spawn()
    EvidenceManager.Remove()

    local evidenceData =
        evidenceTypes[
            math.random(#evidenceTypes)
        ]

    local model =
        GetHashKey(evidenceData.model)

    if not loadModel(model) then
        notify(
            "No fue posible cargar la evidencia.",
            {255, 80, 80}
        )

        return false
    end

    local position =
        findSpawnPosition()

    local object = CreateObject(
        model,
        position.x,
        position.y,
        position.z,
        false,
        false,
        false
    )

    SetModelAsNoLongerNeeded(model)

    if object == 0
        or not DoesEntityExist(object) then

        notify(
            "No fue posible crear la evidencia.",
            {255, 80, 80}
        )

        return false
    end

    SetEntityAsMissionEntity(
        object,
        true,
        true
    )

    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)

    local finalCoords =
        GetEntityCoords(object)

    local blip = AddBlipForCoord(
        finalCoords.x,
        finalCoords.y,
        finalCoords.z
    )

    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Evidencia")
    EndTextCommandSetBlipName(blip)

    EvidenceManager.Active = {
        object = object,
        blip = blip,
        name = evidenceData.name
    }

    EvidenceManager.Locked = false

    notify(
        "Evidencia localizada. Acérquese al marcador azul."
    )

    print(
        (
            "[Sentinel AI] Evidencia creada: %s | %.2f %.2f %.2f"
        ):format(
            evidenceData.name,
            finalCoords.x,
            finalCoords.y,
            finalCoords.z
        )
    )

    return true
end

-- Compatibilidad con InteractionManager.
function SpawnEvidence()
    return EvidenceManager.Spawn()
end

function RemoveActiveEvidence()
    EvidenceManager.Remove()
end

local function completeCaseWithoutCustody()
    local earnedXP = 25

    PlayerData.DispatchState = "REPORT"

    EvidenceManager.Remove()

    if type(CleanupCrimeScene) == "function" then
        CleanupCrimeScene()
    end

    if type(CompleteCase) == "function" then
        local completed =
            CompleteCase(earnedXP)

        if completed
            and type(AwardXP) == "function" then

            AwardXP(earnedXP)
        end
    end

    if type(CompleteCurrentDispatch) == "function" then
        CompleteCurrentDispatch()
    end
end

local function continueAfterCollection()
    if type(IsSuspectArrested) == "function"
        and IsSuspectArrested()
        and type(StartCustodyTransport) == "function" then

        local started =
            StartCustodyTransport()

        if started then
            Sentinel.Notify(
                "CENTRAL",
                "Evidencia asegurada. Traslade al detenido.",
                {90, 190, 255}
            )

            return
        end
    end

    completeCaseWithoutCustody()
end

local function collectEvidence()
    if EvidenceManager.Locked then
        return
    end

    local evidence =
        EvidenceManager.Active

    if not evidence
        or not evidence.object
        or not DoesEntityExist(evidence.object) then

        return
    end

    EvidenceManager.Locked = true

    local evidenceName =
        evidence.name or "Evidencia"

    if type(AddEvidenceToCurrentCase) ~= "function"
        or not AddEvidenceToCurrentCase(evidenceName) then

        notify(
            "No existe un expediente activo.",
            {255, 80, 80}
        )

        EvidenceManager.Locked = false
        return
    end

    if BodyCamManager
        and type(BodyCamManager.Log) == "function" then

        BodyCamManager.Log(
            "Evidencia asegurada: "
                .. evidenceName .. ".",
            "INVESTIGATION"
        )
    end

    notify(
        evidenceName
            .. " recogido correctamente.",
        {80, 220, 140}
    )

    print(
        "[Sentinel AI] Evidencia recogida: "
            .. evidenceName
    )

    EvidenceManager.Remove()
    continueAfterCollection()
end

CreateThread(function()
    while true do
        local sleep = 500

        local evidence =
            EvidenceManager.Active

        if evidence
            and evidence.object
            and DoesEntityExist(evidence.object) then

            local objectCoords =
                GetEntityCoords(evidence.object)

            local playerCoords =
                GetEntityCoords(PlayerPedId())

            local distance =
                horizontalDistance(
                    playerCoords,
                    objectCoords
                )

            if distance <= 100.0 then
                sleep = 0

                DrawMarker(
                    2,
                    objectCoords.x,
                    objectCoords.y,
                    objectCoords.z + 0.75,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    180.0,
                    0.0,
                    0.50,
                    0.50,
                    0.50,
                    0,
                    220,
                    255,
                    255,
                    false,
                    true,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )

                -- Usamos distancia horizontal para que el objeto
                -- hundido o elevado unos centímetros no bloquee la E.
                if distance <= 3.0 then
                    BeginTextCommandDisplayHelp(
                        "STRING"
                    )

                    AddTextComponentSubstringPlayerName(
                        "Pulsa ~INPUT_CONTEXT~ para recoger la evidencia."
                    )

                    EndTextCommandDisplayHelp(
                        0,
                        false,
                        true,
                        -1
                    )

                    if IsControlJustPressed(0, 38) then
                        collectEvidence()
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

RegisterCommand(
    "collectevidence",
    function()
        local evidence =
            EvidenceManager.Active

        if not evidence
            or not evidence.object
            or not DoesEntityExist(evidence.object) then

            notify(
                "No existe evidencia activa.",
                {255, 180, 0}
            )

            return
        end

        local playerCoords =
            GetEntityCoords(PlayerPedId())

        local objectCoords =
            GetEntityCoords(evidence.object)

        local distance =
            horizontalDistance(
                playerCoords,
                objectCoords
            )

        if distance > 5.0 then
            notify(
                "Debe acercarse más a la evidencia.",
                {255, 180, 0}
            )

            return
        end

        collectEvidence()
    end,
    false
)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        EvidenceManager.Remove()
    end
)

print(
    "[Sentinel AI] EvidenceManager listo. "
        .. "SpawnEvidence = "
        .. type(SpawnEvidence)
)
