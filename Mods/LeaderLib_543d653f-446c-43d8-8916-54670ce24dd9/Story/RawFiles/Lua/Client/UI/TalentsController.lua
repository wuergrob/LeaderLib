
TalentManager.SelectedTalents = {}
TalentManager.ControllerUIAvailablePoints = 0

local msgBox_c_ButtonPressed = {
	Yes = 1,
	No = 2,
	Cancel = 3
}

local TalentState =
{
	Selected = 0,
	Selectable = 2,
	Locked = 3
}

---@param name string
---@return boolean
local function IsSelectedInMenu(name)
	Ext.Print(name)
	if TalentManager.SelectedTalents[name] then
		return true
	end
	return false
end

---@param name string
---@return boolean
local function IsRegisteredUnusedTalent(name)
	if TalentManager.RegisteredCount[name] ~= nil and TalentManager.RegisteredCount[name] > 0 then return true end
	return false
end

---@param character EclCharacter
---@param name string
---@return boolean
local function HasCustomTalentWithName(character, name)
	local talentNamePrefixed = "TALENT_" .. name
	if character ~= nil and character.Stats ~= nil and character.Stats[talentNamePrefixed] == true then
		return true
	end
	return false
end

---@param name string
local function UnselectTalentByName(name)
	TalentManager.SelectedTalents[name] = false
end

local function GetArrayIndexStart(ui, arrayName, offset)
	local i = 0
	while i < 9999 do
		local val = ui:GetValue(arrayName, "number", i)
		if val == nil then
			val = ui:GetValue(arrayName, "string", i)
			if val == nil then
				val = ui:GetValue(arrayName, "boolean", i)
			end
		end
		if val == nil then
			return i
		end
		i = i + offset
	end
	return -1
end

---@param character EclCharacter
---@param talent string
local function CharacterMeetsTalentRequirements(character, talent)
	if TalentManager.RequirementHandlers[talent] == nil then
		--Ext.PrintWarning("no requirement handler")
		return true
	end
	for modID in pairs(TalentManager.RequirementHandlers[talent]) do
		local requirementsHandler = TalentManager.RequirementHandlers[talent][modID]
		if requirementsHandler and requirementsHandler(character) == false then
			return false
		end
	end
	return true
end


---@param character EclCharacter
---@param name string
---@return TalentState
local function GetTalentState(character, name)
	--Ext.Print("GetTalentState " .. talent)
	if character.Stats["TALENT_" .. name] then Ext.Print("Selected") return TalentState.Selected
	elseif not CharacterMeetsTalentRequirements(character, name) then Ext.Print("Locked") return TalentState.Locked
	else Ext.Print("Selectable") return TalentState.Selectable
	end
end

---@param character EclCharacter
---@return table
local function BuildTalentInfoTableForRegisteredTalents(character)
	local talentInfoTable = {}
	for talent in pairs(TalentManager.RegisteredTalents) do
		table.insert(talentInfoTable, {
			talentId = Data.TalentEnum[talent],
			talentName = Data.Talents[Data.TalentEnum[talent]],
			talentState = GetTalentState(character, talent),
			softSelected = IsSelectedInMenu(talent)
		})
	end
	return talentInfoTable
end

local TalentFontColor =
{
	Selectable = "#403625",
	Locked = "#C80030"
}

---@param talentName string
---@param talentState TalentState
---@return string
function GetTalentFontColorText(talentName, talentState)
	local prefix = "<font color="
	local affix = "</font>"
	if talentState == TalentState.Selectable then
		return (prefix .. TalentFontColor.Selectable .. ">" .. talentName .. affix)
	elseif talentState == TalentState.Locked then
		return (prefix .. TalentFontColor.Locked .. ">" .. talentName .. affix)
	else
		return talentName
	end
end

