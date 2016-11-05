--Command menu and message log.
--Menu navigation is based on fsm:
--  state: current menu
--  input symbol: chosen command of current menu
--  output symbol: building new menu
--Menu item types: command, menus and menu building functions.
--Commands are represented as functors. Path to the command stores parameters to the command. When
--the command is chosen CommandMenu collects parameters from the path and passes them to the command.
--Item #11 - Back.
--Item #12 - Exit.
--Messages in the log have life time.

local base = _G

module('CommandMenu')

__index = base.getfenv()

local fsm = base.require('fsm')
local utils = base.require('utils')

local gettext = base.require("i_18n")
local _ = gettext.translate

local Gui           = base.require("dxgui")
local Static        = base.require("Static")
local Window        = base.require("Window")
local StaticList    = base.require("StaticList")
local StaticMenu    = base.require("StaticMenu")
local Panel         = base.require("Panel")
local Skin          = base.require('Skin')
local Size          = base.require("Size")
local Color         = base.require("Color")
local Text          = base.require("Text")
local Bkg           = base.require("Bkg")
local HMD           = base.HMD

ON_OPEN = 0
ON_CLOSE = -1
ON_HOME = -2

ON_PREVIOUS = 11
ON_EXIT = 12

menuWidth = 280

local fontSize = 12
local fontSizeCaption = 15
local menuCaptionHeight = 20

if HMD.isActive() == true then
    fontSize = 20
    fontSizeCaption = 25
    menuCaptionHeight = 30
end

function eventCallback(ptr, event, ...)
	local self = list[ptr]
	local handler = handlers[event]
	handler(self, ...)
end

function new(self, data, rootItem, width, height)
	local newCommandMenu = {}
	base.setmetatable(newCommandMenu, self)	
	self.__index = self
	newCommandMenu:init(data, rootItem, width, height)
	return newCommandMenu
end

function init(self, data, rootItem, parent)
		
	self.level = 0 --Current menu level
	self.path = {} --Current menu path
	self.removeMessageActions = {}
	self.funcRef = nil
	
	local x, y, width, height = parent:getBounds()
	
	local containerSkin = {}
	local container = Panel.new('CommandMenu.container')
	do
		container:setSkin(containerSkin)
		container:setBounds(0, 0, width, height)
		self.container = container
	end
	
	local font = 'DejaVuLGCSansMono.ttf'
	local textSkin = Skin.staticSkin()
	textSkin.skinData.params.textWrapping = true
	textSkin.skinData.states.released[1].text.font = font
	textSkin.skinData.states.released[1].text.fontSize = fontSize;
	textSkin.skinData.states.released[1].text.color = Color.white()
	textSkin.skinData.states.released[1].text.shadowColor = Color.black()
	textSkin.skinData.states.released[1].text.shadowOffset = Size.new(1, 1)
	
	do
		local menuPanel = Panel.new('CommandMenu.menuPanel')
		menuPanel:setSkin(containerSkin)
		menuPanel:setBounds(width - menuWidth, 0, menuWidth, height)
		container:insertWidget(menuPanel)
		self.menuPanel = menuPanel
		
		do
			local menuCaption = Static.new('CommandMenu.menuCaption')
			menuCaption:setSkin(textSkin)
			local menuCaptionSkin = menuCaption:getSkin()
			menuCaptionSkin.skinData.states.released[1].text.fontSize = fontSizeCaption;
			menuCaptionSkin.skinData.states.released[1].text.color = Color.white()
			menuCaptionSkin.skinData.states.released[1].text.shadowColor = Color.black()
			menuCaptionSkin.skinData.states.released[1].text.shadowOffset = Size.new(1, 1)
			menuCaption:setSkin(menuCaptionSkin)
			menuCaption:setBounds(0, 0, menuWidth, menuCaptionHeight)
			menuPanel:insertWidget(menuCaption)
			self.menuCaption = menuCaption
		end
		
		do
			local menuHeight = height - menuCaptionHeight
			local skin = {
				container = containerSkin,
				item = textSkin
			}
			local commandMenu = StaticMenu.new('CommandMenu.commandMenu', 0, menuCaptionHeight, menuWidth, menuHeight, 12, skin, self)
			menuPanel:insertWidget(commandMenu:getContainer())
			self.commandMenu = commandMenu
		end
	end
	self.menuPanel:setVisible(false)
	
	do
		local messageLogWidth = width - menuWidth
		local messageLog = StaticList.new('CommandMenu.messageLog', textSkin)
		local skin = {
			container = containerSkin,
			item = textSkin,
			popItem = StaticList.PopFrontItem
		}
		messageLog:setSkin(skin)
		messageLog:setBounds(0, 0, messageLogWidth, height)
		container:insertWidget(messageLog:getContainer())
		self.messageLog = messageLog
	end	
	
	if data then
		self:setData(data, rootItem)
	end
	
	return self.container
