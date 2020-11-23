--[[
==============
    Notes
==============
The options setting menu is optionsSettings.swf
When clicking on the Controls tab, the game switches the menu to optionsInput.swf and recreates the menu buttons.

To allow the Mod Settings button to work from the Controls view (everything is set up for optionsSettings.swf), we get the game to switch to the Graphics tab, and then immediately switch to the Mod Settings tab.
This seems to be the easiest option since the engine does some weird thing to switch the GUI between both options GUI files.
]]

-- optionsSettings.swf
local OPTIONS_SETTINGS = 45
-- optionsInput.swf
local OPTIONS_INPUT = 17
local OPTIONS_ACCEPT = 1

local LarianMenuID = {
	Graphics = 1,
	Audio = 2,
	Gameplay = 3,
	Controls = 4,
}

local MessageBoxButtonID = {
	ACCEPT = 3,
	CANCEL = 4,
}

local MOD_MENU_ID = 69
local lastMenu = 1
local currentMenu = 1
local switchToModMenu = false

local ModMenuTabButtonText = Classes.TranslatedString:Create("h5945db23gdaafg400ega4d6gc2ffa7a53f92", "Mod Settings")

Ext.RegisterNetListener("LeaderLib_ModMenu_RunParseUpdateArrayMethod", function(cmd,payload)
	local ui = Ext.GetBuiltinUI("Public/Game/GUI/optionsSettings.swf")
	if ui ~= nil then
		ui:Invoke("parseUpdateArray")
	end
end)

local function SwitchToModMenu(ui, ...)
	local main = ui:GetRoot()
	---@type MainMenuMC
	local mainMenu = main.mainMenu_mc
	mainMenu.removeItems()
	mainMenu.resetMenuButtons(MOD_MENU_ID)
	local buttonsArray = mainMenu.menuBtnList.content_array
	for i=0,#buttonsArray do
		local button = buttonsArray[i]
		if button ~= nil then
			if button.buttonID == MOD_MENU_ID then
				button.setEnabled(false)
			else
				button.setEnabled(true)
			end
		end
	end
	ModMenuManager.CreateMenu(ui, mainMenu)
	ModMenuManager.SetScrollPosition(ui)
end

Ext.RegisterNetListener("LeaderLib_ModMenu_Open", function(cmd,payload)
	local ui = Ext.GetBuiltinUI("Public/Game/GUI/optionsSettings.swf")
	if ui ~= nil then
		SwitchToModMenu(ui)
	end
end)

---@param ui UIObject
local function CreateModMenuButton(ui, method, ...)
	local main = ui:GetRoot()
	if main ~= nil then
		---@type MainMenuMC
		local mainMenu = main.mainMenu_mc
		mainMenu.addOptionButton(ModMenuTabButtonText.Value, "switchToModMenu", MOD_MENU_ID, switchToModMenu)
		if switchToModMenu then
			for i=0,#main.baseUpdate_Array do
				local val = main.baseUpdate_Array[i]
				if val == true then
					main.baseUpdate_Array[i] = false
					break
				end
			end
			SwitchToModMenu(ui)
			--Ext.PostMessageToServer("LeaderLib_ModMenu_RequestOpen", tostring(Client.ID))
		end
	end
	if switchToModMenu then
		--Ext.PostMessageToServer("LeaderLib_ModMenu_SendParseUpdateArrayMethod", tostring(UI.ClientID))
		switchToModMenu = false
	end
end

local debugEvents = {
	"onEventInit",
	"parseUpdateArray",
	"parseBaseUpdateArray",
	"onEventResize",
	"onEventUp",
	"onEventDown",
	"hideWin",
	"showWin",
	"getHeight",
	"getWidth",
	"setX",
	"setY",
	"setPos",
	"getX",
	"getY",
	"openMenu",
	"closeMenu",
	"cancelChanges",
	"addMenuInfoLabel",
	"setMenuCheckbox",
	"addMenuSelector",
	"addMenuSelectorEntry",
	"selectMenuDropDownEntry",
	"clearMenuDropDownEntries",
	"setMenuDropDownEnabled",
	"setMenuDropDownDisabledTooltip",
	"setMenuSlider",
	"addOptionButton",
	"setButtonEnabled",
	"removeItems",
	--"setButtonDisable",
	"resetMenuButtons",
}