Ext.RegisterListener("SessionLoaded", function()

	Ext.RegisterUITypeCall(Data.UIType.statsPanel_c, "removePointsTalent", function(ui, call, talentId, ...)
		Ext.Print("RemovePointsTalent")
		if IsRegisteredUnusedTalent(Data.Talents[talentId]) and IsSelectedInMenu(Data.Talents[talentId]) then
			ui:GetRoot().mainpanel_mc.stats_mc.talents_mc.setBtnVisible(false, talentId, false)
			ui:GetRoot().mainpanel_mc.stats_mc.talents_mc.setBtnVisible(true, talentId, false)
			TalentManager.SelectedTalents[Data.Talents[talentId]] = false
		end
	end, "After")

	Ext.RegisterUITypeInvokeListener(Data.UIType.statsPanel_c, "ButtonPressed", function(ui, call, buttonPressedType, deviceId)
		Ext.Print("buttonPressed")
		if buttonPressedType == msgBox_c_ButtonPressed.No then
			TalentManager.SelectedTalents = {}
		end
	end, "After")

	Ext.RegisterUINameInvokeListener("setStatPoints", function(ui, call, statsType, pointsAmount)
		Ext.Print("setStatPoints")
		-- statsType = 3 -> talentPoints
		if statsType == 3 then
			TalentManager.ControllerUIAvailablePoints = pointsAmount
		end
	end, "After")

	Ext.RegisterUITypeCall(Data.UIType.statsPanel_c, "addPointsTalent", function(ui, call, talentId, ...)
		--Ext.Print(Data.Talents[talentId])
		if IsRegisteredUnusedTalent(Data.Talents[talentId]) then
			ui:GetRoot().mainpanel_mc.stats_mc.talents_mc.setBtnVisible(false, talentId, false)
			ui:GetRoot().mainpanel_mc.stats_mc.talents_mc.setBtnVisible(false, talentId, true)
			TalentManager.SelectedTalents[Data.Talents[talentId]] = true
		end
	end, "After")

	Ext.RegisterUITypeInvokeListener(Data.UIType.statsPanel_c, "updateArraySystem", function(ui, call, ...)
		local character = GameHelpers.Client.GetCharacter()
		local indexBtnArray = GetArrayIndexStart(ui, "lvlBtnTalent_array", 1)

		if ui:GetRoot().mainpanel_mc.stats_mc.currentPanel.name ~= "talents_mc" then
			TalentManager.SelectedTalents = {}
		end

		local talentInfoTable = BuildTalentInfoTableForRegisteredTalents(character)

		for j=1,#talentInfoTable,1 do
			local talentState = GetTalentState(character, talentInfoTable[j].talentName)
			if HasCustomTalentWithName(character, talentInfoTable[j].talentName) then
				Ext.Print("Unselected a talent...")
				Ext.Print(talentInfoTable[j].talentName)
				UnselectTalentByName(talentInfoTable[j].talentName)
			end

			local isSelected = IsSelectedInMenu(talentInfoTable[j].talentName)
			local notSelectedHasPointsAndIsSelectable = (not IsSelectedInMenu(talentInfoTable[j].talentName) and TalentManager.ControllerUIAvailablePoints > 0 and talentState == TalentState.Selectable)
			Ext.Print("notSelectedHasPointsAndIsSelectable")
			Ext.Print(notSelectedHasPointsAndIsSelectable)
			Ext.Print(not IsSelectedInMenu(talentInfoTable[j][2]))
			Ext.Print(TalentManager.ControllerUIAvailablePoints)
			Ext.Print(talentState)

			ui:SetValue("lvlBtnTalent_array", false, indexBtnArray)
			ui:SetValue("lvlBtnTalent_array", talentInfoTable[j].talentId, indexBtnArray+1)
			ui:SetValue("lvlBtnTalent_array", isSelected, indexBtnArray+2)
			indexBtnArray = indexBtnArray+3
			ui:SetValue("lvlBtnTalent_array", true, indexBtnArray)
			ui:SetValue("lvlBtnTalent_array", talentInfoTable[j].talentId, indexBtnArray+1)
			ui:SetValue("lvlBtnTalent_array", notSelectedHasPointsAndIsSelectable, indexBtnArray+2)
			indexBtnArray = indexBtnArray+3

			local index = GetArrayIndexStart(ui, "talent_array", 1)
			local displayName = GetTalentFontColorText(talentInfoTable[j].talentName, talentState)

			ui:SetValue("talent_array", talentInfoTable[j].talentId, index)
			ui:SetValue("talent_array", (displayName or talentInfoTable[j].talentName), index+1)
			ui:SetValue("talent_array", talentState, index+2)
			index = index+3
		end
    end, "Before")
end)

local function EnableTestingTalents()
	TalentManager.EnableTalent("SpillNoBlood", "OpenTalents", function (character) return true end)
	TalentManager.EnableTalent("FolkDancer", "OpenTalents", function (character) return true end)
	TalentManager.EnableTalent("Scientist", "OpenTalents", function (character) return false end)
	TalentManager.EnableTalent("Jitterbug", "OpenTalents", function (character) return false end)
	TalentManager.EnableTalent("GoldenMage", "OpenTalents")
	TalentManager.EnableTalent("GoldenMage", "OpenTalents2", function (character) return false end)
	TalentManager.EnableTalent("GoldenMage", "OpenTalents3", function (character) return true end)
end

Ext.RegisterConsoleCommand("addControllerTalents", function(cmd)
	EnableTestingTalents()
end)