AppearanceManager = {
    EditorOpen = false,
    PendingCallback = nil,
    InCustomizationArea = false,
    ReturnPosition = nil
}

local RESOURCE_NAME = "fivem-appearance"
local CUSTOMIZATION_POSITION =
    vector4(402.92, -996.77, -99.00, 180.0)

local allowedBodyModels = {
    mp_f_freemode_01 = true,
    mp_m_freemode_01 = true
}

local function isValidBodyModel(bodyModel)
    return type(bodyModel) == "string"
        and allowedBodyModels[bodyModel] == true
end

local function isValidAppearanceData(data, bodyModel)
    return type(data) == "table"
        and data.model == bodyModel
end

function AppearanceManager.IsAvailable()
    return GetResourceState(RESOURCE_NAME) == "started"
end

function AppearanceManager.EnterCustomizationArea()
    if AppearanceManager.InCustomizationArea then
        return true
    end

    local ped = PlayerPedId()

    if not ped
        or ped == 0
        or not DoesEntityExist(ped) then

        return false, "ped_unavailable"
    end

    local currentPosition = GetEntityCoords(ped)

    AppearanceManager.ReturnPosition = {
        x = currentPosition.x,
        y = currentPosition.y,
        z = currentPosition.z,
        w = GetEntityHeading(ped)
    }

    RequestCollisionAtCoord(
        CUSTOMIZATION_POSITION.x,
        CUSTOMIZATION_POSITION.y,
        CUSTOMIZATION_POSITION.z
    )

    SetFocusPosAndVel(
        CUSTOMIZATION_POSITION.x,
        CUSTOMIZATION_POSITION.y,
        CUSTOMIZATION_POSITION.z,
        0.0,
        0.0,
        0.0
    )

    SetEntityCoordsNoOffset(
        ped,
        CUSTOMIZATION_POSITION.x,
        CUSTOMIZATION_POSITION.y,
        CUSTOMIZATION_POSITION.z,
        false,
        false,
        false
    )

    SetEntityHeading(
        ped,
        CUSTOMIZATION_POSITION.w
    )
    FreezeEntityPosition(ped, true)
    ResetEntityAlpha(ped)
    SetEntityVisible(ped, true, false)

    local timeoutAt = GetGameTimer() + 10000

    while not HasCollisionLoadedAroundEntity(ped)
        and GetGameTimer() < timeoutAt do

        RequestCollisionAtCoord(
            CUSTOMIZATION_POSITION.x,
            CUSTOMIZATION_POSITION.y,
            CUSTOMIZATION_POSITION.z
        )

        Wait(100)
    end

    ClearFocus()

    if not HasCollisionLoadedAroundEntity(ped) then
        AppearanceManager.ExitCustomizationArea(true)
        return false, "collision_timeout"
    end

    AppearanceManager.InCustomizationArea = true

    return true
end

function AppearanceManager.ExitCustomizationArea(
    restorePosition
)
    local ped = PlayerPedId()
    local returnPosition =
        AppearanceManager.ReturnPosition

    ClearFocus()

    if ped
        and ped ~= 0
        and DoesEntityExist(ped) then

        FreezeEntityPosition(ped, true)
        ResetEntityAlpha(ped)
        SetEntityVisible(ped, true, false)

        if restorePosition == true
            and type(returnPosition) == "table" then

            RequestCollisionAtCoord(
                returnPosition.x,
                returnPosition.y,
                returnPosition.z
            )

            SetFocusPosAndVel(
                returnPosition.x,
                returnPosition.y,
                returnPosition.z,
                0.0,
                0.0,
                0.0
            )

            SetEntityCoordsNoOffset(
                ped,
                returnPosition.x,
                returnPosition.y,
                returnPosition.z,
                false,
                false,
                false
            )

            SetEntityHeading(ped, returnPosition.w)

            local timeoutAt = GetGameTimer() + 10000

            while not HasCollisionLoadedAroundEntity(ped)
                and GetGameTimer() < timeoutAt do

                RequestCollisionAtCoord(
                    returnPosition.x,
                    returnPosition.y,
                    returnPosition.z
                )

                Wait(100)
            end

            ClearFocus()
        end
    end

    AppearanceManager.InCustomizationArea = false
    AppearanceManager.ReturnPosition = nil

    return true