local debugCalls = {
	"switchToModMenu",
	"requestCloseUI",
	"acceptPressed",
	"applyPressed",
	"checkBoxID",
	"comboBoxID",
	"selectorID",
	"menuSliderID",
	"buttonPressed",
	"switchMenu",
}

Ext.RegisterNetListener("LeaderLib_ModMenu_CreateMenuButton", function(cmd, payload)
	local ui = Ext.GetBuiltinUI("Public/Game/GUI/optionsSettings.swf")
	if ui ~= nil then
		CreateModMenuButton(ui)
	end
end)

local registeredListeners = false

local function OnSwitchMenu(ui, call, id)
	if currentMenu == MOD_MENU_ID then
		ModMenuManager.SaveScroll(ui)
	end
	lastMenu = currentMenu
	currentMenu = id
	if id == LarianMenuID.Gameplay then
		if Ext.IsDeveloperMode() then
			GameSettingsMenu.AddSettings(ui, true)
		end
	elseif id == LarianMenuID.Controls then

	end
end

local function OnAcceptChanges(ui, call)
	if currentMenu == MOD_MENU_ID then
		ModMenuManager.SaveScroll(ui)
		ModMenuManager.CommitChanges()
		registeredListeners = false
	elseif currentMenu == LarianMenuID.Gameplay then
		GameSettingsMenu.CommitChanges()
	end
end

local function OnApplyPressed(ui, call, ...)
	
end

local function OnCancelChanges(ui, call)
	if currentMenu == MOD_MENU_ID then
		ModMenuManager.SaveScroll(ui)
		ModMenuManager.UndoChanges()
		registeredListeners = false
	elseif currentMenu == LarianMenuID.Gameplay then
		GameSettingsMenu.UndoChanges()
	end
end

