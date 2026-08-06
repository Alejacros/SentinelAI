EntityManager = {
    Entities = {},
    Blips = {}
}

local function loadModel(model, timeoutMs)
    timeoutMs = timeoutMs or 7000

    if not IsModelInCdimage(model)
        or not IsModelValid(model) then

        print(
            ("[Sentinel AI] Modelo inválido: %s")
                :format(tostring(model))
        )

        return false
    end

    RequestModel(model)

    local timeout = GetGameTimer() + timeoutMs

    while not HasModelLoaded(model) do
        Wait(50)

        if GetGameTimer() >= timeout then
            print(
                ("[Sentinel AI] Timeout cargando modelo: %s")
                    :format(tostring(model))
            )

            return false
        end
    end

    return true
end

local function registerEntity(entity, group)
    if not entity
        or entity == 0
        or not DoesEntityExist(entity) then

        return nil
    end

    EntityManager.Entities[#EntityManager.Entities + 1] = {
        entity = entity,
        group = group or "default"
    }

    return entity
end

local function registerBlip(blip, group)
    if not blip or not DoesBlipExist(blip) then
        return nil
    end

    EntityManager.Blips[#EntityManager.Blips + 1] = {
        blip = blip,
        group = group or "default"
    }

    return blip
end

function EntityManager.SpawnPed(options)
    options = options or {}

    local model = GetHashKey(
        options.model or "a_m_m_business_01"
    )

    if not loadModel(model) then
        return nil
    end

    local coords = options.coords

    if not coords then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    RequestCollisionAtCoord(
        coords.x,
        coords.y,
        coords.z
    )

    local ped = CreatePed(
        options.pedType or 4,
        model,
        coords.x,
        coords.y,
        coords.z,
        options.heading or 0.0,
        options.networked == true,
        false
    )

    if ped == 0 or not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    SetEntityAsMissionEntity(ped, true, true)

    if options.invincible then
        SetEntityInvincible(ped, true)
        SetEntityCanBeDamaged(ped, false)
    end

    if options.blockEvents ~= false then
        SetBlockingOfNonTemporaryEvents(ped, true)
    end

    if options.freeze then
        FreezeEntityPosition(ped, true)
    end

    if options.canRagdoll == false then
        SetPedCanRagdoll(ped, false)
    end

    SetModelAsNoLongerNeeded(model)

    return registerEntity(
        ped,
        options.group
    )
end

function EntityManager.SpawnVehicle(options)
    options = options or {}

    local model = GetHashKey(
        options.model or "blista"
    )

    if not loadModel(model) then
        return nil
    end

    local coords = options.coords

    if not coords then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    RequestCollisionAtCoord(
        coords.x,
        coords.y,
        coords.z
    )

    local vehicle = CreateVehicle(
        model,
        coords.x,
        coords.y,
        coords.z,
        options.heading or 0.0,
        options.networked == true,
        false
    )

    if vehicle == 0
        or not DoesEntityExist(vehicle) then

        SetModelAsNoLongerNeeded(model)
        return nil
    end

    SetEntityAsMissionEntity(
        vehicle,
        true,
        true
    )

    SetVehicleOnGroundProperly(vehicle)

    if options.engineOn ~= nil then
        SetVehicleEngineOn(
            vehicle,
            options.engineOn,
            true,
            false
        )
    end

    if options.invincible then
        SetEntityInvincible(vehicle, true)
    end

    if options.freeze then
        FreezeEntityPosition(vehicle, true)
    end

    SetModelAsNoLongerNeeded(model)

    return registerEntity(
        vehicle,
        options.group
    )
end

function EntityManager.SpawnObject(options)
    options = options or {}

    local model = GetHashKey(
        options.model or "prop_cs_package_01"
    )

    if not loadModel(model) then
        return nil
    end

    local coords = options.coords

    if not coords then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    local object = CreateObject(
        model,
        coords.x,
        coords.y,
        coords.z,
        options.networked == true,
        false,
        false
    )

    if object == 0
        or not DoesEntityExist(object) then

        SetModelAsNoLongerNeeded(model)
        return nil
    end

    SetEntityAsMissionEntity(
        object,
        true,
        true
    )

    if options.placeOnGround ~= false then
        PlaceObjectOnGroundProperly(object)
    end

    if options.freeze then
        FreezeEntityPosition(object, true)
    end

    SetModelAsNoLongerNeeded(model)

    return registerEntity(
        object,
        options.group
    )