end

function AppearanceManager.ApplyFallback(bodyModel)
    if not isValidBodyModel(bodyModel) then
        return false, "invalid_body_model"
    end

    local model = GetHashKey(bodyModel)

    if not IsModelInCdimage(model)
        or not IsModelValid(model) then

        return false, "invalid_model"
    end

    if GetEntityModel(PlayerPedId()) ~= model then
        RequestModel(model)

        local timeoutAt = GetGameTimer() + 10000

        while not HasModelLoaded(model)
            and GetGameTimer() < timeoutAt do

            Wait(100)
        end

        if not HasModelLoaded(model) then
            return false, "model_timeout"
        end

        SetPlayerModel(PlayerId(), model)
        SetModelAsNoLongerNeeded(model)
        Wait(0)
    end

    local ped = PlayerPedId()

    if not ped
        or ped == 0
        or not DoesEntityExist(ped) then

        return false, "ped_unavailable"
    end

    SetPedDefaultComponentVariation(ped)
    ResetEntityAlpha(ped)
    SetEntityVisible(ped, true, false)

    return true
end

function AppearanceManager.OpenCreator(options, callback)
    options = type(options) == "table"
        and options
        or {}

    callback = type(callback) == "function"
        and callback
        or function() end

    if AppearanceManager.EditorOpen then
        callback(false, nil, "editor_already_open")
        return false
    end

    if not AppearanceManager.IsAvailable() then
        callback(false, nil, "provider_unavailable")
        return false
    end

    local bodyModel = tostring(options.bodyModel or "")

    if not isValidBodyModel(bodyModel) then
        callback(false, nil, "invalid_body_model")
        return false
    end

    local applied, applyError =
        AppearanceManager.ApplyFallback(bodyModel)

    if not applied then
        callback(false, nil, applyError)
        return false
    end

    local entered, enterError =
        AppearanceManager.EnterCustomizationArea()

    if not entered then
        callback(false, nil, enterError)
        return false
    end

    local mode = tostring(options.mode or "character")
    local editIdentityAppearance = mode == "character"

    local config = {
        ped = false,
        headBlend = editIdentityAppearance,
        faceFeatures = editIdentityAppearance,
        headOverlays = editIdentityAppearance,
        components = options.clothing == true,
        props = options.props == true,
        tattoos = false,
        allowExit = options.allowExit == true,
        automaticFade = true
    }

    AppearanceManager.EditorOpen = true
    AppearanceManager.PendingCallback = callback

    local exportOk, exportError = pcall(function()
        exports[RESOURCE_NAME]:startPlayerCustomization(
            function(appearance)
                AppearanceManager.EditorOpen = false
                AppearanceManager.PendingCallback = nil

                if appearance == nil then
                    AppearanceManager.ExitCustomizationArea(
                        true
                    )
                    callback(false, nil, "cancelled")
                    return
                end

                if not isValidAppearanceData(
                    appearance,
                    bodyModel
                ) then
                    AppearanceManager.ExitCustomizationArea(
                        true
                    )
                    callback(false, nil, "model_mismatch")
                    return
                end

                AppearanceManager.ExitCustomizationArea(false)
                callback(true, appearance, nil)
            end,
            config
        )
    end)

    if not exportOk then
        AppearanceManager.EditorOpen = false
        AppearanceManager.PendingCallback = nil
        AppearanceManager.ExitCustomizationArea(true)
        callback(false, nil, "open_failed")

        print(
            "[Sentinel AI] ERROR abriendo fivem-appearance: "
                .. tostring(exportError)
        )

        return false
    end

    return true
end

function AppearanceManager.Capture()
    if not AppearanceManager.IsAvailable() then
        return nil, "provider_unavailable"
    end

    local success, appearance = pcall(function()
        return exports[RESOURCE_NAME]:getPedAppearance(
            PlayerPedId()
        )
    end)

    if not success or type(appearance) ~= "table" then
        return nil, "capture_failed"
    end

    return appearance
end

