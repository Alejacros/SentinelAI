SceneBuilder = {
    Layout = nil,
    PreparedDispatch = nil
}

local function notifyError(message)
    Sentinel.Notify(
        "ERROR",
        message,
        {255, 80, 80}
    )
end

function SceneBuilder.Reset()
    SceneBuilder.Layout = nil
    SceneBuilder.PreparedDispatch = nil
end

function SceneBuilder.Build(dispatch)
    if not dispatch or not dispatch.location then
        notifyError(
            "El despacho no contiene un centro de incidente válido."
        )

        return nil
    end

    local center = dispatch.location
    local occupied = {}

    SpawnPointManager.PreloadArea(
        center,
        1200
    )

    local witnessPosition =
        SpawnPointManager.FindSafePedPosition(
            center,
            3.0,
            9.0,
            occupied
        )

    occupied[#occupied + 1] =
        witnessPosition

    local evidencePosition =
        SpawnPointManager.FindSafeEvidencePosition(
            center,
            occupied
        )

    occupied[#occupied + 1] =
        evidencePosition

    local suspectPosition =
        SpawnPointManager.FindSafePedPosition(
            center,
            7.0,
            16.0,
            occupied
        )

    occupied[#occupied + 1] =
        suspectPosition

    local secondaryPedPosition =
        SpawnPointManager.FindSafePedPosition(
            center,
            4.0,
            12.0,
            occupied
        )

    occupied[#occupied + 1] =
        secondaryPedPosition

    local vehiclePosition, vehicleHeading =
        SpawnPointManager.FindSafeVehiclePosition(
            center
        )

    SceneBuilder.Layout = {
        center = center,

        witness = {
            position = witnessPosition,
            heading = math.random(0, 359) + 0.0
        },

        evidence = {
            position = evidencePosition
        },

        suspect = {
            position = suspectPosition,
            heading = math.random(0, 359) + 0.0
        },

        secondaryPed = {
            position = secondaryPedPosition,
            heading = math.random(0, 359) + 0.0
        },

        vehicle = {
            position = vehiclePosition,
            heading = vehicleHeading or 0.0
        },

        preparedAt = GetGameTimer()
    }

    SceneBuilder.PreparedDispatch = dispatch

    print(
        (
            "[Sentinel AI] Escena preparada | "
            .. "Testigo %.2f %.2f %.2f | "
            .. "Evidencia %.2f %.2f %.2f"
        ):format(
            witnessPosition.x,
            witnessPosition.y,
            witnessPosition.z,
            evidencePosition.x,
            evidencePosition.y,
            evidencePosition.z
        )
    )

    return SceneBuilder.Layout
end

function SceneBuilder.GetLayout()
    return SceneBuilder.Layout
end

function SceneBuilder.GetWitnessPosition()
    local layout = SceneBuilder.GetLayout()

    return layout
        and layout.witness
        and layout.witness.position
        or nil
end

function SceneBuilder.GetEvidencePosition()
    local layout = SceneBuilder.GetLayout()

    return layout
        and layout.evidence
        and layout.evidence.position
        or nil
end

function SceneBuilder.GetSuspectPosition()
    local layout = SceneBuilder.GetLayout()

    return layout
        and layout.suspect
        and layout.suspect.position
        or nil
end

function SceneBuilder.GetVehiclePosition()
    local layout = SceneBuilder.GetLayout()

    if not layout or not layout.vehicle then
        return nil, 0.0
    end

    return layout.vehicle.position,
        layout.vehicle.heading
end