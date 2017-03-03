local agcST = {} 

-- 
-- AGC_MP 服务器可选飞机管理工具
-- AGC_MP Slot Blocking Tools
--
-- Version 1.5
--
-- Change logs:
--     1. 修改了管理员命令，增加-id命令以查看玩家playerID。
--
-- By Dennic - https://github.com/Dennic/DCS-Script-AGC_MP
--

agcST.disabledPlayerTimeleft = {}
agcST.playerIDList = {}
agcST.Admins = {"Server Admin", "小恐龙Dennic", }

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
            return false
        end
      
    elseif _mode == 2 then
        _flag = agcST.getFlagValue("AGC_DontEject".._playerName:gsub('%W',''))
        
        if _flag == 1 then
            return false
        end
        
    elseif _mode == 3 then
        _flag = agcST.getFlagValue("AGC_DontLand".._playerName:gsub('%W',''))
        
        if _flag == 1 then
            return false
        end
        
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
                
            elseif eventName == "takeoff" or eventName == "landing" then
            
                -- is player in a slot and valid?
                _playerDetails = net.get_player_info(playerID)

                if _playerDetails ~=nil and _playerDetails.side ~= 0 and _playerDetails.slot ~= "" and _playerDetails.slot ~= nil then
                    
                    if eventName == "takeoff" then
                        _allow = agcST.agcCheck(playerID, _playerDetails.slot, 1)
                    elseif eventName == "landing" then
                        _allow = agcST.agcCheck(playerID, _playerDetails.slot, 3)
                    end

                    if not _allow then
                        local _playerName = _playerDetails.name

                        local _time = math.floor(os.time())
                        local _timeout = agcST.getFlagValue("AGC_DisableTimeout")
                        agcST.disabledPlayerTimeleft[_playerName] = _time + _timeout
                        agcST.disabledPlayer(playerID, _timeout, true)
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
                
                if agcST.disabledPlayerTimeleft[_playerName] then
                    local _time = math.floor(os.time())
                    if agcST.disabledPlayerTimeleft[_playerName] > _time then
                        agcST.disabledPlayer(playerID, agcST.disabledPlayerTimeleft[_playerName] - _time, false)
                        return false
                    end
                end
                
				
				agcST.playerIDList[_playerName] = playerID
				net.log("Add to playerIDList: ".._playerName.." -- "..playerID)
        end

        net.log("allowing -  playerid: "..playerID.." side:"..side.." slot: "..slotID)


    return true

end

agcST.onPlayerTrySendChat = function(playerID, msg, all)

 --   if  DCS.isServer() and DCS.isMultiplayer() then

        local _name = net.get_player_info(playerID, 'name')

        if _name ~= nil then

			if agcST.checkInTable(agcST.Admins, _name) then
			
				local _cmd = agcST.trimStr(msg)
			
				local _chatMessage = ""
            
                if _cmd:sub(1,4) == "-ban" and string.len(_cmd) >= 6 then
                
                    if tonumber(_cmd:sub(6,-1)) == nil then
                        net.send_chat_to("命令输入错误 请输入：-ban [playerID]", playerID)
                        return msg
                    end
                    
                    for _playerName, _playerID in pairs(agcST.playerIDList) do
                        if _playerID == tonumber(_cmd:sub(6,-1)) then
                        
                            local _time = math.floor(os.time())
                            local _timeout = agcST.getFlagValue("AGC_DisableTimeout")
                            agcST.disabledPlayerTimeleft[_playerName] = _time + _timeout
                            agcST.disabledPlayer(_playerID, _timeout, true)
                            _chatMessage = string.format("玩家【%s】被管理员停飞 %i 秒。", _playerName, _timeout)
                            net.send_chat(_chatMessage, 0, 0)
                            
                            break
                        end
                    end
                
            
                elseif _cmd:sub(1,5) == "-kick" and string.len(_cmd) >= 7 then
				
                    if tonumber(_cmd:sub(7,-1)) == nil then
                        net.send_chat_to("命令输入错误 请输入：-kick [playerID]", playerID)
                        return msg
                    end
                    
                    for _playerName, _playerID in pairs(agcST.playerIDList) do
                        if _playerID == tonumber(_cmd:sub(7,-1)) then
                        
                            net.force_player_slot(_playerID, 0, '')
                            _chatMessage = string.format("玩家【%s】被管理员踢回到观众席。",_playerName)
                            net.send_chat(_chatMessage, 0, 0)
                            
                            break
                        end
                    end
            
                elseif _cmd:sub(1,3) == "-id" and string.len(_cmd) >= 5 then
                
                    local _check = _cmd:sub(5,-1)
                    local _result = 0
                    local _msg = ""
                    
                    for _playerName, _playerID in pairs(agcST.playerIDList) do
                        if string.find(_playerName, _check) ~= nil then
                            _result = _result + 1
                            _msg = _msg .. string.format("【%d -- %s】 ", _playerID, _playerName)
                        end
                    end
                    
                    _chatMessage = string.format("找到 %d 个玩家：%s", _result, _msg)
                    
                    net.send_chat_to(_chatMessage, playerID)
                    
                end
            
            end
			
        else
            net.log("playername null")
        end

    return msg
end

agcST.trimStr = function(_str)

    return  string.format( "%s", _str:match( "^%s*(.-)%s*$" ) )
end

function agcST.checkInTable(_tb, _vl)
		for _i,_v in pairs(_tb) do
			if _v == _vl then
				return true
			end
		end
	return false
end

function agcST.chatmsg_net(text)
	local clientindex = 0
	while clientindex <= 128 do
		net.send_chat(text, clientindex, clientindex)				
		clientindex = clientindex + 1
	end
end


agcST.disabledPlayer = function(playerID, timeLeft, _toSpectators)

    if _toSpectators then
        -- put to spectators
        net.force_player_slot(playerID, 0, '')
    end
        
    local _playerName = net.get_player_info(playerID, 'name')

    if _playerName ~= nil then
        local _chatMessage = string.format("【 %s - 你因违反服务器规定，现已被停飞。请 %i 秒后再试！】",_playerName,timeLeft)
        net.send_chat_to(_chatMessage, playerID)
    end
end


DCS.setUserCallbacks(agcST)