end

function setData(self, data, rootItem)
	
	--self.data = data
	local fsmData = {}
	self.fsmData = fsmData
	self:buildFsmData(fsmData, data, rootItem)
	self.fsm = fsm:new(fsmData, self.onSymbol, self, 'menu')
end

function buildFsmData(self, fsmData, data, rootItem)
	--base.print('CommandDialog.buildFsmData()')
	self.fsmData = fsmData
	self.rootItem = rootItem
	local mainMenu = rootItem.submenu or rootItem:getSubmenu()
	fsmData.init_state = 'Closed'
	fsmData.transitions = {
		['Closed'] = {
			[ON_OPEN] = {
				outSymbol = function(self)	
					self:clearMenu()
					--base.print('buildFsmData ON_OPEN')
					self:enterMenu_(rootItem)
				end,
				newState = mainMenu.name,
				stackOption = fsm.PUSH_TO_STACK
			},
		}
	}
	fsmData.initStateFreeTransitions = {
		[ON_HOME] = {
			outSymbol = function(self)
				self:clearMenu()
				--base.print('buildFsmData ON_HOME')
				self:enterMenu_(rootItem)
			end,
			newState = mainMenu.name,
			stackOption = fsm.PUSH_TO_STACK,
		},
		[ON_CLOSE] = {
			outSymbol = self.closeMenu_,
			newState = 'Closed'
		},
	}
	if self.rootItem.submenu ~= nil then
		self:buildMenuFsm_(fsmData.transitions, self.rootItem.name, self.rootItem.submenu)
	end
end

