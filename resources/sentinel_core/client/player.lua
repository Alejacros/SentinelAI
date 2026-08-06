PlayerData = {

    OnDuty = false,

    Unit = nil,

    Rank = "Cadete"

}

function AssignRandomUnit()

    local randomIndex = math.random(#Config.Units)

    PlayerData.Unit = Config.Units[randomIndex]

end