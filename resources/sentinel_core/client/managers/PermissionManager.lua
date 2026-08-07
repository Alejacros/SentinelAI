PermissionManager = {}

local function contains(values, expected)
    for _, value in ipairs(values or {}) do
        if value == expected then
            return true
        end
    end

    return false
end

local function getRank(context)
    return context.rank
        or (PlayerData and PlayerData.Rank)
        or "Cadete"
end

function PermissionManager.Can(action, context)
    context = context or {}

    if context.onDuty == false then
        return false, "OFF_DUTY"
    end

    if action == "vehicle.locate" then
        if context.vehicleState ~= "NONE" then
            return true
        end

        return false, "NO_ACTIVE_UNIT"
    end

    local moduleId = tostring(action or ""):match(
        "^terminal%.module%.(.+)$"
    )

    if moduleId then
        for _, module in ipairs(TerminalModules or {}) do
            if module.id == moduleId then
                if not contains(module.allowedModes, context.terminalMode) then
                    return false, "CONTEXT_RESTRICTED"
                end

                if not IsRankAtLeast(getRank(context), module.minRank) then
                    return false, "RANK_REQUIRED"
                end

                return module.implemented == true,
                    module.implemented and nil or "NOT_IMPLEMENTED"
            end
        end
    end

    if action == "dispatch.accept"
        or action == "dispatch.decline" then

        return context.onDuty == true, nil
    end

    return false, "UNKNOWN_ACTION"
end

function PermissionManager.GetAllowedModules(context)
    context = context or {}
    local modules = {}

    for _, module in ipairs(TerminalModules or {}) do
        local modeAllowed = contains(
            module.allowedModes,
            context.terminalMode
        )
        local rankAllowed = IsRankAtLeast(
            getRank(context),
            module.minRank
        )
        local dutyAllowed = context.onDuty == true

        modules[#modules + 1] = {
            id = module.id,
            label = module.label,
            icon = module.icon,
            implemented = module.implemented == true,
            modeAllowed = modeAllowed,
            allowed = modeAllowed
                and dutyAllowed
                and rankAllowed
                and module.implemented == true,
            locked = not dutyAllowed or not rankAllowed,
            visible = context.terminalMode ~= "DRIVER_SAFE"
                or modeAllowed,
            reason = not dutyAllowed
                and "Debes estar en servicio"
                or not rankAllowed
                and ("Requiere rango " .. module.minRank)
                or (not module.implemented and "Próximamente")
                or (not modeAllowed and "No disponible en este modo")
                or nil
        }
    end

    return modules
end

function PermissionManager.GetCapabilities(context)
    context = context or {}

    return {
        rank = getRank(context),
        certifications = {},
        division = nil,
        assignment = nil,
        terminalMode = context.terminalMode,
        onDuty = context.onDuty == true,
        vehicleState = context.vehicleState or "NONE",
        canUseFullNavigation = context.terminalMode ~= "DRIVER_SAFE"
    }
end
