-- available APIs:
--[[
DCS.setPause(bool)
DCS.getPause() -> bool
--DCS.startMission(string filename) -- NOT IMPLEMENTED YET
DCS.stopMission()
DCS.exitProcess()

DCS.isMultiplayer() -> bool
DCS.isServer() -> bool
DCS.isTrackPlaying() -> bool
DCS.takeTrackControl()

DCS.getModelTime() -> number
DCS.getRealTime() -> number


DCS.setMouseCapture(bool)
DCS.setKeyboardCapture(bool)

DCS.getManualPath() -> string

DCS.getMissionOptions() -> table
DCS.getMissionDescription() -> string
DCS.getPlayerCoalition() -> string
DCS.getPlayerUnitType() -> string
DCS.getPlayerBriefing() -> table { text = string, images = { array of strings } }

DCS.spawnPlayer()

DCS.hasMultipleSlots() -> boolean
DCS.getAvailableCoalitions() -> table {
 [coalition_id] = { name = "coalition name", hasPassword = <bool> }
 ...
}
DCS.getAvailableSlots() -> array of {unitId, type, role, callsign, groupName, country}


--FIXME: these are temporary, for single-player only
DCS.getPlayerUnit() -> string

DCS.setPlayerCoalition(coalition_id)
DCS.setPlayerUnit(misId) -> sets the unit and spawns the player

]]

-- functions called by the sim
--[[
onMissionLoadBegin()
onMissionLoadProgress(progress_0_1, message)
onMissionLoadEnd()

onTriggerMessage(message, duration)
onRadioMessage(message, duration)
onRadioCommand(command_message)

onSimulationStart()
onSimulationFrame()
onSimulationStop()
onSimulationPause()
onSimulationResume()

onShowMainInterface()
onShowGameMenu()
onShowBriefing()
onShowChatAll()
onShowChatTeam()
onShowScores()
onShowResources()
onShowMessage(text, type)  
onShowChatPanel()
onHideChatPanel()
onGameEvent(eventName, args...)
onPlayerDisconnect(id)
onPlayerStart(id)
onPlayerConnect(id, name)

onShowRadioMenu(size) --вызывается при изменении размеров радио меню
]]

package.path = '.\\Scripts\\?.lua;'.. '.\\Scripts\\UI\\?.lua;'

local progressBar = require('ProgressBarDialog')
local GameMenu = require('GameMenu')
local ChoiceOfRoleDialog = require('ChoiceOfRoleDialog')
local ChoiceOfCoalitionDialog = require('ChoiceOfCoalitionDialog')
local gameMessages = require('gameMessages')
local UpdateManager = require('UpdateManager')
local Gui = require('dxgui')
local GuiWin = require('dxguiWin')
local Select_role		= require('mul_select_role')
local Chat		= require('mul_chat')
local PlayersPool       = require('mul_playersPool')
local net               = require('net')
local MsgWindow			        = require('MsgWindow')
local RPC = require('RPC')
local i18n 				= require('i18n')
local query 				= require('mul_query')
local wait_query        = require('mul_wait_query')
local MeSettings				= require('MeSettings')
local wait_screen     = require('me_wait_screen')
local OptionsDialog				= require('me_options')
local Censorship        = require('censorship')


controlRequest = require('mul_controlRequest')

local _ = i18n.ptranslate

setmetatable(dxgui, {__index = dxguiWin})


Gui.SetupApplicationUpdateCallback()
require('GuiFontInitializer')

-- Данная функция будет вызываться на каждом кадре отрисовки GUI.
Gui.SetUpdateCallback(UpdateManager.update)

countCoalitions = 0
isDisconnect = false
msgDisconnect = nil
codeDisconnect = nil

function onMissionLoadBegin()
    progressBar.show()
end

function onMissionLoadProgress(progress, message)
    progressBar.setValue(progress)
    if message then
        progressBar.setText(message)
    end
end

function onMissionLoadEnd()
    progressBar.kill()
end

function onShowRadioMenu(a_h)
--print("------- onShowRadioMenu------",a_h)
    gameMessages.setOffsetLentaTrigger(a_h)
end