function AppearanceManager.Apply(appearance)
    if type(appearance) ~= "table"
        or tonumber(appearance.version) ~= 1 then

        return false, "invalid_appearance"
    end

    local bodyModel = tostring(
        appearance.bodyModel or ""
    )

    if not isValidBodyModel(bodyModel) then
        return false, "invalid_body_model"
    end

    if not isValidAppearanceData(
        appearance.data,
        bodyModel
    ) then
        return false, "model_mismatch"
    end

    if not AppearanceManager.IsAvailable() then
        return false, "provider_unavailable"
    end

    local success, exportError = pcall(function()
        exports[RESOURCE_NAME]:setPlayerAppearance(
            appearance.data
        )
    end)

    if not success then
        print(
            "[Sentinel AI] ERROR aplicando fivem-appearance: "
                .. tostring(exportError)
        )

        return false, "apply_failed"
    end

    -- El export aplica el modelo de forma asíncrona internamente.
    Wait(100)

    local expectedModel = GetHashKey(bodyModel)
    local timeoutAt = GetGameTimer() + 10000
    local ped = PlayerPedId()

    while (not DoesEntityExist(ped)
        or GetEntityModel(ped) ~= expectedModel)
        and GetGameTimer() < timeoutAt do

        Wait(100)
        ped = PlayerPedId()
    end

    ped = PlayerPedId()

    if not ped
        or ped == 0
        or not DoesEntityExist(ped) then

        return false, "ped_unavailable"
    end

    if GetEntityModel(ped) ~= expectedModel then
        return false, "model_timeout"
    end

    return true
end

local outfitComponentIds = {
    1,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11
}

local outfitPropIds = {
    0,
    1,
    2,
    6,
    7
}

local allowedOutfitComponentIds = {}
local allowedOutfitPropIds = {}

for _, componentId in ipairs(outfitComponentIds) do
    allowedOutfitComponentIds[componentId] = true
end

for _, propId in ipairs(outfitPropIds) do
    allowedOutfitPropIds[propId] = true
end

local function validateOutfit(outfit, ped)
    if type(outfit) ~= "table"
        or type(outfit.components) ~= "table"
        or type(outfit.props) ~= "table" then

        return nil, "invalid_outfit"
    end

    local cleanOutfit = {
        components = {},
        props = {}
    }

    for index, component in ipairs(outfit.components) do
        if index > #outfitComponentIds
            or type(component) ~= "table" then

            return nil, "invalid_components"
        end

        local componentId = tonumber(component.component_id)
        local drawable = tonumber(component.drawable)
        local texture = tonumber(component.texture)

        if not componentId
            or componentId % 1 ~= 0
            or not allowedOutfitComponentIds[componentId]
            or not drawable
            or drawable % 1 ~= 0
            or drawable < 0
            or drawable >= GetNumberOfPedDrawableVariations(
                ped,
                componentId
            )
            or not texture
            or texture % 1 ~= 0
            or texture < 0
            or texture >= GetNumberOfPedTextureVariations(
                ped,
                componentId,
                drawable
            ) then

            return nil, "invalid_component"
        end

        cleanOutfit.components[#cleanOutfit.components + 1] = {
            component_id = componentId,
            drawable = drawable,
            texture = texture
        }
    end

    for index, prop in ipairs(outfit.props) do
        if index > #outfitPropIds
            or type(prop) ~= "table" then

            return nil, "invalid_props"
        end

        local propId = tonumber(prop.prop_id)
        local drawable = tonumber(prop.drawable)
        local texture = tonumber(prop.texture)

        if not propId
            or propId % 1 ~= 0
            or not allowedOutfitPropIds[propId]
            or not drawable
            or drawable % 1 ~= 0
            or drawable < -1
            or not texture
            or texture % 1 ~= 0
            or (drawable >= 0 and texture < 0) then

            return nil, "invalid_prop"
        end

        if drawable >= 0 then
            if drawable >= GetNumberOfPedPropDrawableVariations(
                ped,
                propId
            )
                or texture >= GetNumberOfPedPropTextureVariations(
                    ped,
                    propId,
                    drawable
                ) then

                return nil, "invalid_prop"
            end
        end

        cleanOutfit.props[#cleanOutfit.props + 1] = {
            prop_id = propId,
            drawable = drawable,
            texture = drawable == -1 and 0 or texture
        }
    end

    return cleanOutfit
end

