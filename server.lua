ESX = exports["es_extended"]:getSharedObject()

local vehiclesCache = {}

exports('resetPlate', function(plate)

    vehiclesCache[plate] = nil

end)

exports('giveTempKeys', function(plate, identifier, timeout)

    if not vehiclesCache[plate] then
        vehiclesCache[plate] = {}
    end

    vehiclesCache[plate][identifier] = true

    if timeout then
        Citizen.SetTimeout(timeout, function()
            if vehiclesCache[plate] and vehiclesCache[plate][identifier] then
                vehiclesCache[plate][identifier] = nil
            end
        end)
    end
end)

RegisterNetEvent('carkeys:RequestVehicleLock', function(netId, lockstatus)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(vehicle)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not plate then xPlayer.showNotification(_U('spz_not_found')) return end
    if not vehiclesCache[plate] then
        local result = MySQL.Sync.fetchAll('SELECT owner, peopleWithKeys FROM owned_vehicles WHERE plate = "'..plate..'"')
        if result and result[1] then
            vehiclesCache[plate] = {}
            vehiclesCache[plate][result[1].owner] = true
            local otherKeys = json.decode(result[1].peopleWithKeys)
            if not otherKeys then otherKeys = {} end
            for k, v in pairs(otherKeys) do
                vehiclesCache[plate][v] = true
            end
        end
    end
    if vehiclesCache[plate] and (vehiclesCache[plate][xPlayer.identifier] or vehiclesCache[plate][xPlayer.job.name]) then
        SetVehicleDoorsLocked(vehicle, lockstatus == 2 and 1 or 2)
        TriggerClientEvent('carlock:CarLockedEffect', xPlayer.source, netId, lockstatus ~= 2)
    else
        xPlayer.showNotification(_U('no_keys'))
    end
end)

RegisterNetEvent('carkeys:GiveKeyToPerson', function(plate, target)
    local xPlayer = ESX.GetPlayerFromId(source)
    local owner = MySQL.Sync.fetchScalar('SELECT owner FROM owned_vehicles WHERE plate = "'..plate..'"')
    if owner == xPlayer.identifier then
        local xTarget = ESX.GetPlayerFromId(target)
        local peopleWithKeys = MySQL.Sync.fetchScalar('SELECT peopleWithKeys FROM owned_vehicles WHERE plate = "'..plate..'"')
        local keysTable = json.decode(peopleWithKeys) or {}
        keysTable[xTarget.identifier] = true

        MySQL.Async.execute('UPDATE owned_vehicles SET peopleWithKeys = @peopleWithKeys WHERE plate = @plate', {
            ['@peopleWithKeys'] = json.encode(keysTable),
            ['@plate'] = plate
        }, function(rowsUpdated)
            if rowsUpdated > 0 then
                xTarget.showNotification(_U('received_keys', plate))
                xPlayer.showNotification(_U('gave_keys', plate))
            end
        end)

        if vehiclesCache[plate] then
            vehiclesCache[plate][xTarget.identifier] = true
        end

    else
        xPlayer.showNotification(_U('not_yours_vehicle'))
    end
end)

RegisterNetEvent('carkeys:NewLocks', function(plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    local isOwned = MySQL.Sync.fetchScalar('SELECT 1 FROM owned_vehicles WHERE plate = "'..plate..'" AND owner = "'..xPlayer.identifier..'"')
    if isOwned then
        if xPlayer.getMoney() >= Config.Price then
            xPlayer.removeMoney(Config.Price)
        elseif xPlayer.getAccount('bank').money >= Config.Price then
            xPlayer.removeAccountMoney('bank', Config.Price)
        else
            xPlayer.showNotification(_U('not_enough_money'))
            return
        end
        xPlayer.showNotification(_U('paid_for_locks', Config.Price))
        xPlayer.showNotification(_U('wait_new_locks'))
        TriggerClientEvent('progressBars:StartUI', xPlayer.source, 30000, _U('installing_new_locks'))
        FreezeEntityPosition(GetPlayerPed(xPlayer.source), true)
        local playersVeh = GetVehiclePedIsIn(GetPlayerPed(xPlayer.source))
        FreezeEntityPosition(playersVeh, true)
        Wait(30000)
        FreezeEntityPosition(GetPlayerPed(xPlayer.source), false)
        FreezeEntityPosition(playersVeh, false)
        MySQL.Async.execute('UPDATE owned_vehicles SET peopleWithKeys = "[]" WHERE plate = "'..plate..'"', {}, function(rowsUpdated)
            if rowsUpdated > 0 then
                xPlayer.showNotification(_('locks_replaced'))
                vehiclesCache[plate] = {}
                vehiclesCache[plate][xPlayer.identifier] = true
            end
        end)
    else
        xPlayer.showNotification(_U('not_yours_vehicle'))
    end
end)