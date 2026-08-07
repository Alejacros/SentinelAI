CharacterManager = {
    CreatorOpen = false,
    SavePending = false,
    PendingCharacter = nil
}

local allowedGenderIdentities = {
    woman = true,
    man = true,
    non_binary = true
}

local allowedPronouns = {
    she = true,
    he = true,
    elle = true,
    custom = true
}

local allowedBodyModels = {
    mp_f_freemode_01 = true,
    mp_m_freemode_01 = true
}

local function trim(value)
    return tostring(value or "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

local function applyPreviewModel(modelName)
    if not allowedBodyModels[modelName] then
        return false
    end

    local model = GetHashKey(modelName)

    if not IsModelInCdimage(model)
        or not IsModelValid(model) then

        return false
    end

    RequestModel(model)

    local timeoutAt = GetGameTimer() + 10000

    while not HasModelLoaded(model)
        and GetGameTimer() < timeoutAt do

        Wait(100)
    end

    if not HasModelLoaded(model) then
        return false
    end

    if CharacterManager.SavePending == true
        or CharacterManager.CreatorOpen ~= true then

        SetModelAsNoLongerNeeded(model)
        return false
    end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()

    SetPedDefaultComponentVariation(ped)

    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)

    return true
end

local function validateCharacterInput(data)
    data = type(data) == "table" and data or {}

    local firstName = trim(data.firstName)
    local lastName = trim(data.lastName)
    local genderIdentity =
        tostring(data.genderIdentity or "")
    local pronounType =
        tostring(data.pronounType or "")
    local customPronouns =
        trim(data.customPronouns)
    local bodyModel =
        tostring(data.bodyModel or "")

    if firstName == "" or #firstName > 32 then
        return nil, "Escribe un nombre válido."
    end

    if lastName == "" or #lastName > 32 then
        return nil, "Escribe un apellido válido."
    end

    if not allowedGenderIdentities[genderIdentity] then
        return nil, "Selecciona una identidad de género."
    end

    if not allowedPronouns[pronounType] then
        return nil, "Selecciona tus pronombres."
    end

    if pronounType == "custom"
        and (customPronouns == ""
            or #customPronouns > 48) then

        return nil, "Escribe pronombres personalizados válidos."
    end

    if not allowedBodyModels[bodyModel] then
        return nil, "Selecciona una base corporal."
    end

    return {
        created = true,
        version = 1,

        identity = {
            firstName = firstName,
            lastName = lastName,
            genderIdentity = genderIdentity,

            pronouns = {
                type = pronounType,
                custom = pronounType == "custom"
                    and customPronouns
                    or nil
            }
        },

        appearance = {
            bodyModel = bodyModel
        },

        firstSpawn = true,
        academyCompleted = false,
        createdAt = 0,
        updatedAt = 0
    }
end

function CharacterManager.IsCreated(character)
    character = character
        or PlayerData.Character

    return type(character) == "table"
        and character.created == true
        and type(character.appearance) == "table"
        and allowedBodyModels[
            character.appearance.bodyModel
        ] == true
end

function CharacterManager.OpenCreator()
    if CharacterManager.CreatorOpen then
        return false
    end

    CharacterManager.CreatorOpen = true

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    local ped = PlayerPedId()

    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = "character:open"
    })

    return true
end

function CharacterManager.CloseCreator()
    if not CharacterManager.CreatorOpen then
        return false
    end

    CharacterManager.CreatorOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = "character:close"
    })

    return true
end

function CharacterManager.ApplyCharacter(character)
    if not CharacterManager.IsCreated(character) then
        return false
    end

    PlayerData.Character = character

    return true
end

local function sendCreatorError(message)
    SendNUIMessage({
        action = "character:error",
        message = message
    })
end

AddEventHandler(
    "sentinel:characterCreationRequired",
    function()
        CharacterManager.OpenCreator()
    end
)

AddEventHandler(
    "sentinel:profileSaveResult",
    function(saved)
        if not CharacterManager.SavePending then
            return
        end

        CharacterManager.SavePending = false

        if not saved then
            PlayerData.Character = nil
            CharacterManager.PendingCharacter = nil

            sendCreatorError(
                "No fue posible guardar el personaje. Inténtalo nuevamente."
            )

            return
        end

        local character =
            CharacterManager.PendingCharacter

        CharacterManager.PendingCharacter = nil

        if not CharacterManager.ApplyCharacter(character) then
            sendCreatorError(
                "El personaje guardado no es válido."
            )

            return
        end

        CharacterManager.CloseCreator()

        if not SpawnPlayerCharacter() then
            CharacterManager.OpenCreator()

            sendCreatorError(
                "No fue posible aplicar la base corporal."
            )
        end
    end
)

RegisterNUICallback(
    "character:previewBody",
    function(data, callback)
        local bodyModel = type(data) == "table"
            and tostring(data.bodyModel or "")
            or ""

        callback({
            ok = applyPreviewModel(bodyModel)
        })
    end
)

RegisterNUICallback(
    "character:create",
    function(data, callback)
        if CharacterManager.SavePending then
            callback({
                ok = false,
                error = "El personaje se está guardando."
            })

            return
        end

        local character, errorMessage =
            validateCharacterInput(data)

        if not character then
            sendCreatorError(errorMessage)

            callback({
                ok = false,
                error = errorMessage
            })

            return
        end

        CharacterManager.PendingCharacter = character
        CharacterManager.SavePending = true
        PlayerData.Character = character

        if not SaveProgress(true) then
            CharacterManager.SavePending = false
            CharacterManager.PendingCharacter = nil
            PlayerData.Character = nil

            sendCreatorError(
                "El perfil aún no está listo para guardar."
            )

            callback({
                ok = false,
                error = "El perfil aún no está listo."
            })

            return
        end

        callback({
            ok = true,
            pending = true
        })
    end
)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            SetNuiFocus(false, false)
        end
    end
)
