print("[Sentinel AI] RobberyDirector cargado.")

ActionDirector.Register(

"ROBBERY",

function(incident)

    local profile = {}

    profile.scene = "ROBBERY"

    profile.suspects =
        math.random(1,2)

    profile.witnesses =
        math.random(1,3)

    profile.evidence = {

        "Wallet",

        "Phone",

        "Weapon"

    }

    profile.backup =
        math.random() < 0.35

    profile.ems =
        math.random() < 0.10

    profile.fire =
        false

    profile.weather =
        GetPrevWeatherTypeHashName()

    return profile

end)

print("[Sentinel AI] RobberyDirector listo.")