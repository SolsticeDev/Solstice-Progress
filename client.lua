local display = false
local isAnimPlaying = false
local currentProps = {}

local AnimationList = {
    ['phone'] = {
        dict = "cellphone@",
        anim = "cellphone_text_read_base",
        flag = 49,
        props = {
            {
                model = `prop_npc_phone_02`,
                bone = 28422,
                pos = vector3(0.0, 0.0, 0.0),
                rot = vector3(0.0, 0.0, 0.0)
            }
        }
    },
    ['tablet'] = {
        dict = "amb@code_human_in_bus_passenger_idles@female@tablet@idle_a",
        anim = "idle_b",
        flag = 49,
        props = {
            {
                model = `prop_cs_tablet`,
                bone = 60309,
                pos = vector3(0.03, 0.002, -0.0),
                rot = vector3(10.0, 160.0, 0.0)
            }
        }
    },
    ['type'] = {
        dict = "anim@heists@prison_heistig1_p1_guard_checks_bus",
        anim = "loop",
        flag = 49,
        props = {}  
    },
    ['splice'] = {
        dict = "anim@gangops@facility@servers@",
        anim = "hotwire",
        flag = 1,
        props = {}
    },
    ['search'] = {
        dict = "amb@prop_human_bum_bin@idle_a",
        anim = "idle_a",
        flag = 1,
        props = {}
    }
}

local disableControls = {
    disableMovement = false,
    disableCarMovement = false,
    disableMouse = false,
    disableCombat = false
}

local function LoadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

local function LoadModel(model)
    if type(model) == 'string' then model = GetHashKey(model) end
    while not HasModelLoaded(model) do
        RequestModel(model)
        Wait(10)
    end
end

local function HandleControls()
    if disableControls.disableMovement then
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
    end
    if disableControls.disableCarMovement then
        DisableControlAction(0, 63, true)
        DisableControlAction(0, 64, true)
    end
    if disableControls.disableMouse then
        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)
    end
    if disableControls.disableCombat then
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 47, true)
    end
end

local function HandleProps(propData)
    local ped = PlayerPedId()
    local props = {}
    
    if propData then
        if type(propData) ~= 'table' then propData = {propData} end
        for _, prop in ipairs(propData) do
            if prop.model then
                LoadModel(prop.model)
                local propObj = CreateObject(GetHashKey(prop.model), 0.0, 0.0, 0.0, true, true, true)
                AttachEntityToEntity(propObj, ped, 
                    GetPedBoneIndex(ped, prop.bone or 60309),
                    prop.pos.x or 0.0, prop.pos.y or 0.0, prop.pos.z or 0.0,
                    prop.rot.x or 0.0, prop.rot.y or 0.0, prop.rot.z or 0.0,
                    true, true, false, true, 1, true)
                table.insert(props, propObj)
            end
        end
    end
    return props
end

local function HandleAnimation(animation)
    if not animation then return end
    
    local ped = PlayerPedId()
    if animation.dict then
        LoadAnimDict(animation.dict)
        if not IsEntityPlayingAnim(ped, animation.dict, animation.anim, 3) then
            TaskPlayAnim(ped, animation.dict, animation.anim, 8.0, 8.0, -1, animation.flag or 49, 0, false, false, false)
        end
    elseif AnimationList[animation] then
        local animData = AnimationList[animation]
        LoadAnimDict(animData.dict)
        TaskPlayAnim(ped, animData.dict, animData.anim, 8.0, 8.0, -1, animData.flag, 0, false, false, false)
    end
end

local function Progress(data, cb)
    if display then return end
    
    display = true
    local props = {}
    local isCancelled = false
    
    if data.controlDisables then
        disableControls = data.controlDisables
    end
    
    if data.prop then
        props = HandleProps(data.prop)
    end
    if data.propTwo then
        local secondaryProps = HandleProps(data.propTwo)
        for _, prop in ipairs(secondaryProps) do
            table.insert(props, prop)
        end
    end
    
    HandleAnimation(data.animation)
    
    SendNUIMessage({
        type = "ui",
        display = true,
        time = data.duration,
        text = data.label
    })
    
    if data.canCancel then
        Citizen.CreateThread(function()
            while display do
                if IsControlJustPressed(0, 177) then
                    isCancelled = true
                    display = false
                    break
                end
                Wait(0)
            end
        end)
    end
    
    Citizen.CreateThread(function()
        while display do
            HandleControls()
            Wait(0)
        end
    end)
    
    Citizen.Wait(data.duration)
    
    display = false
    ClearPedTasks(PlayerPedId())
    for _, prop in ipairs(props) do
        DeleteEntity(prop)
    end
    
    if cb then
        cb(isCancelled)
    end
end

exports('Progress', Progress)

exports('showProgressBar', function(name, label, duration, useWhileDead, canCancel, disableControls, animation, prop, propTwo, onFinish, onCancel)
    Progress({
        name = name and name:lower() or 'default',
        duration = duration or 5000,
        label = label or '',
        useWhileDead = useWhileDead or false,
        canCancel = canCancel or false,
        controlDisables = disableControls or {},
        animation = animation,
        prop = prop,
        propTwo = propTwo
    }, function(cancelled)
        if not cancelled and onFinish then
            onFinish()
        elseif cancelled and onCancel then
            onCancel()
        end
    end)
end)

RegisterCommand('testbar', function(source, args)
    local time = tonumber(args[1]) or 5000
    local text = args[2] or "Testing Progress Bar..."
    local anim = args[3]
    
    Progress({
        name = 'test',
        duration = time,
        label = text,
        useWhileDead = false,
        canCancel = true,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true
        },
        animation = anim,
    }, function(cancelled)
        if cancelled then
            print('Progress bar cancelled')
        else
            print('Progress bar completed')
        end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    if display then
        display = false
        ClearPedTasks(PlayerPedId())
    end
end)