function buildMenuFsm_(self, transitions, item_name, submenu)
	
	transitions[item_name] = {}
	local nCount = #submenu.items
	for item_index, item in base.pairs(submenu.items) do
		if item.submenu then--есть подменю - строю подменю
			transitions[item_name][item_index] =
			{
				outSymbol = function(self)
					self:enterMenu_(item)
				end,
				newState = item_name..'.'..item.name,
				stackOption = fsm.PUSH_TO_STACK
			}
			self:buildMenuFsm_(transitions, item_name..'.'..item.name, item.submenu)
		elseif item.getSubmenu then
			transitions[item_name][item_index] =
			{
				outSymbol = function(self)
					local submenu = item:getSubmenu()
					self:buildMenuFsm_(transitions, item_name..'.'..item.name, submenu)
					self:enterMenu_(item)
				end,
				newState = item_name..'.'..item.name,
				stackOption = fsm.PUSH_TO_STACK
			}
		else
			transitions[item_name][item_index] =
			{
				outSymbol = function(self)
					self:selectCommand_(item)
				end,
				newState = 'Closed'
			}
		end			
	end

	transitions[item_name][ON_PREVIOUS] = {
		outSymbol = function(self)
			self:popMenuItem_()
			local top = self.path[#self.path]
			if top.submenu then
				--base.print('popMenuItem_() '..top.submenu.name)
				self:buildMenu_(top.submenu)
			elseif top.getSubmenu then
				local submenu = top:getSubmenu()
				self:buildMenuFsm_(transitions, top.name, submenu)
				self:buildMenu_(submenu)
			end
		end,
		newState = nil,
		stackOption = fsm.POP_FROM_STACK
	}
	
	transitions[item_name][ON_EXIT] = {
		outSymbol = self.closeMenu_,
		newState = 'Closed',
		stackOption = fsm.CLEAR_STACK
	}
end

function buildMenuFsm(self, menu_item)
	self:buildMenuFsm_(self.fsmData.transitions, menu_item)
end

function setHandler(self, handler)
	self.handler = handler
end

function clearLog_(self)
	self.messageLog:clear()
end

function release(self)
	--base.print('release')
	fsm:reset()
	
	if self.funcRef ~= nil then
		base.timer.removeFunction(self.funcRef)
		self.funcRef = nil
	end
	
	base.assert(self.container ~= nil)
	self.container:destroy()
	self.container = nil
		self.menuPanel = nil
			self.menuCaption = nil
			self.commandMenu = nil
		self.messageLog = nil
end

local function onMenuShowHide(self, prev, cur)
	--base.print('onMenuShoHide '..base.tostring(cur))
	if self.handler then
		if not prev and cur then
			self.handler:onMenuShow(self)
		elseif prev and not cur then
			self.handler:onMenuHide(self)
		end
	end
end

function toggle(self, on)
	--base.print('toggle('..base.tostring(on)..')')
	onMenuShowHide(self, self:isMenuVisible(), on and self.menuPanel:isVisible())
	self.container:setVisible(on)
	return self.container:isVisible()
end

function toggleMenu(self, on)
	--base.print('toggleMenu('..base.tostring(on)..')')
	onMenuShowHide(self, self:isMenuVisible(), self.container:isVisible() and on)
	self.menuPanel:setVisible(on)
	return self.menuPanel:isVisible()
end

function isMenuVisible(self)
	--base.print('isVisible()')
	return self.container:getVisible() and self.menuPanel:isVisible()
end

function isLogEmpty(self)
	return self.messageLog:getContainer():getWidgetCount() == 0
end

function pushMenuItem_(self, menu_item)
	--base.print('pushMenuItem_')
	base.table.insert(self.path, menu_item)
	self.receiver = menu_item.receiver
	self.level = self.level + 1
end

function popMenuItem_(self)
	--base.print('popMenuItem_')
	local top = self.path[#self.path]
	base.table.remove(self.path)
	self.receiver = nil
	self.level = self.level - 1
	return top
end

function getItemColor(self, item)
	--base.print('item.name = '..item.name)
	--base.print('item.color = '..base.tostring(item.color))
	if item.color then
		return item.color:get()
	else
		for index = #self.path, 1, -1 do
			local parentColor = self.path[index].color
			if parentColor ~= nil then
				return parentColor:get()
			end
		end
		return nil
	end
end

function makeGuiColor(color)
	local guiColorValue = {0, 0, 0}
	for i = 1, 3 do
		local bs = base.math.pow(256, 3 - i)
		local num = base.math.floor(color / bs)
		guiColorValue[i] = num / 256
		color = color - num * bs
	end
	return base.Color.new(guiColorValue[1], guiColorValue[2], guiColorValue[3])
end

function buildMenu_(self, menu)
	self.menu = menu
	
	local fullCaption = self.caption ~= nil and self.caption..'. ' or ''	
	if self.level > 1 then
		fullCaption = fullCaption..base.tostring(self.level)..'. '
	end
	for submenu_index, submenu_item in base.pairs(self.path) do
		if submenu_index > 1 then
			fullCaption = fullCaption..'. '..submenu_item.name
		else
			fullCaption = fullCaption..submenu_item.name
		end
	end
	self:setCaption(fullCaption)
	
	self.commandMenu:clear()	
	self.menuItemCommands = {}
	local count = #menu.items
	--base.print('menu name:'..menu.name)
	--base.print('count items:'..base.tostring(count))
	for index, item in base.pairs(menu.items) do
		--base.print('item.name = '..item.name)
		if item.condition == nil or item.condition:check() then
			local item_name = item.name
			if item.submenu or item.getSubmenu then
				item_name = item_name..'...'
			else
				--item_name = item_name..'.'
			end
			
			if item.isDialogOpened ~= nil and item.isDialogOpened() then
				item_name = item_name..'>>'
			end
			
			local color = self:getItemColor(item) or (menu.color and menu.color:get()) or (self.color and self.color:get()) or utils.COLOR.WHITE
			self.commandMenu:setItem(index, 'F'..index..'. '..item_name, makeGuiColor(color))
			self.menuItemCommands[index] = index
		end
	end	
	if self.level > 1 then
		self.commandMenu:setItem(11, _('F11. Previous Menu'), makeGuiColor(utils.COLOR.WHITE))
		self.menuItemCommands[11] = ON_PREVIOUS
	end
	self.commandMenu:setItem(12, _('F12. Exit'), makeGuiColor(utils.COLOR.WHITE))
	self.menuItemCommands[12] = ON_EXIT
end

function enterMenu_(self, menuItem)
	--base.print('enterMenu_'..base.tostring(menuItem))
	self:pushMenuItem_(menuItem)
	self:buildMenu_(menuItem.submenu or menuItem:getSubmenu())
end

function setMainMenu(self)
	--base.print('setMainMenu')
	if self.rootItem.getSubmenu ~= nil then
		self:buildMenuFsm_(self.fsmData.transitions, self.rootItem.name, self.rootItem:getSubmenu())
	end
	self.fsm:onSymbol(ON_HOME)
	--base.print('mainMenu.name = '..base.tostring(self.rootItem.name))
	--base.print('fsm.state = '..base.tostring(self.fsm.state))
end

local function findMenuItemByName(menu, name)
	for menuItemIndex, menuItem in base.pairs(menu.items) do
		if menuItem.name == name then
			return menuItem
		end
	end
	return nil
end

function updateMenu(self)
	--base.print('updateMenu')
	if self.rootItem.getSubmenu ~= nil then
		self:buildMenuFsm_(self.fsmData.transitions, self.rootItem.name, self.rootItem:getSubmenu())
	end
	
	local oldPath = self.path	
	self.path = {}
	--Restoring menu
	local menuItem = self.rootItem
	for oldItemIndex, oldItem in base.pairs(oldPath) do
		if oldItemIndex > 1 then
			menuItem = findMenuItemByName(menuItem.submenu or menuItem:getSubmenu(), oldItem.name)
		end	
		if menuItem ~= nil then
			base.table.insert(self.path, menuItem)
			if menuItem.submenu == nil then
				if menuItem.getSubmenu ~= nil then
					self.menu = menuItem:getSubmenu()
				end
			else
				self.menu = menuItem.submenu
			end
			fsm.state = menuItem.name
		else
			break
		end
	end
	
	self:buildMenu_(self.menu)
end

function selectCommand_(self, menu_item)
	--base.print('selectCommand_ '..base.tostring(menu_item))
	base.table.insert(self.path, menu_item)
	self.level = self.level + 1
	self:performCommands()
end

function selectMenuItem(self, menu_item_num)
	--base.print('CommandMenu.selectMenuItem('..base.tostring(menu_item_num)..')')
	if self.menuItemCommands then
		local inputSymbol = self.menuItemCommands[menu_item_num]
		
		--base.print('inputSymbol = '..base.tostring(inputSymbol))
		--base.print('before: fsm.state = '..base.tostring(self.fsm.state))
		if inputSymbol then
			self.fsm:onSymbol(inputSymbol)
		end
	end
	--base.print('selectMenuItem will see self.handler')
	if 	self.handler then 
		--base.print('self.handler exist')
		if 	self.handler.onDialogMenuItem then
			--base.print('onDialogMenuItem')		
			self.handler:onDialogMenuItem(menu_item_num)
		end
	end
	--base.print('after: fsm.state = '..base.tostring(self.fsm.state))
end

function performCommands(self)
	local parameters = {}
	for path_index, path_item in base.pairs(self.path) do
		if path_item.command then
			self:onCommand(path_item.command, parameters)
			parameters = {}
		end	
		if path_item.parameter then
			base.table.insert(parameters, path_item.parameter)
		elseif path_item.parameters then
			for par_index, par_item in base.pairs(path_item.parameters) do
				base.table.insert(parameters, par_item)
			end
		end
	end
end

function onCommand(self, command, parameters)	
	--base.print('CommandMenu.onCommand()'..base.tostring(command))
	self:closeMenu_()
	if command then
		if 	self.handler and
			self.handler.onDialogCommand then
			self.handler:onDialogCommand(self, command, parameters)
		end
	end
end

function setCaption(self, caption)
	self.menuCaption:setText(caption)
	local captionWidth, captionHeight = self.menuCaption:calcSize()
	self.menuCaption:setBounds(0, 0, menuWidth, captionHeight)
	local menuX, menuY, menuWidth, menuHeight = self.commandMenu:getContainer():getBounds()
	self.commandMenu:getContainer():setBounds(0, captionHeight + 5, menuWidth, menuHeight)
	if 	self.handler and
		self.handler.onDialogSetCaption then
		self.handler:onDialogSetCaption(self, caption)
	end
end

function clearMenu(self)
	--base.print('clearMenu')
	self.path = {}
	self.level = 0
	self.commandMenu:clear()
	self:setCaption('')
end

function closeMenu_(self)
	--base.print('closeMenu count'..base.tostring(#self.path))
	self:setMainMenu()
	self:toggleMenu(false)
end

local addTimeStamp = false

local function getTimeStr(timeSec)
	return base.string.format('[%02d:%02d:%02d]', utils.getTime(timeSec))
end

function onMsgStart(self, msg, color)
	self.messageLog:insertItem(nil, addTimeStamp and getTimeStr(base.timer.getAbsTime())..' '..msg or msg, makeGuiColor(color))
end

local function findItemIndex(messageLog, msg)
	local messageCount = messageLog:getItemCount()
	for i = 1, messageCount do
		local messageItem = messageLog:getItem(i)
		if messageItem:getText() == msg then
			return i
		end
	end
end

local function removeNextMessage(self, time)
	local action = self.removeMessageActions[1]
	local itemIndex = findItemIndex(self.messageLog, action.msg)
	if itemIndex ~= nil then
		self.messageLog:removeItem(itemIndex)
	end
	base.table.remove(self.removeMessageActions, 1)
	if #self.removeMessageActions > 0 then
		return self.removeMessageActions[1].time
	else
		self.funcRef = nil
	end
end

function onMsgFinish(self, msg)	
	local delay = 10.0
	local time = base.timer.getTime() + delay
	local i = 1
	while 	i <= #self.removeMessageActions and
			self.removeMessageActions[i].time < time do
		i = i + 1
	end	
	base.table.insert(self.removeMessageActions, i, {time = time, msg = msg})
	
	if self.funcRef == nil then
		if #self.removeMessageActions > 0 then
			self.funcRef = base.timer.scheduleFunction(removeNextMessage, self, self.removeMessageActions[1].time)
		end
	else
		if #self.removeMessageActions > 0 then
			if i == 1 then
				base.timer.setFunctionTime(self.funcRef, self.removeMessageActions[1].time)
			end
		else
			base.timer.removeFunction(self.funcRef)
			self.funcRef = nil
		end
	end	
end

--fsm handler
	
function onSymbol(self, outputSymbol)
	if outputSymbol then
		outputSymbol(self)
	end
end

--C++ event handlers

function onMenuItem(self, menu_item_num)
	--base.print('CommandMenu.onMenuItem('..base.tostring(menu_item_num)..')')
	self:selectMenuItem(menu_item_num)
end

function onMenuToggle(self, on)
	--base.print('CommandMenu.onMenuToggle('..base.tostring(on)..')')
	if self.fsm then
		if on then
			self.fsm:onSymbol(ON_OPEN)
		else
			self.fsm:onSymbol(ON_CLOSE)
		end
	end
	if 	self.handler and
		self.handler.onDialogToggle then
		self.handler:onDialogToggle(on)
	end
	return true
end



function getContainer(self)
	return self.container
end

list = {}

handlers = {
	['onMenuItem'] 		= onMenuItem,
	['onMenuToggle']	= onMenuToggle,
}