function RPC.method.onCustomEvent(sender_id, eventName, player_id)
    --print("---RPC.method.onCustomEvent----",sender_id, eventName, player_id,arg2,arg3)
    Chat.onGameEvent(eventName,player_id) 
end

function RPC.method.onPrtScn(sender_id, ...)
    --print("---RPC.method.onPrtScn----",sender_id, arg1,arg2,arg3)
    RPC.method.onCustomEvent(sender_id, "screenshot", sender_id) -- locally
    RPC.sendEvent(0, "onCustomEvent", "screenshot", sender_id) -- to everybody else
end

--запрос на слот
function RPC.method.slotWanted(server_id, player_id, slot_id) 
    if DCS.isTrackPlaying() == true then
        return
    end
print("------- RPC.method.slotWanted------",server_id, player_id, slot_id)
    query.slotWanted(server_id, player_id, slot_id)
end

function RPC.method.slotGiven(playerMaster_id, player_id, side, slot_id)
    if DCS.isTrackPlaying() == true then
        return
    end
    print("------- RPC.method.slotGiven------",playerMaster_id, player_id, side, slot_id)
    if Select_role.isEnablePlayerTryChangeSlot(player_id,playerMaster_id) then
        print("-------force_player_slot---",player_id, side, slot_id)
        net.force_player_slot(player_id, side, slot_id)
    end
end


function RPC.method.slotDenial(playerMaster_id, player_id)
    if DCS.isTrackPlaying() == true then
        return
    end
    print("------- RPC.method.slotDenial------",playerMaster_id, player_id)
    Select_role.slotDenial(player_id)
end

function RPC.method.slotDenialToPlayer()
    if DCS.isTrackPlaying() == true then
        return
    end
    print("------- RPC.method.slotDenialToPlayer------")    
    wait_query.slotDenialToPlayer()
end

function RPC.method.releaseSeat(player_id)
    if DCS.isTrackPlaying() == true then
        return
    end
    print("------- RPC.method.releaseSeat------", player_id)    
    Select_role.releaseSeat(player_id)
end

function RPC.method.releaseSeatToMaster(playerMaster_id, player_id)
    if DCS.isTrackPlaying() == true then
        return
    end
    print("------- RPC.method.releaseSeatToMaster------", playerMaster_id, player_id)  
    query.releaseSeatToMaster(player_id) 
end

function onPlayerTryChangeSlot(player_id, side, slot_id)
    print("---onPlayerTryChangeSlot-----",player_id, side, slot_id)
    return Select_role.onPlayerTryChangeSlot(player_id, side, slot_id)
end

function onChatShowHide()
    print("---onChatShowHide-----",DCS.isMultiplayer())
    if (DCS.isMultiplayer() == true) then
        Chat.onChatShowHide()
    end
end

-- used in onSimulationStart, onSimulationStop and onGameEvent
local _serverSettings = nil

