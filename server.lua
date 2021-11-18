TriggerEvent('esx:getShkFxaredObjkFxect', function(obj) ESX = obj end)

local vehiclesCache = {}

exports('resetPlate', function(plate)

    vehiclesCache[plate] = nil

end)

RegisterNetEvent('carkeys:RequestVehicleLock', function(netId, lockstatus)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(vehicle)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not plate then xPlayer.showNotification('Nepodařilo se najít SPZ vozidla') return end
    if not vehiclesCache[plate] then
        local result = MySQL.Sync.fetchAll('SELECT owner, peopleWithKeys FROM owned_vehicles WHERE plate = "'..plate..'"')
        if result and result[1] then
            vehiclesCache[plate] = {}
            vehiclesCache[plate][result[1].owner] = true
            local otherKeys = json.decode(result[1].peopleWithKeys)
            for k, v in pairs(otherKeys) do
                vehiclesCache[plate][v] = true
            end
        end
    end
    if vehiclesCache[plate] and (vehiclesCache[plate][xPlayer.identifier] or vehiclesCache[plate][xPlayer.job.name]) then
        SetVehicleDoorsLocked(vehicle, lockstatus == 2 and 1 or 2)
        TriggerClientEvent('carlock:CarLockedEffect', xPlayer.source, netId, lockstatus ~= 2)
    else
        xPlayer.showNotification('Od tohoto auta nemáš klíče')
    end
end)

RegisterNetEvent('carkeys:GiveKeyToPerson', function(plate, target)
    local xPlayer = ESX.GetPlayerFromId(source)

    local owner = MySQL.Sync.fetchScalar('SELECT owner FROM owned_vehicles WHERE plate = "'..plate..'"')
    if owner == xPlayer.identifier then
        local xTarget = ESX.GetPlayerFromId(target)
        local peopleWithKeys = MySQL.Sync.fetchScalar('SELECT peopleWithKeys FROM owned_vehicles WHERE plate = "'..plate..'"')
        local keysTable = json.decode(peopleWithKeys)
        keysTable[xTarget.identifier] = true

        MySQL.Async.execute('UPDATE owned_vehicles SET peopleWithKeys = @peopleWithKeys WHERE plate = @plate', {
            ['@peopleWithKeys'] = json.encode(keysTable),
            ['@plate'] = plate
        }, function(rowsUpdated)
            if rowsUpdated > 0 then
                xTarget.showNotification('Dostal jsi klíče od vozidla s SPZ: '..plate)
                xPlayer.showNotification('Dal jsi klíče od vozidla s SPZ: '..plate)
            end
        end)

        if vehiclesCache[plate] then
            vehiclesCache[plate][xTarget.identifier] = true
        end

    else
        xPlayer.showNotification('Nevlastníš toto vozidlo')
    end
end)

RegisterNetEvent('carkeys:NewLocks', function(plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    local isOwned = MySQL.Sync.fetchScalar('SELECT 1 FROM owned_vehicles WHERE plate = "'..plate..'" AND owner = "'..xPlayer.identifier..'"')
    if isOwned then
        if xPlayer.getMoney() >= 5000 then
            xPlayer.removeMoney(5000)
        elseif xPlayer.getAccount('bank').money >= 5000 then
            xPlayer.removeAccountMoney('bank', 5000)
        else
            xPlayer.showNotification('Nemáš na zaplacení nových zámků')
            return
        end
        xPlayer.showNotification('Zaplatil jsi 5000$ za nové zámky')
        xPlayer.showNotification('Nyní počkej půl minuty na nové zámky')
        TriggerClientEvent('progressBars:StartUI', xPlayer.source, 30000, 'Probíhá instalace nových zámků')
        FreezeEntityPosition(GetPlayerPed(xPlayer.source), true)
        local playersVeh = GetVehiclePedIsIn(GetPlayerPed(xPlayer.source))
        FreezeEntityPosition(playersVeh, true)
        Wait(30000)
        FreezeEntityPosition(GetPlayerPed(xPlayer.source), false)
        FreezeEntityPosition(playersVeh, false)
        MySQL.Async.execute('UPDATE owned_vehicles SET peopleWithKeys = "[]" WHERE plate = "'..plate..'"', {}, function(rowsUpdated)
            if rowsUpdated > 0 then
                xPlayer.showNotification('Zámky úspěšně vyměněny')
                vehiclesCache[plate] = {}
                vehiclesCache[plate][xPlayer.identifier] = true
            end
        end)
    else
        xPlayer.showNotification('Toto vozidlo není tvoje')
    end
end)