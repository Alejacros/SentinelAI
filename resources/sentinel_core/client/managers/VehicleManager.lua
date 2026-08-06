function SpawnPoliceVehicle()

    local ped = PlayerPedId()

    local coords = GetEntityCoords(ped)

    local heading = GetEntityHeading(ped)

    local model = GetHashKey(Config.PoliceVehicle)

    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(0)
    end

    local vehicle = CreateVehicle(
        model,
        coords.x + 3.0,
        coords.y,
        coords.z,
        heading,
        true,
        false
    )

    SetVehicleOnGroundProperly(vehicle)

    SetVehicleHasBeenOwnedByPlayer(vehicle, true)

    SetVehicleEngineOn(vehicle, true, true, false)

    PlayerData.Vehicle = vehicle

end