Ext.RegisterListener("SessionLoaded", function()
	if Ext.IsDeveloperMode() then
		for i,v in pairs(debugEvents) do
			---@param ui UIObject
			Ext.RegisterUINameInvokeListener(v, function(ui, ...)
				print(ui:GetTypeId(), Common.Dump({...}), Ext.MonotonicTime())
			end)
		end
		for i,v in pairs(debugCalls) do
			---@param ui UIObject
			Ext.RegisterUINameCall(v, function(ui, ...)
				print(ui:GetTypeId(), Common.Dump({...}), Ext.MonotonicTime())
			end)
		end
	end

	Ext.RegisterUITypeCall(19, "openMenu", function(ui, call)
		currentMenu = 1
		lastMenu = 1
		registeredListeners = false
	end)

	Ext.RegisterUINameCall("switchToModMenu", function(ui, call, ...)
		lastMenu = currentMenu
		currentMenu = MOD_MENU_ID
		SwitchToModMenu(ui)
		--Ext.PostMessageToServer("LeaderLib_ModMenu_RequestOpen", tostring(Client.ID))
	end)
	---@param ui UIObject
	Ext.RegisterUINameCall("switchToModMenuFromInput", function(ui, call, ...)
		switchToModMenu = true
		ui:ExternalInterfaceCall("switchMenu", 1)
		--ui:ExternalInterfaceCall("requestCloseUI")
	end)
	Ext.RegisterUITypeCall(29, "ButtonPressed", function(ui, call, id)
		-- Are you sure you want to discard your changes?
		if lastMenu == MOD_MENU_ID or currentMenu == MOD_MENU_ID then
			if id == MessageBoxButtonID.CANCEL then

			elseif id == MessageBoxButtonID.ACCEPT then
				ModMenuManager.UndoChanges()
			end
		elseif lastMenu == LarianMenuID.Gameplay or currentMenu == LarianMenuID.Gameplay then
			if id == MessageBoxButtonID.CANCEL then

			elseif id == MessageBoxButtonID.ACCEPT then
				GameSettingsMenu.UndoChanges()
			end
		end
	end)

	Ext.RegisterUITypeCall(OPTIONS_SETTINGS, "acceptPressed", OnAcceptChanges)
	Ext.RegisterUITypeCall(OPTIONS_INPUT, "acceptPressed", OnAcceptChanges)
	Ext.RegisterUITypeCall(OPTIONS_SETTINGS, "requestCloseUI", OnCancelChanges)
	Ext.RegisterUITypeCall(OPTIONS_INPUT, "requestCloseUI", OnCancelChanges)

	Ext.RegisterUITypeCall(OPTIONS_INPUT, "applyPressed", OnApplyPressed)

	---@param ui UIObject
	Ext.RegisterUINameInvokeListener("parseUpdateArray", function(...)
		local ui = Ext.GetBuiltinUI("Public/Game/GUI/optionsSettings.swf")
		if ui ~= nil then
			if currentMenu == 3 then
				GameSettingsMenu.AddSettings(ui, true)
			end
		end
	end)

	---optionsInput.swf version.
	---@param ui UIObject
	Ext.RegisterUINameInvokeListener("addMenuButtons", function(ui, method, ...)
		ui = Ext.GetBuiltinUI("Public/Game/GUI/optionsInput.swf")
		local main = ui:GetRoot()
		if main ~= nil then
			---@type MainMenuMC
			local mainMenu = main.controlsMenu_mc
			mainMenu.addMenuButton(ModMenuTabButtonText.Value, "switchToModMenuFromInput", MOD_MENU_ID, false)
		end
	end)

	Ext.RegisterUITypeCall(OPTIONS_INPUT, "switchMenu", OnSwitchMenu)
	Ext.RegisterUITypeCall(OPTIONS_SETTINGS, "switchMenu", OnSwitchMenu)

	local OnCheckBox = function(ui, call, id, value)
		if currentMenu == MOD_MENU_ID then
			ModMenuManager.OnCheckbox(id, value)
		elseif currentMenu == LarianMenuID.Gameplay then
			GameSettingsMenu.OnCheckbox(id, value)
		end
	end

	Ext.RegisterUITypeCall(OPTIONS_SETTINGS, "checkBoxID", OnCheckBox)
	Ext.RegisterUITypeCall(OPTIONS_INPUT, "checkBoxID", OnCheckBox)

	local OnComboBox = function(ui, call, id, value)
		if currentMenu == MOD_MENU_ID then
			ModMenuManager.OnComboBox(id, value)
		elseif currentMenu == LarianMenuID.Gameplay then
			GameSettingsMenu.OnComboBox(id, value)
		end
	end

	Ext.RegisterUITypeCall(OPTIONS_SETTINGS, "comboBoxID", OnComboBox)
	Ext.RegisterUITypeCall(OPTIONS_INPUT, "comboBoxID", OnComboBox)

	local OnSelector = function(ui, call, id, value)
		if currentMenu == MOD_MENU_ID then
			ModMenuManager.OnSelector(id, value)
		elseif currentMenu == LarianMenuID.Gameplay then
			GameSettingsMenu.OnSelector(id, value)
		end
	end

	Ext.RegisterUITypeCall(OPTIONS_SETTINGS, "selectorID", OnSelector)
	Ext.RegisterUITypeCall(OPTIONS_INPUT, "selectorID", OnSelector)

	local OnSlider = function(ui, call, id, value)
		if currentMenu == MOD_MENU_ID then
			ModMenuManager.OnSlider(id, value)
		elseif currentMenu == LarianMenuID.Gameplay then
			GameSettingsMenu.OnSlider(id, value)
		end
	end

	Ext.RegisterUITypeCall(OPTIONS_SETTINGS, "menuSliderID", OnSlider)
	Ext.RegisterUITypeCall(OPTIONS_INPUT, "menuSliderID", OnSlider)

	local OnButton = function(ui, call, id)
		if currentMenu == MOD_MENU_ID then
			ModMenuManager.OnButtonPressed(id)
		elseif currentMenu == LarianMenuID.Gameplay then
			GameSettingsMenu.OnButtonPressed(id)
		end
	end
	Ext.RegisterUITypeCall(OPTIONS_SETTINGS, "buttonPressed", OnButton)
	Ext.RegisterUITypeCall(OPTIONS_INPUT, "buttonPressed", OnButton)

	---@param ui UIObject
	Ext.RegisterUINameInvokeListener("parseBaseUpdateArray", function(ui, method, ...)
		-- Initial setup
		if ui:GetTypeId() == nil then
			ui = Ext.GetBuiltinUI("Public/Game/GUI/optionsSettings.swf") or ui
			--Ext.PostMessageToServer("LeaderLib_ModMenu_CreateMenuButtonAfterDelay", tostring(UI.ClientID))
		end
		CreateModMenuButton(ui, method, ...)
	end)
end)