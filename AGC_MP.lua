-- DCS 机场地面控制 (MP)
-- DCS Airfield Ground Controller (MP)
--
-- Version 1.4
--
-- Change logs:
--     1. 修改了判断逻辑，优化代码
--     2. 增加了跑道外着陆检测
--     3. 增加了管理员命令
--
-- By Dennic - https://github.com/Dennic/DCS-Script-AGC_MP
--

agc  = {}


-- 违反规定后停飞时间（秒）
-- disableTimeout (Seconds)
agc.disableTimeout = 60

-- 警示滑行速度（节）
-- noticeTexiSpeed (Knots)
agc.noticeTexiSpeed = 30

-- 警示音
-- notification
agc.playSound = true -- 是否开启超速提示音
agc.soundNotice = "notice.ogg"

-- 第一个"%i"是当前值, 第二个"%i"是限制值
-- the first "%i" is for current value, and the secend is for limit value
agc.overspeedNotice = "【注意】%i 节 - 你已超速，请立刻减速！\n地面滑行速度严禁超过 %i 节，滑行道起飞将会被取消飞行资格。"

-- 最高监测高度（离地高度）
-- max monitor altitude (AGL)
agc.maxAlt = 500

agc.Runway = {
    {
        name = "Runway1",
    },
    {
        name = "Runway2",
    },
    {
        name = "Runway3",
    },
    {
        name = "Runway4",
    },
    {
        name = "Runway5",
    },
}

agc.Airfield = {

    "Airfield1",
    "Airfield2",
    "Airfield3",
    "Airfield4",
    "Airfield5",

}


function agc.displayNotice(_unit, _text, _time, _type, _playsound)

    local msg = {} 
    msg.text = _text
    msg.displayTime = _time
    msg.msgFor = {units = { _unit:getName() }}
    msg.name = _unit:getName() .. _type
    mist.message.add(msg)
    
    if _playsound and agc.playSound then
        trigger.action.outSoundForGroup(_unit:getGroup():getID(), agc.soundFile )
    end
    
end


function agc.checkOnRunway(_unit)

    local _unitPos = _unit:getPosition().p

    for _,_runway in pairs(agc.Runway) do
        if _runway.polygon and mist.pointInPolygon(_unitPos,_runway.polygon,_runway.maxAlt) then
            return true
        end
    end

    return false
end


function agc.checkTraffic()
    
    local _AllPlanes = mist.makeUnitTable({"[all][plane]"})

    local _units = mist.getUnitsInZones(_AllPlanes ,agc.Airfield)
    for __,_unit in pairs(_units) do
    
        if _unit:isActive() and _unit:getLife() > 0 and _unit:getPlayerName() then
    
            if not _unit:inAir() then
                
                if not agc.checkOnRunway(_unit) then
                
                    local _unitData = mist.utils.unitToWP( _unit )
                    local _unitSpeed = math.floor(mist.utils.mpsToKnots(_unitData["speed"]))
                    if _unitSpeed > agc.noticeTexiSpeed then
                        agc.displayNotice(_unit, string.format(agc.overspeedNotice, _unitSpeed, agc.noticeTexiSpeed), 1, "noticeTexiSpeed", true)
                    end
                    
                end
                
            end
            
        end
    end

    mist.scheduleFunction(agc.checkTraffic, {}, timer.getTime() + 1)

end


function agc.onAirfield(_unit)
    local _unitName = _unit:getName()
    local _units = mist.getUnitsInZones({_unitName} ,agc.Airfield)

    if #(_units) > 0 then
        return true
    else
        return false
    end
    
end

function agc.isPlane(_unit)
    local _unitName = _unit:getName()
    local _AllPlanes = mist.makeUnitTable({"[all][plane]"})

    for _,__unitName in pairs(_AllPlanes) do
        if _unitName == __unitName then
            return true
        end
    end
    
    return false
end


-- Handles all world events
agc.eventHandler = {}
function agc.eventHandler:onEvent(_event)
    local status, err = pcall(function(_event)

        if _event == nil or _event.initiator == nil then
            return false
            
        elseif  _event.id == 3 or _event.id == 4 then -- 起飞或着陆
        
            local _unit = _event.initiator
            
            if  _unit:getPlayerName() and agc.isPlane(_unit) and agc.onAirfield(_unit) then

                if agc.checkOnRunway(_unit) then
                    trigger.action.setUserFlag("AGC_DontTakeoff" .. string.gsub(_unit:getPlayerName(), '%W', ''), 0)
                    trigger.action.setUserFlag("AGC_DontLand" .. string.gsub(_unit:getPlayerName(), '%W', ''), 0)
                else
                    trigger.action.setUserFlag("AGC_DontTakeoff" .. string.gsub(_unit:getPlayerName(), '%W', ''), 1)
                    trigger.action.setUserFlag("AGC_DontLand" .. string.gsub(_unit:getPlayerName(), '%W', ''), 1)
                end
                
            else
                
            end
            
        end
        return true
    end, _event)
    if (not status) then
        env.error(string.format("Error while handling event %s", err),false)
    end
end

for _,_runway in pairs(agc.Runway) do

    if Group.getByName(_runway.name) then
        local _points = mist.getGroupPoints(_runway.name)
        _runway.polygon = _points
        local _landAlt = 0
        for _,_point in pairs(_points) do
            if land.getHeight(_point) > _landAlt then
                _landAlt = land.getHeight(_point)
            end
        end
        _runway.maxAlt = _landAlt + agc.maxAlt
    else
        _runway.polygon = nil
    end
    
end


agc.soundFile = "l10n/DEFAULT/"..agc.soundNotice
function agc.setNoticeSound(_filename)
    agc.soundFile = "l10n/DEFAULT/".._filename
end

trigger.action.setUserFlag("AGC_DisableTimeout", agc.disableTimeout)

world.addEventHandler(agc.eventHandler)

mist.scheduleFunction(agc.checkTraffic, nil, timer.getTime() + 1)
