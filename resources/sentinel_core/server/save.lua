local RESOURCE_NAME = GetCurrentResourceName()
local SAVE_FILE = "data/profiles.json"

print(
    ("[Sentinel AI] RUNTIME PATH | resource=%s | path=%s | save=%s")
        :format(
            tostring(RESOURCE_NAME),
            tostring(GetResourcePath(RESOURCE_NAME)),
            tostring(SAVE_FILE)
        )
)

local profiles = {}

print(
    "[Sentinel AI] Perfil persistente: "
        .. SAVE_FILE
)

local function countProfiles()
    local count = 0

    for _ in pairs(profiles) do
        count = count + 1
    end

    return count
end

local function writeProfiles(encoded)
    local successWrite, result =
        pcall(
            SaveResourceFile,
            RESOURCE_NAME,
            SAVE_FILE,
            encoded,
            -1
        )

    if not successWrite or not result then
        print(
            "[Sentinel AI] ERROR escribiendo profiles.json: "
                .. tostring(result)
        )

        return false
    end

    print(
        "[Sentinel AI] profiles.json guardado correctamente."
    )

    return true
end

local function loadProfiles()
    local rawData = LoadResourceFile(
        RESOURCE_NAME,
        SAVE_FILE
    )

    if not rawData or rawData == "" then
        profiles = {}

        if writeProfiles("{}") then
            print(
                "[Sentinel AI] Base de perfiles creada."
            )
        end

        print(
            ("[Sentinel AI] Perfiles cargados: %d")
                :format(countProfiles())
        )

        return
    end

    local success, decoded =
        pcall(json.decode, rawData)

    if not success
        or type(decoded) ~= "table" then

        profiles = {}

        print(
            "[Sentinel AI] ERROR: profiles.json inválido."
        )

        return
    end

    profiles = decoded

    print(
        ("[Sentinel AI] Perfiles cargados: %d")
            :format(countProfiles())
    )
end

local function saveProfiles()
    local success, encoded =
        pcall(json.encode, profiles)

    if not success or not encoded then
        print(
            "[Sentinel AI] ERROR codificando perfiles."
        )

        return false
    end

    return writeProfiles(encoded)
end

local function getPlayerIdentifier(sourceId)
    local license =
        GetPlayerIdentifierByType(
            sourceId,
            "license"
        )

    if license then
        return license
    end

    local fivem =
        GetPlayerIdentifierByType(
            sourceId,
            "fivem"
        )

    if fivem then
        return fivem
    end

    return ("player:%s"):format(
        tostring(sourceId)
    )
end

