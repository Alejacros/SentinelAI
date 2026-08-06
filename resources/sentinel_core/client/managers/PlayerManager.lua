PlayerData = {
    OnDuty = false,

    Rank = "Cadete",
    XP = 0,
    CompletedCases = 0,

    Unit = nil,
    Vehicle = nil,

    DispatchState = "OFF_DUTY",
    CurrentDispatch = nil,
    DispatchBlip = nil,

    SceneNPC = nil,
    SceneBlip = nil
}

local unitPrefixes = {
    "ADAM",
    "BRAVO",
    "CHARLIE",
    "DELTA",
    "EDWARD",
    "FRANK",
    "GEORGE",
    "LINCOLN",
    "VICTOR"
}

function AssignRandomUnit()
    local prefix = unitPrefixes[math.random(#unitPrefixes)]
    local number = math.random(1, 99)

    PlayerData.Unit = string.format("%s-%02d", prefix, number)
end