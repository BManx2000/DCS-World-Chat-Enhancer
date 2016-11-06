dofile('./Scripts/UI/initGUI.lua')

local base = _G

module('gameMessages')

local require = base.require
local pairs = base.pairs
local ipairs = base.ipairs
local print = base.print
local table = base.table
local string = base.string
local tonumber = base.tonumber
local tostring = base.tostring
local assert = base.assert
local type = base.type
local math = base.math
local os = base.os
local HMD = base.HMD

local Gui               = require('dxgui')
local GuiWin            = require('dxguiWin')
local DialogLoader      = require('DialogLoader')
local WidgetParams      = require('WidgetParams')
local gettext           = require('i_18n')
local DCS               = require('DCS')
local Static            = require('Static')
local Skin              = require('Skin')
local SkinUtils		    = require('SkinUtils')
local Color		        = require('Color')
local Lenta	            = require('lentaMessages')

base.setmetatable(base.dxgui, {__index = base.dxguiWin})

local listMessages = {}
local timeShow = 30000
local timeAnim = 5000

local timeAnimPause = 0
local timeStartAnimPause = 0

local ListCreatedWidgets = {}

local function _(text) 
    if text == nil then
        return ""
    end
    return gettext.translate(text) 
end

function create()
    local localization = {
	}

	window = DialogLoader.spawnDialogFromFile('Scripts/UI/gameMessages.dlg', localization)
    main_w, main_h = Gui.GetWindowSize()
    window:setBounds(0,0, main_w, main_h)  
    
    sPause = window.sPause
    
    sPause:setPosition(main_w-76,9)
    
    pLentaTrigger = Lenta.new(window.pLentaTrig)
    pLentaRadio = Lenta.new(window.pLentaRadio) 
    
    sMain = window.sMain
    sRadioAuto = window.sRadioAuto
        
   -- pLentaTrigger:setBounds(main_w - (2 * main_w/3)+20,20, main_w/3, main_h/4)
    pLentaTrigger:setBounds(main_w - (889)-20,20, 889, main_h/2)
    pLentaTrigger:setSeparator(true)
    pLentaRadio:setBounds(0,20, main_w*0.8, main_h/2)
    
    sPause:setVisible(false)
    onRadioCommand("")
end

function setOffsetLentaTrigger(a_h)
    if pLentaTrigger then
        pLentaTrigger:setBounds(main_w - 909,20+a_h, 889, main_h/2)
    end
end

function show()
--base.print("----gameMessages---show()")

    if not window then
		 create()
	end
    
    if HMD.isActive() == true then
        pLentaTrigger:updateSkins(window.pLentaTrig_High)
        pLentaRadio:updateSkins(window.pLentaRadio_High)
      
        window.sRadioAuto:setVisible(false)
        sRadioAuto = window.sRadioAuto_High
        window.sMain:setVisible(false)
        sMain = window.sMain_High
    else
        pLentaTrigger:updateSkins(window.pLentaTrig)
        pLentaRadio:updateSkins(window.pLentaRadio)
        
        window.sMain_High:setVisible(false)
        sMain = window.sMain
        window.sRadioAuto_High:setVisible(false)    
        sRadioAuto = window.sRadioAuto
    end
    
    clear()       
    
    window:setVisible(true)
end

function clear()
    pLentaTrigger:clear()
    pLentaRadio:clear()
    sRadioAuto:setText("")
    sRadioAuto:setVisible(false)
    sMain:setVisible(false)
    
    if pLentaTrigger then
        pLentaTrigger:setBounds(main_w - 909,20, 889, main_h/2) --возвращаем назад для новой миссии
    end
end

function hide()
    if window then
        window:setVisible(false)
    end
end


function addTriggerMessage(a_text, a_duration, a_clearView)
    if a_clearView == true or a_clearView == 1 then
        pLentaTrigger:clear()
    end
    --base.print("----gameMessages---addTriggerMessage()",a_text, a_duration, pLentaTrigger, a_clearView )
    if pLentaTrigger then
        pLentaTrigger:addMessage(a_text, a_duration)
    end
end 

function addRadioMessage(a_text, a_duration)
    if pLentaRadio then
        pLentaRadio:addMessage(a_text, a_duration)
    end    
end    

function onRadioCommand(a_command_message)
    sRadioAuto:setText(a_command_message)
    if a_command_message == "" then
        sRadioAuto:setVisible(false)
        sMain:setVisible(false)
    else   
        sRadioAuto:setVisible(true)
        sMain:setVisible(true)
    end
end
    
function addMessage(a_text, a_duration)
    --base.print("----gameMessages---addMessage()")
    pLentaTrigger:addMessage(a_text, a_duration)
end

function updateAnimations()
    if pLentaRadio then
        pLentaRadio:updateAnimations()
    end
    
    if pLentaTrigger then
        pLentaTrigger:updateAnimations()
    end
    
    if sPause and sPause:getVisible() then
        local timeCur = DCS.getRealTime() * 1000 - timeStartAnimPause        
        if (timeCur > 2000) then
            timeStartAnimPause = DCS.getRealTime() * 1000
            timeCur = 0
        end
        sPause:setSkin(SkinUtils.setStaticPictureAlpha((1500-timeCur)/1500, sPause:getSkin()))
    end
end

function showPause()
    if sPause then
        if DCS.isMultiplayer() == true then
            sPause:setVisible(true)
            timeStartAnimPause = DCS.getRealTime() * 1000
            sPause:setSkin(SkinUtils.setStaticPictureAlpha(1, sPause:getSkin()))
        else
            sPause:setVisible(false)
        end
    end    
end

function hidePause()
    if sPause then
        sPause:setVisible(false)
    end    
end

function kill()
    for k,v in base.pairs(ListCreatedWidgets) do
        v:destroy()
    end
    
	if window_ then
	   window_:setVisible(false)
	   window_:kill()
	   window_ = nil
	end
end


