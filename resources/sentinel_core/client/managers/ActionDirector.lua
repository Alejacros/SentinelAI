print("[Sentinel AI] ActionDirector iniciado.")

ActionDirector = {}

local directors = {}

function ActionDirector.Register(name, callback)

    directors[name] = callback

end

function ActionDirector.Build(incident)

    if not incident then
        return false
    end

    local callback = directors[incident.type]

    if not callback then

        print(
            "[ActionDirector] No existe director para "
            .. tostring(incident.type)
        )

        return false
    end

    return callback(incident)

end

print("[Sentinel AI] ActionDirector listo.")