function onSimulationStart()
    print("------- onSimulationStart------",DCS.getPause(),DCS.isMultiplayer(),DCS.isTrackPlaying())

    wait_screen.showSplash(false)
    gameMessages.show()
    if (DCS.isMultiplayer() == true) then
		isDisconnect = false
		msgDisconnect = nil
		codeDisconnect = nil
	_serverSettings = net.get_server_settings()
        Select_role.onSimulationStart() 
        if not _OLD_NET_GUI and DCS.isTrackPlaying() == false then
            Select_role.show(true)
        end 

        if DCS.getPause() == true then
            gameMessages.showPause()
        else
            gameMessages.hidePause()
        end        
        Chat.updateSlots()  
        PlayersPool.updateSlots()  
        query.onChange_bDenyAll()
        print("----onSimulationStart--releaseSeat---")
        RPC.sendEvent(net.get_server_id(), "releaseSeat", net.get_my_player_id())
        
        if DCS.isTrackPlaying() == false then
            local opt = DCS.getUserOptions()
            if opt and opt.miscellaneous.chat_window_at_start ~= false then  
                Chat.setMode(Chat.mode.read)
                Chat.show(true)
            end
        else
            BriefingDialog.showUnpauseMessage(true)
            BriefingDialog.show()
        end    
        return
    end
	
    countCoalitions = 0
    Coalitions = DCS.getAvailableCoalitions()
    ChoiceOfCoalitionDialog.setAvailableCoalitions(Coalitions)
    CoalitionLast = nil
    
    for k,v in pairs(Coalitions) do
        countCoalitions = countCoalitions + 1
        CoalitionLast = k
    end
   -- print("------------onSimulationStart====",#(DCS.getAvailableCoalitions()),countCoalitions)
    
    if DCS.getPause() == true then
        if DCS.hasMultipleSlots() == false or DCS.isTrackPlaying() == true then
            BriefingDialog.showUnpauseMessage(true)
            BriefingDialog.show()
        elseif countCoalitions == 1 then
            ChoiceOfRoleDialog.show(CoalitionLast, true, "Menu")
        else
            ChoiceOfCoalitionDialog.show()
        end 
    end
   
    GameMenu.setCountCoalitions(countCoalitions)
end

function onSimulationFrame()
    gameMessages.updateAnimations()
end 


local event2setting = {
    ['crash'] = 'event_Crash',
    ['eject'] = 'event_Ejecting',
    ['takeoff'] = 'event_Takeoff',
    ['landing'] = 'event_Takeoff',
    ['kill'] = 'event_Kill',
    ['self_kill'] = 'event_Kill',
    ['pilot_death'] = 'event_Kill',
    ['change_slot'] = 'event_Role',
    ['connect'] = 'event_Connect',
    ['disconnect'] = 'event_Connect',
    ['friendly_fire'] = nil,
    ['screenshot'] = nil,
}

-- events are filtered on the server only, because on clients they are filtered by the C++ code.
local function show_event(eventName)
    if _serverSettings then
        local settingName = event2setting[eventName]
        if settingName then
            return _serverSettings.advanced[settingName]
        end
    end
    return true
end

function onGameEvent(eventName,arg1,arg2,arg3,arg4,arg5,arg6,arg7) 
    --print("---onGameEvent(eventName)-----",eventName,arg1,arg2,arg3,arg4,arg5,arg6,arg7)
    if show_event(eventName) then
        Chat.onGameEvent(eventName,arg1,arg2,arg3,arg4,arg5,arg6,arg7) 
    end
end

function onShowPool()
--print("---onShowPool()----")
    if PlayersPool.isVisible() ~= true then
        if Select_role.getVisible() == true then 
            PlayersPool.show(true)
        else
            PlayersPool.show(true)
        end    
    else
        PlayersPool.show(false)
    end
end

function onSimulationEsc()
    if (DCS.isMultiplayer() == true) and (DCS.isTrackPlaying() == false) then
        if Select_role.getVisible() == true then            
            Select_role.onEsc()			
        else
            if GameMenu.getVisible() == true then
                GameMenu.hide()  
                DCS.setViewPause(false)    
            else
                GameMenu.show()
                DCS.setViewPause(true)
            end    
        end
		
        return
    end
    
    if GameMenu.getVisible() == true then
        GameMenu.hide()  
        gameMessages.hidePause() 
        DCS.setPause(false)    
    elseif BriefingDialog.getVisible() == true then
        BriefingDialog.hide()
        gameMessages.hidePause() 
        DCS.setPause(false) 
    elseif ChoiceOfRoleDialog.getVisible() == true then
        ChoiceOfRoleDialog.hide()
    elseif ChoiceOfCoalitionDialog.getVisible() == true then
        ChoiceOfCoalitionDialog.hide()  
    elseif OptionsDialog.getVisible() == true then
        OptionsDialog.onCancel()
    else
        GameMenu.show()
        gameMessages.showPause()
    end    
    
 --   ggg = ggg or 10
 --   ggg = ggg + 1
 --   onShowMessage("dfgdf fdg dg"..ggg, math.random(10000,20000), {r=math.random(0,1),g=math.random(0,1),b=math.random(0,1)}  ) 
end

function onShowMessage(a_text, a_duration)
    gameMessages.addMessage(a_text, a_duration) 
end

function onShowChatAll()
--print("----onShowChatAll()----",DCS.isMultiplayer()) 
    if (DCS.isMultiplayer() == true) then  
		Chat.setAll(false)
		Chat.setMode(Chat.mode.write)
        Chat.show(true)
    else
        Chat.show(false)
    end
end

function onShowChatTeam()
print("----onShowChatTeam()----",DCS.isMultiplayer())
	onShowChatAll()
end

function onShowChatRead()
print("----onShowChatRead()----",DCS.isMultiplayer())
    if (DCS.isMultiplayer() == true) then
		if (Chat.getMode() ~= Chat.mode.write) then
			Chat.setAll(true)
			Chat.setMode(Chat.mode.write)
		elseif Chat.getAll() == false then
			Chat.setAll(true)
		elseif Chat.chatTimerActive() then
			Chat.setMode(Chat.mode.read)
		else
			Chat.setMode(Chat.mode.min)    
		end
        Chat.show(true)
    else
        Chat.show(false)
    end    
end

function onSimulationPause()
    print("----onSimulationPause---")
    if DCS.isTrackPlaying() == false then
        gameMessages.showPause()
    end    
end

function onSimulationStop()
    Chat.show(false)
    controlRequest.show(false)
    gameMessages.hide()
    _serverSettings = nil
    print("----onSimulationStop---",isDisconnect,msgDisconnect,codeDisconnect)
	
	if isDisconnect == true then
		onShowMainInterface()
		
		if codeDisconnect ~= net.ERR_THATS_OKAY then
		--	MsgWindow.warning(msgDisconnect, _("DISCONNECT"), _("OK")):show()
end
	end
end

function onNetDisconnect(reason, code)
print("----onNetDisconnect---",reason, code)    
    local msg = Chat.getMsgByCode(code)

    if reason and (code == nil or code ~= net.ERR_INVALID_PASSWORD) then
        msg = msg.."\n\n".._(reason)
    end    
 
    wait_screen.showSplash(false)
    net.stop_network()   
    Chat.show(false)
    PlayersPool.show(false)
    Select_role.show(false)
    query.show(false)
    wait_query.show(false)
    
	isDisconnect = true  
	msgDisconnect = msg	
	codeDisconnect = code
    end

function onSimulationResume()
    print("----onSimulationResume---")
    gameMessages.hidePause()
    
    if BriefingDialog.getVisible() == true then
        BriefingDialog.hide()
    end
end

if not onShowMainInterface then
    onShowMainInterface = function() end
end

function onShowGameMenu()
  --  GameMenu.show()
    onSimulationEsc()
end

function onShowBriefing()
    if BriefingDialog.getVisible() == false then
        BriefingDialog.showUnpauseMessage(false)
        BriefingDialog.show()   
    else
        BriefingDialog.Fly_onChange()
    end    
end

function onShowChat(say_all)
end

function onShowScores()
end

function onShowResources()
end

-- shows a trigger-induced message for a specified duration (in modeltime seconds)
function onTriggerMessage(message, duration, clearView)
--print("---onTriggerMessage---",message, duration, clearView)
    gameMessages.addTriggerMessage(message, duration*1000, clearView)
end

-- shows a player-activated radio message for a specified duration (in modeltime seconds)
function onRadioMessage(message, duration)
--print("---onRadioMessage---",message, duration)
    gameMessages.addRadioMessage(message, duration*1000)
end

-- shows an 'automatic' radio command, until replaced by another or an empty one
function onRadioCommand(command_message)
--print("---onRadioCommand---",command_message)
    gameMessages.onRadioCommand(command_message)
end


function onPlayerTrySendChat(playerID, msg, all) -- -> filteredMessage | "" - empty string drops the message
   -- print("---onPlayerTrySendChat----",playerID, msg, all)
    msg = Censorship.censor(msg)
    return msg
end

function onChatMessage(message, from)
--print("--GUI-onChatMessage----",message, from)
    Chat.onChatMessage(message, from)  
end

--- player list callbacks
function onPlayerConnect(id, name)
  --  print("---onPlayerConnect--",id, name)
    Select_role.onPlayerConnect(id)
    PlayersPool.onPlayerConnect(id)    
end

function onPlayerDisconnect(id, code)
    print("----onPlayerDisconnect---", id, code)
    
    query.onChange_bDenyAll()
    RPC.sendEvent(net.get_server_id(), "releaseSeat", id)
        
    Select_role.onPlayerDisconnect(id)
    PlayersPool.onPlayerDisconnect(id)     
end

function onPlayerStart(id)
   -- local name = net.get_player_info(id, 'name')
   -- print('Player '..name..' entered the game.')
end

function onPlayerStop(id)
end

function onPlayerChangeSlot(id)
    --print("----onPlayerChangeSlot---", id)
    Select_role.onPlayerChangeSlot(id)
    PlayersPool.onPlayerChangeSlot(id)
    wait_query.onPlayerChangeSlot(id)
end

function onUpdateScore()
    PlayersPool.updateGrid()
end


-- Данная функция будет вызываться на каждом кадре отрисовки GUI.
Gui.SetUpdateCallback(UpdateManager.update)

--------------------------------------------------------------------------------------------------------

-- отладочная функция для сериализации таблицы на экран
function traverseTable(_t, _numLevels, _tabString, filename, filter)
    local _tablesList = {}
    filter = filter or {}
    fun = print
    if ( filename and (filename ~= '') ) then
        local out = io.open(filename, 'w')
        fun = function (...)
            out:write(..., '\n')
        end
    end
    function _traverseTable(t, tabString, tablesList, numLevels, filter)
        if (numLevels <1) then 
            return
        end

      for k,v in pairs(t or {} ) do      
            if type(k) == "number" then
                k = '[' .. tostring(k) .. ']'
            end
        if type(v) == "table" then 
            local skip = false
            for i,ignoredField in ipairs(filter) do
                if ignoredField == k then
                    skip = true
                    break
                end
            end
            if skip == false then
                local str = string.gsub(tostring(v), 'table: ','')
                if not tablesList[v] then
                    tablesList[v] = tostring(k)
                    fun(tabString  .. tostring(k) .. "--[[" .. str .. "--]]  = {")
                    --numLevels = numLevels - 1
                    _traverseTable(v, tabString .. '    ', tablesList, numLevels - 1, filter)
                    fun(tabString .. "}")
                else 
                    fun(tabString .. k .. " = -> " .. (tostring(tablesList[v])  or '') .. "--[[" .. str .. "--]],")
                end
            end
        elseif type(v) == "function" then
          fun(tabString .. k .. " = " .. "function() {},")
        elseif type(v) == "string" then
          fun(tabString .. k .. " = '" .. v .. "'")
        else
          fun(tabString .. k .. " = " .. tostring(v) or '' .. ",")
        end
      end        
    end 

    if not _t then 
        fun('traverseTable(): nil value')
        return
    end
    
    if 'table' ~= type(_t) then 
        fun('traverseTable(): not a table', tostring(_t)  or '')
        return
    end
    fun('displaying table:', (tostring(_t) or ''), tostring(_numLevels) or '')
    
    if _numLevels == nil then 
        _numLevels  = math.huge
    end
    
    if (_numLevels <1) then 
        return
    end
    
    if _tabString == nil then
        _tabString = ""
    end
    
    if not _tablesList then 
        _tablesList = {}
    end 
    --fun('_numLevels',_numLevels)
    for k,v in ipairs(filter) do
        print(k,v)
    end
    _traverseTable(_t, _tabString, _tablesList, _numLevels, filter)
    
end

function getPermissionToCollectStatistics()
    return MeSettings.getPermissionToCollectStatistics()
end 

--------------------------------------------------------------------------------------------------------
-- load a user-provided script
local userCallbackList = {
    'onMissionLoadBegin',
    'onMissionLoadProgress',
    'onMissionLoadEnd',
    'onSimulationStart',
    'onSimulationStop',
    'onSimulationFrame',
    'onSimulationPause',
    'onSimulationResume',
    'onGameEvent',
    'onNetConnect',
    'onNetMissionChanged',
    'onNetDisconnect',
    'onPlayerConnect',
    'onPlayerDisconnect',
    'onPlayerStart',
    'onPlayerStop',
    'onPlayerChangeSlot',
    'onPlayerTryConnect',
    'onPlayerTrySendChat',
    'onPlayerTryChangeSlot',
    'onChatMessage',
    'onShowRadioMenu',
    'onShowPool',
    'onShowGameMenu',
    'onShowBriefing',
    'onShowChatAll',
    'onShowChatTeam',
    'onShowChatRead',
    'onShowMessage',
    'onTriggerMessage',
    'onRadioMessage',
    'onRadioCommand',
}

local function list2map(cbList)
    local map = {}
	for i,v in ipairs(cbList) do
	    map[v] = true
	end
	return map
end

local userCallbackMap = list2map(userCallbackList)
local userCallbacks = {} -- array of cb_tables

local function isValidCallback(name, cb)
    return userCallbackMap[name]==true and type(cb) == 'function'
end

local function filterUserCallbacks(cb_table)
    local filtered = {}
    local ok = false
    for name,func in pairs(cb_table) do
        if isValidCallback(name, func) then
            print('    Hooked ' .. name)
            filtered[name] = func
            ok = true
        else
            print('    Rejected ' .. name)
        end
    end
    return ok, filtered
end

function DCS.setUserCallbacks(cb_table)
    local ok, cb = filterUserCallbacks(cb_table)
    -- in theory we could just do 'if #cb > 0' but it does not work this way in 5.1
    if ok then
        table.insert(userCallbacks, cb)
    end
end

function DCS.reloadUserScripts()
    local userScriptDir = lfs.writedir() .. 'Scripts'
    local userScripts = {}
    for fn in lfs.dir(userScriptDir) do
        if string.find(fn, '.*GameGUI%.lua') then
            table.insert(userScripts, fn)
        end
    end
    table.sort(userScripts)

    -- clear all current callbacks
    userCallbacks = {}

    -- actually load the stuff
    for i,fn in ipairs(userScripts) do
        local env = {}
        setmetatable(env, { __index = _G })
        local u, err = loadfile(userScriptDir .. '/' .. fn)
        if u then
            setfenv(u, env)
            local ok, err = pcall(u)
            if ok then
                print('Loaded user script '..fn)
            else
                print('Failed to exec user script '..fn..': '..err)
            end
        else
            print('Failed to load user script '..fn..': '..err)
        end
    end
end

local function callbackHook(name, dcsHandler, ...)
    for i = #userCallbacks, 1, -1 do -- call last-to-first
        local cb = userCallbacks[i]
        local h = cb[name]
        if h then
            local ok, res = pcall(h, ...)
            if not ok then
                print(name, res) -- error
            elseif res ~= nil then
                return res -- callback returned a result
            end -- if not ok
        end -- if h
    end -- for i, cb
    if dcsHandler then return dcsHandler(...) end
end


-- call only ONCE
local function hookTheCallbacks()
    for name, t in pairs(userCallbackMap) do
        local dcsHandler = _G[name]
        local hook = function(...) return callbackHook(name, dcsHandler, ...) end
        _G[name] = hook
    end
end

--- END of user callback stuff
---------------------------------------------------------------------------------------

local classifier

if not me_db then
	OptionsData = require('Options.Data')
	OptionsData.load({})

	me_db = require('me_db_api')
	me_db.create() -- чтение и обработка БД редактора

	-- база данных по плагинам загружается в me_db_api
	-- после ее загрузки можно загрузить настройки для плагинов
	OptionsData.loadPluginsDb()
end

function getUnitIconByType(a_type)
    local iconName
    local rotatable
	local mainPath = mainPath or 'MissionEditor/'
    
    if classifier == nil then
        local filename = mainPath .. 'data/NewMap/Classifier.lua'
        local func, err = loadfile(filename)
        
        if func then
            local imagesPath = mainPath .. 'data/NewMap/images/themes/' .. OptionsData.getIconsTheme() .. '/' 	
            classifier = func(imagesPath,i18n.ptranslate)
        end
    end

    if classifier and classifier.objects then
        local classKey = me_db.getClassKeyByType(a_type)
        --print('a_type, ClassKey:', a_type, classKey)
        if classKey then
            local classInfo = classifier.objects[classKey]
            if classInfo then
                rotatable = classInfo.rotatable or false
                iconName = classInfo.file
            end
        end
    end
  
    return iconName, rotatable
end

---- Insert your stuff ABOVE this line.
-- These should be the last 2 lines:
hookTheCallbacks()
DCS.reloadUserScripts()