end

function EntityManager.CreateEntityBlip(
    entity,
    options
)
    options = options or {}

    if not entity
        or not DoesEntityExist(entity) then

        return nil
    end

    local blip = AddBlipForEntity(entity)

    SetBlipSprite(
        blip,
        options.sprite or 1
    )

    SetBlipColour(
        blip,
        options.colour or 1
    )

    SetBlipScale(
        blip,
        options.scale or 0.9
    )

    SetBlipAsShortRange(
        blip,
        options.shortRange == true
    )

    BeginTextCommandSetBlipName("STRING")

    AddTextComponentString(
        options.name or "Sentinel"
    )

    EndTextCommandSetBlipName(blip)

    return registerBlip(
        blip,
        options.group
    )
end

function EntityManager.CreateCoordinateBlip(
    coords,
    options
)
    options = options or {}

    if not coords then
        return nil
    end

    local blip = AddBlipForCoord(
        coords.x,
        coords.y,
        coords.z
    )

    SetBlipSprite(
        blip,
        options.sprite or 1
    )

    SetBlipColour(
        blip,
        options.colour or 1
    )

    SetBlipScale(
        blip,
        options.scale or 0.9
    )

    SetBlipAsShortRange(
        blip,
        options.shortRange == true
    )

    if options.route then
        SetBlipRoute(blip, true)

        SetBlipRouteColour(
            blip,
            options.routeColour
                or options.colour
                or 1
        )
    end

    BeginTextCommandSetBlipName("STRING")

    AddTextComponentString(
        options.name or "Sentinel"
    )

    EndTextCommandSetBlipName(blip)

    return registerBlip(
        blip,
        options.group
    )
end

function EntityManager.RemoveEntity(entity)
    if not entity or not DoesEntityExist(entity) then
        return false
    end

    SetEntityAsMissionEntity(
        entity,
        true,
        true
    )

    DeleteEntity(entity)

    return not DoesEntityExist(entity)
end

function EntityManager.ReleaseEntity(entity)
    if not entity or not DoesEntityExist(entity) then
        return false
    end

    if IsEntityAPed(entity) then
        FreezeEntityPosition(entity, false)
        SetEntityInvincible(entity, false)
        SetEntityCanBeDamaged(entity, true)
        SetBlockingOfNonTemporaryEvents(entity, false)
        SetPedCanRagdoll(entity, true)

    elseif IsEntityAVehicle(entity) then
        SetVehicleSiren(entity, false)
        FreezeEntityPosition(entity, false)
        SetEntityInvincible(entity, false)
    end

    SetEntityAsNoLongerNeeded(entity)

    return true
end

function EntityManager.CleanupGroup(
    group,
    deleteEntities
)
    for index = #EntityManager.Blips, 1, -1 do
        local entry = EntityManager.Blips[index]

        if entry.group == group then
            if DoesBlipExist(entry.blip) then
                RemoveBlip(entry.blip)
            end

            table.remove(
                EntityManager.Blips,
                index
            )
        end
    end

    for index = #EntityManager.Entities, 1, -1 do
        local entry = EntityManager.Entities[index]

        if entry.group == group then
            if DoesEntityExist(entry.entity) then
                if deleteEntities then
                    EntityManager.RemoveEntity(
                        entry.entity
                    )
                else
                    EntityManager.ReleaseEntity(
                        entry.entity
                    )
                end
            end

            table.remove(
                EntityManager.Entities,
                index
            )
        end
    end
end

function EntityManager.CleanupAll(deleteEntities)
    local groups = {}

    for _, entry in ipairs(
        EntityManager.Entities
    ) do
        groups[entry.group] = true
    end

    for _, entry in ipairs(
        EntityManager.Blips
    ) do
        groups[entry.group] = true
    end

    for group in pairs(groups) do
        EntityManager.CleanupGroup(
            group,
            deleteEntities
        )
    end
end

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        EntityManager.CleanupAll(true)
    end
)