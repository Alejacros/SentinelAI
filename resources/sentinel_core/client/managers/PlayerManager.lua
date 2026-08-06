PlayerData = {

    OnDuty = false,

    Unit = nil,

    Rank = "Cadete",

    Vehicle = nil,

    SceneNPC = nil,

    DispatchState = "OFF_DUTY"

}

function AssignRandomUnit()

    local randomIndex = math.random(#Config.Units)

    PlayerData.Unit = Config.Units[randomIndex]

end

PlayerData.Vehicle = nil
PlayerData.SceneNPC = nil