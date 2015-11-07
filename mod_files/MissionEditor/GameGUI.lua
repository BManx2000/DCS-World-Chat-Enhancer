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

onShowRadioMenu(size) --���������� ��� ��������� �������� ����� ����
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

setmetatable(dxgui, {__index = dxguiWin})

Gui.SetupApplicationUpdateCallback()
Gui.AddFontSearchPathes({'dxgui/skins/fonts/', tostring(os.getenv('windir')) .. '/Fonts/'})

-- ������ ������� ����� ���������� �� ������ ����� ��������� GUI.
Gui.SetUpdateCallback(UpdateManager.update)

countCoalitions = 0

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
print("------- onShowRadioMenu------",a_h)
    gameMessages.setOffsetLentaTrigger(a_h)
end

function onSimulationStart()
    print("------- onSimulationStart------",DCS.getPause(),DCS.isMultiplayer(),DCS.isTrackPlaying())
    
    gameMessages.show()
    if (DCS.isMultiplayer() == true) then
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

function onGameEvent(eventName,arg1,arg2,arg3,arg4) 
    print("---onGameEvent(eventName)-----",eventName,arg1,arg2,arg3,arg4) 
    Chat.onGameEvent(eventName,arg1,arg2,arg3,arg4) 
end

function onShowPool()
print("---onShowPool()----")
    if PlayersPool.isVisible() ~= true then
        PlayersPool.show(true)
    else
        PlayersPool.show(false)
    end
end

function onSimulationEsc()
    if (DCS.isMultiplayer() == true) and (DCS.isTrackPlaying() == false) then
        if Select_role.getVisible() == false then
            Select_role.show(true)
			DCS.setViewPause(true)
        else
            Select_role.show(false)
			DCS.setViewPause(false)
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
print("----onShowChatAll()----",DCS.isMultiplayer()) 
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
    if (DCS.isMultiplayer() == true) then    
        Chat.show(true)
    else
        Chat.show(false)
    end    
end

function onShowChatRead()
print("----onShowChatRead()----",DCS.isMultiplayer())     
    if (DCS.isMultiplayer() == true) then
		if (Chat.getMode() ~= Chat.mode.write) and not Chat.chatJustClosed() then
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

function onShowChatPanel()
    print("----onShowChatPanel()----")
    Chat.setHideMail(false)
end

function onHideChatPanel()
    print("----onHideChatPanel()----")
    Chat.setHideMail(true)
end

function onSimulationPause()
    print("----onSimulationPause---")
    gameMessages.showPause()
end

function onSimulationStop()
    Chat.show(false)
    print("----onSimulationStop---")
end

function onNetDisconnect(reason)
print("----onNetDisconnect---",reason)
    net.stop_network()   
    Chat.show(false)
    PlayersPool.show(false)
    Select_role.show(false)
 --   MsgWindow.warning(reason, _("Disconnect"), _("ok")):show()
    onShowMainInterface()
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
    BriefingDialog.showUnpauseMessage(false)
    BriefingDialog.show()    
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

function onChatMessage(message, from)
    Chat.onChatMessage(message, from)
end

--- player list callbacks
function onPlayerConnect(id, name)
  --  print("---onPlayerConnect--",id, name)
    Select_role.onPlayerConnect(id)
    PlayersPool.onPlayerConnect(id)
end

function onPlayerDisconnect(id)
    print("----onPlayerDisconnect---", id)
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
    print("----onPlayerChangeSlot---", id)
    Select_role.onPlayerChangeSlot(id)
    PlayersPool.onPlayerChangeSlot(id)
end

-- ������ ������� ����� ���������� �� ������ ����� ��������� GUI.
Gui.SetUpdateCallback(UpdateManager.update)

--------------------------------------------------------------------------------------------------------

-- ���������� ������� ��� ������������ ������� �� �����
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


--------------------------------------------------------------------------------------------------------
-- load a user-provided script

local userScript = lfs.writedir() .. 'Scripts/userGameGUI.lua'
if lfs.attributes(userScript, 'mode') == 'file' then
    dofile(userScript)
end
