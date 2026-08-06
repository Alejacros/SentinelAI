local function drawHudText(text, x, y, scale)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

CreateThread(function()
    while true do
        Wait(0)

        if PlayerData.OnDuty then
            DrawRect(0.88, 0.16, 0.20, 0.16, 0, 0, 0, 170)

            drawHudText("SENTINEL AI", 0.79, 0.09, 0.38)
            drawHudText("Rango: " .. PlayerData.Rank, 0.79, 0.13, 0.30)
            drawHudText("Unidad: " .. (PlayerData.Unit or "Sin asignar"), 0.79, 0.17, 0.30)
            drawHudText("Estado: EN SERVICIO", 0.79, 0.21, 0.30)
        end
    end
end)