local function applyOutfitWithNatives(ped, outfit)
    for _, component in ipairs(outfit.components) do
        SetPedComponentVariation(
            ped,
            component.component_id,
            component.drawable,
            component.texture,
            0
        )
    end

    for _, prop in ipairs(outfit.props) do
        if prop.drawable == -1 then
            ClearPedProp(ped, prop.prop_id)
        else
            SetPedPropIndex(
                ped,
                prop.prop_id,
                prop.drawable,
                prop.texture,
                false
            )
        end
    end
end

local function outfitMatches(ped, outfit)
    for _, component in ipairs(outfit.components) do
        if GetPedDrawableVariation(
            ped,
            component.component_id
        ) ~= component.drawable
            or GetPedTextureVariation(
                ped,
                component.component_id
            ) ~= component.texture then

            return false
        end
    end

    for _, prop in ipairs(outfit.props) do
        if GetPedPropIndex(ped, prop.prop_id)
            ~= prop.drawable then

            return false
        end

        if prop.drawable >= 0
            and GetPedPropTextureIndex(
                ped,
                prop.prop_id
            ) ~= prop.texture then

            return false
        end
    end

    return true
end

function AppearanceManager.CaptureOutfit()
    local ped = PlayerPedId()

    if not ped
        or ped == 0
        or not DoesEntityExist(ped) then

        return nil, "ped_unavailable"
    end

    if AppearanceManager.IsAvailable() then
        local success, components, props = pcall(function()
            return exports[RESOURCE_NAME]:getPedComponents(ped),
                exports[RESOURCE_NAME]:getPedProps(ped)
        end)

        if success
            and type(components) == "table"
            and type(props) == "table" then

            local outfit = {
                components = {},
                props = {}
            }

            for _, component in ipairs(components) do
                if type(component) == "table"
                    and allowedOutfitComponentIds[
                        tonumber(component.component_id)
                    ] then

                    outfit.components[#outfit.components + 1] =
                        component
                end
            end

            for _, prop in ipairs(props) do
                if type(prop) == "table"
                    and allowedOutfitPropIds[
                        tonumber(prop.prop_id)
                    ] then

                    outfit.props[#outfit.props + 1] = prop
                end
            end

            local cleanOutfit = validateOutfit(
                outfit,
                ped
            )

            if cleanOutfit then
                return cleanOutfit
            end
        end
    end

    local outfit = {
        components = {},
        props = {}
    }

    for _, componentId in ipairs(outfitComponentIds) do
        outfit.components[#outfit.components + 1] = {
            component_id = componentId,
            drawable = GetPedDrawableVariation(
                ped,
                componentId
            ),
            texture = GetPedTextureVariation(
                ped,
                componentId
            )
        }
    end

    for _, propId in ipairs(outfitPropIds) do
        local drawable = GetPedPropIndex(ped, propId)

        outfit.props[#outfit.props + 1] = {
            prop_id = propId,
            drawable = drawable,
            texture = drawable == -1
                and 0
                or GetPedPropTextureIndex(ped, propId)
        }
    end

    return outfit
end

function AppearanceManager.ApplyOutfit(outfit)
    local ped = PlayerPedId()

    if not ped
        or ped == 0
        or not DoesEntityExist(ped) then

        return false, "ped_unavailable"
    end

    local cleanOutfit, validationError =
        validateOutfit(outfit, ped)

    if not cleanOutfit then
        return false, validationError
    end

    local appliedWithProvider = false

    if AppearanceManager.IsAvailable() then
        appliedWithProvider = pcall(function()
            exports[RESOURCE_NAME]:setPedComponents(
                ped,
                cleanOutfit.components
            )
            exports[RESOURCE_NAME]:setPedProps(
                ped,
                cleanOutfit.props
            )
        end)
    end

    if not appliedWithProvider
        or not outfitMatches(ped, cleanOutfit) then

        applyOutfitWithNatives(ped, cleanOutfit)
    end

    Wait(0)

    if not outfitMatches(ped, cleanOutfit) then
        return false, "outfit_apply_failed"
    end

    return true
end

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName == RESOURCE_NAME then
            AppearanceManager.EditorOpen = false

            local callback =
                AppearanceManager.PendingCallback

            AppearanceManager.PendingCallback = nil
            AppearanceManager.ExitCustomizationArea(true)

            if callback then
                callback(
                    false,
                    nil,
                    "provider_unavailable"
                )
            end
        end
    end
)
