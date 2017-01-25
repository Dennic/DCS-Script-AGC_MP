local agcST = {} 

-- 
-- AGC_MP 服务器可选飞机管理工具
-- AGC_MP Slot Blocking Tools
--
-- Version 1.1
--
-- By Dennic - https://github.com/Dennic/DCS-Script-AGC_MP
--

agcST.disabledPlayerTimeleft = {}



function agcST.agcCheck(_playerID, _slotID, _mode)

    local _unitId = agcST.getUnitId(_slotID);

    local _playerName = net.get_player_info(_playerID, 'name')

    if _playerName == nil then
        return true
    end
    
    local _flag = 0
    
    if _mode == 1 then
        _flag = agcST.getFlagValue("AGC_DontTakeoff".._playerName:gsub('%W',''))
        
        if _flag == 1 then
            if _mode == 1 then
                local _funcStr = string.format(" return ssb.violation(\"%s\");",_playerName:gsub('%W',''))
                local _status,_error = net.dostring_in('server',_funcStr)
            end
            return false
        end
        
        
        
        
        
    elseif _mode == 2 then
        _flag = agcST.getFlagValue("AGC_DontEject".._playerName:gsub('%W',''))
        
        if _flag == 1 then
            return false
        end
        
        
    elseif _mode == 3 then
        _flag = agcST.getFlagValue("AGC_Violation".._playerName:gsub('%W',''))
        
        return _flag
        
        
        
        
        
        
    else
        return true
    end

    return true

end

function agcST.getFlagValue(_flag)

    local _status,_error  = net.dostring_in('server', " return trigger.misc.getUserFlag(\"".._flag.."\"); ")

    if not _status and _error then
        net.log("error getting flag: ".._error)
        return 0
    else
        return tonumber(_status)
    end
    
end

function agcST.getUnitId(_slotID)
    local _unitId = tostring(_slotID)
    if string.find(tostring(_unitId),"_",1,true) then
        --extract substring
        _unitId = string.sub(_unitId,1,string.find(_unitId,"_",1,true))
        net.log("Unit ID Substr ".._unitId)
    end

    return tonumber(_unitId)
end

agcST.onGameEvent = function(eventName,playerID,arg2,arg3,arg4) -- This stops the user flying again after crashing or other events

    if  DCS.isServer() and DCS.isMultiplayer() then
        if DCS.getModelTime() > 1 then  -- must check this to prevent a possible CTD by using a_do_script before the game is ready to use a_do_script. -- Source GRIMES :)

            local _playerDetails = nil
            local _allow = true
        
            if eventName == "eject" then

                -- is player in a slot and valid?
                _playerDetails = net.get_player_info(playerID)

                if _playerDetails ~=nil and _playerDetails.side ~= 0 and _playerDetails.slot ~= "" and _playerDetails.slot ~= nil then

                    _allow = agcST.agcCheck(playerID, _playerDetails.slot, 2)

                    if not _allow then  -- put to spectators
                        net.force_player_slot(playerID, 0, '')
                    end

                end
                
            elseif eventName == "takeoff" then
            
                -- is player in a slot and valid?
                _playerDetails = net.get_player_info(playerID)

                if _playerDetails ~=nil and _playerDetails.side ~= 0 and _playerDetails.slot ~= "" and _playerDetails.slot ~= nil then

                    _allow = agcST.agcCheck(playerID, _playerDetails.slot, 1)

                    if not _allow then
                        local _playerName = _playerDetails.name

                        local _time = math.floor(os.time())
                        local _timeout = agcST.getFlagValue("AGC_DisableTimeout")
                        agcST.disabledPlayerTimeleft[_playerName:gsub('%W','')] = _time + _timeout
                        agcST.disabledPlayer(playerID, _timeout)
                    end

                end
            
            end
        end
    end
end

agcST.onPlayerTryChangeSlot = function(playerID, side, slotID)


        if  (side ~=0 and  slotID ~='' and slotID ~= nil)  then

                local _playerDetails = net.get_player_info(playerID)

                if _playerDetails == nil then
                    return true
                end
                
                local _playerName = _playerDetails.name
                
                if agcST.disabledPlayerTimeleft[_playerName:gsub('%W','')] then
                    local _time = math.floor(os.time())
                    if agcST.disabledPlayerTimeleft[_playerName:gsub('%W','')] > _time then
                        agcST.disabledPlayer(playerID, agcST.disabledPlayerTimeleft[_playerName:gsub('%W','')] - _time)
                        return false
                    end
                end
        end

        net.log("allowing -  playerid: "..playerID.." side:"..side.." slot: "..slotID)


    return true

end


agcST.disabledPlayer = function(playerID, timeLeft)

    -- put to spectators
    net.force_player_slot(playerID, 0, '')

    local _playerName = net.get_player_info(playerID, 'name')

    if _playerName ~= nil then
        local _chatMessage = string.format("【 %s - 你因违反服务器规定，现已被停飞。请 %i 秒后再试！】",_playerName,timeLeft)
        net.send_chat_to(_chatMessage, playerID)
    end
end



DCS.setUserCallbacks(agcST)