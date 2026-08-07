local COMMAND_CATEGORIES = {
    "SENTINEL",
    "CARRERA",
    "VEHÍCULOS",
    "DESARROLLO"
}

local function printAvailableCommands()
    print("=== SENTINEL AI — COMANDOS ===")

    for _, category in ipairs(COMMAND_CATEGORIES) do
        local printedHeader = false

        for _, commandData in ipairs(SentinelCommands or {}) do
            local visible = commandData.category == category
                and (not commandData.devOnly
                    or (Config and Config.DevMode == true))

            if visible then
                if not printedHeader then
                    print("")
                    print(category .. ":")
                    printedHeader = true
                end

                local usage = commandData.usage
                    and (" " .. commandData.usage)
                    or ""

                print(("/%s%s - %s"):format(
                    commandData.command,
                    usage,
                    commandData.description
                ))
            end
        end
    end

    print("===============================")

    if Sentinel and Sentinel.Notify then
        Sentinel.Notify(
            "SENTINEL",
            "Lista de comandos impresa en F8.",
            {90, 190, 255}
        )
    end
end

RegisterCommand("commands", printAvailableCommands, false)
RegisterCommand("help", printAvailableCommands, false)