local function sanitizeHistory(history)
    if type(history) ~= "table" then
        return {}
    end

    local cleanHistory = {}

    for index, caseData in ipairs(history) do
        if index > 100 then
            break
        end

        if type(caseData) == "table" then
            local evidence = {}

            for evidenceIndex, evidenceName
                in ipairs(caseData.evidence or {}) do

                if evidenceIndex > 20 then
                    break
                end

                evidence[#evidence + 1] =
                    tostring(evidenceName)
            end

            cleanHistory[#cleanHistory + 1] = {
                id = tonumber(caseData.id) or index,
                code = tostring(caseData.code or "000"),
                title = tostring(caseData.title or "Incidente"),
                state = "COMPLETED",
                witness = tostring(caseData.witness or ""),
                evidence = evidence,
                suspect = type(caseData.suspect) == "table"
                    and caseData.suspect
                    or {},
                xp = tonumber(caseData.xp) or 0,
                startedAt = tostring(caseData.startedAt or ""),
                completedAt = tostring(caseData.completedAt or ""),
                durationSeconds =
                    tonumber(caseData.durationSeconds) or 0
            }
        end
    end

    return cleanHistory
end

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

local function sanitizeText(value, maximumLength)
    local text = tostring(value or "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")

    if text == "" then
        return nil
    end

    return text:sub(1, maximumLength)
end

local function sanitizeNumber(value, minimum, maximum)
    local number = tonumber(value)

    if not number or number ~= number then
        return nil
    end

    return math.max(
        minimum,
        math.min(maximum, number)
    )
end

local faceFeatureNames = {
    "noseWidth",
    "nosePeakHigh",
    "nosePeakSize",
    "noseBoneHigh",
    "nosePeakLowering",
    "noseBoneTwist",
    "eyeBrownHigh",
    "eyeBrownForward",
    "cheeksBoneHigh",
    "cheeksBoneWidth",
    "cheeksWidth",
    "eyesOpening",
    "lipsThickness",
    "jawBoneWidth",
    "jawBoneBackSize",
    "chinBoneLowering",
    "chinBoneLenght",
    "chinBoneSize",
    "chinHole",
    "neckThickness"
}

local headOverlayNames = {
    "blemishes",
    "beard",
    "eyebrows",
    "ageing",
    "makeUp",
    "blush",
    "complexion",
    "sunDamage",
    "lipstick",
    "moleAndFreckles",
    "chestHair",
    "bodyBlemishes"
}

local allowedComponentIds = {
    [0] = true,
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
    [5] = true,
    [6] = true,
    [7] = true,
    [8] = true,
    [9] = true,
    [10] = true,
    [11] = true
}

local allowedPropIds = {
    [0] = true,
    [1] = true,
    [2] = true,
    [6] = true,
    [7] = true
}

local function sanitizeAppearanceData(data, bodyModel)
    if type(data) ~= "table"
        or tostring(data.model or "") ~= bodyModel
        or type(data.headBlend) ~= "table"
        or type(data.faceFeatures) ~= "table"
        or type(data.headOverlays) ~= "table"
        or type(data.hair) ~= "table"
        or type(data.components) ~= "table"
        or type(data.props) ~= "table" then

        return nil
    end

    local headBlend = {
        shapeFirst = sanitizeNumber(
            data.headBlend.shapeFirst,
            0,
            45
        ),
        shapeSecond = sanitizeNumber(
            data.headBlend.shapeSecond,
            0,
            45
        ),
        skinFirst = sanitizeNumber(
            data.headBlend.skinFirst,
            0,
            45
        ),
        skinSecond = sanitizeNumber(
            data.headBlend.skinSecond,
            0,
            45
        ),
        shapeMix = sanitizeNumber(
            data.headBlend.shapeMix,
            0,
            1
        ),
        skinMix = sanitizeNumber(
            data.headBlend.skinMix,
            0,
            1
        )
    }

    if headBlend.shapeFirst == nil
        or headBlend.shapeSecond == nil
        or headBlend.skinFirst == nil
        or headBlend.skinSecond == nil
        or headBlend.shapeMix == nil
        or headBlend.skinMix == nil then

        return nil
    end

    local faceFeatures = {}

    for _, name in ipairs(faceFeatureNames) do
        local value = sanitizeNumber(
            data.faceFeatures[name],
            -1,
            1
        )

        if value == nil then
            return nil
        end

        faceFeatures[name] = value
    end

    local headOverlays = {}

    for _, name in ipairs(headOverlayNames) do
        local overlay = data.headOverlays[name]

        if type(overlay) ~= "table" then
            return nil
        end

        local style = sanitizeNumber(
            overlay.style,
            0,
            255
        )
        local opacity = sanitizeNumber(
            overlay.opacity,
            0,
            1
        )

        if style == nil or opacity == nil then
            return nil
        end

        headOverlays[name] = {
            style = style,
            opacity = opacity,
            color = sanitizeNumber(
                overlay.color or 0,
                0,
                255
            ),
            secondColor = sanitizeNumber(
                overlay.secondColor or 0,
                0,
                255
            )
        }
    end

    local hair = {
        style = sanitizeNumber(
            data.hair.style,
            0,
            1000
        ),
        color = sanitizeNumber(
            data.hair.color,
            0,
            255
        ),
        highlight = sanitizeNumber(
            data.hair.highlight,
            0,
            255
        )
    }

    local eyeColor = sanitizeNumber(
        data.eyeColor,
        0,
        31
    )

    if hair.style == nil
        or hair.color == nil
        or hair.highlight == nil
        or eyeColor == nil then

        return nil
    end

    local components = {}

    for index, component in ipairs(data.components) do
        if index > 12
            or type(component) ~= "table" then

            return nil
        end

        local componentId = tonumber(
            component.component_id
        )

        if not allowedComponentIds[componentId] then
            return nil
        end

        components[#components + 1] = {
            component_id = componentId,
            drawable = sanitizeNumber(
                component.drawable,
                0,
                10000
            ),
            texture = sanitizeNumber(
                component.texture,
                0,
                1000
            )
        }

        if components[#components].drawable == nil
            or components[#components].texture == nil then

            return nil
        end
    end

    local props = {}

    for index, prop in ipairs(data.props) do
        if index > 5 or type(prop) ~= "table" then
            return nil
        end

        local propId = tonumber(prop.prop_id)

        if not allowedPropIds[propId] then
            return nil
        end

        props[#props + 1] = {
            prop_id = propId,
            drawable = sanitizeNumber(
                prop.drawable,
                -1,
                10000
            ),
            texture = sanitizeNumber(
                prop.texture,
                0,
                1000
            )
        }

        if props[#props].drawable == nil
            or props[#props].texture == nil then

            return nil
        end
    end

    return {
        model = bodyModel,
        headBlend = headBlend,
        faceFeatures = faceFeatures,
        headOverlays = headOverlays,
        hair = hair,
        eyeColor = eyeColor,
        components = components,
        props = props,
        tattoos = {}
    }
end

local function sanitizeCharacter(
    character,
    existingCharacter
)
    if character == nil then
        return nil, true
    end

    if type(character) ~= "table"
        or character.created ~= true then

        return nil, false
    end

    local identity = character.identity
    local appearance = character.appearance

    if type(identity) ~= "table"
        or type(appearance) ~= "table" then

        return nil, false
    end

    local firstName =
        sanitizeText(identity.firstName, 32)

    local lastName =
        sanitizeText(identity.lastName, 32)

    local genderIdentity =
        tostring(identity.genderIdentity or "")

    local pronouns = identity.pronouns
    local pronounType = type(pronouns) == "table"
        and tostring(pronouns.type or "")
        or ""

    local bodyModel =
        tostring(appearance.bodyModel or "")

    if not firstName
        or not lastName
        or not allowedGenderIdentities[genderIdentity]
        or not allowedPronouns[pronounType]
        or not allowedBodyModels[bodyModel] then

        return nil, false
    end

    local customPronouns = nil

    if pronounType == "custom" then
        customPronouns =
            sanitizeText(pronouns.custom, 48)

        if not customPronouns then
            return nil, false
        end
    end

    local cleanAppearance = {
        bodyModel = bodyModel
    }

    if appearance.data ~= nil then
        if tonumber(appearance.version) ~= 1 then
            return nil, false
        end

        local appearanceData =
            sanitizeAppearanceData(
                appearance.data,
                bodyModel
            )

        if not appearanceData then
            return nil, false
        end

        cleanAppearance.version = 1
        cleanAppearance.data = appearanceData
    end

    local now = os.time()
    local createdAt = type(existingCharacter) == "table"
        and tonumber(existingCharacter.createdAt)
        or nil

    return {
        created = true,
        version = 1,

        identity = {
            firstName = firstName,
            lastName = lastName,
            genderIdentity = genderIdentity,

            pronouns = {
                type = pronounType,
                custom = customPronouns
            }
        },

        appearance = cleanAppearance,

        firstSpawn = character.firstSpawn ~= false,
        academyCompleted =
            character.academyCompleted == true,

        createdAt = createdAt or now,
        updatedAt = now
    }, true
end

local function sanitizeProfile(payload, existingProfile)
    payload = type(payload) == "table"
        and payload
        or {}

    local character, characterValid =
        sanitizeCharacter(
            payload.character,
            type(existingProfile) == "table"
                and existingProfile.character
                or nil
        )

    if not characterValid then
        return nil
    end

    return {
        schemaVersion = 2,

        xp = math.max(
            0,
            tonumber(payload.xp) or 0
        ),

        completedCases = math.max(
            0,
            tonumber(payload.completedCases) or 0
        ),

        history = sanitizeHistory(
            payload.history
        ),

        character = character,

        updatedAt = os.time()
    }
end

RegisterNetEvent(
    "sentinel:server:requestProfile",
    function()
        local sourceId = source

        local identifier =
            getPlayerIdentifier(sourceId)

        local profile =
            profiles[identifier]

        if type(profile) ~= "table" then
            profile = {
                schemaVersion = 2,
                xp = 0,
                completedCases = 0,
                history = {},
                character = nil,
                updatedAt = os.time()
            }

            profiles[identifier] = profile
            saveProfiles()
        end

        TriggerClientEvent(
            "sentinel:client:loadProfile",
            sourceId,
            profile
        )
    end
)

RegisterNetEvent(
    "sentinel:server:saveProfile",
    function(payload)
        local sourceId = source

        local identifier =
            getPlayerIdentifier(sourceId)

        local sanitizedProfile =
            sanitizeProfile(
                payload,
                profiles[identifier]
            )

        if not sanitizedProfile then
            TriggerClientEvent(
                "sentinel:client:profileSaved",
                sourceId,
                false
            )

            return
        end

        profiles[identifier] =
            sanitizedProfile

        local saved = saveProfiles()

        TriggerClientEvent(
            "sentinel:client:profileSaved",
            sourceId,
            saved
        )
    end
)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName ~= RESOURCE_NAME then
            return
        end

        saveProfiles()
    end
)

loadProfiles()
