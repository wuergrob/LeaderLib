---@class TagTooltipData
---@field Title TranslatedString
---@field Description TranslatedString

---@type table<string,TagTooltipData>
local TagTooltips = {}
local hasTagTooltip = false;

---@type TranslatedString
local ts = Classes.TranslatedString

local AutoLevelingDescription = ts:Create("hca27994egc60eg495dg8146g7f81c970e265", "<font color='#80FFC3'>Automatically levels up with the wearer.</font>")

local extraPropStatusTurnsPattern = "Set (.+) for (%d+) turn%(s%).-%((%d+)%% Chance%)"

---@param item EsvItem
---@param tooltip TooltipData
local function CondenseItemStatusText(tooltip, inputElements, addColor)
	
	local entries = {}
	
	for i,v in pairs(inputElements) do
		v.Label = string.gsub(v.Label, "  ", " ")
		local a,b,status,turns,chance = string.find(v.Label, extraPropStatusTurnsPattern)
		if status ~= nil and turns ~= nil and chance ~= nil then
			local color = ""
			tooltip:RemoveElement(v)
			if addColor == true then
				
			end
			table.insert(entries, {Status = status, Turns = turns, Chance = chance, Color = color})
		end
	end
	
	if #entries > 0 then
		local finalStatusText = ""
		local finalTurnsText = ""
		local finalChanceText = ""
		for i,v in pairs(entries) do
			finalStatusText = finalStatusText .. v.Status
			finalTurnsText = finalTurnsText .. v.Turns
			finalChanceText = finalChanceText .. v.Chance.."%"
			if i >= 1 and i < #entries then
				finalStatusText = finalStatusText .. "/"
				finalTurnsText = finalTurnsText .. "/"
				finalChanceText = finalChanceText .. "/"
			end
		end
		return string.format("On Hit:<br>%s for %s turns(s). (%s Chance)", finalStatusText, finalTurnsText, finalChanceText)
	end
end

local chaosDamagePattern = "<font color=\"#C80030\">([%d-%s]+)</font>"

---@param character EsvCharacter
---@param status EsvStatus
---@param tooltip TooltipData
local function OnStatusTooltip(character, status, tooltip)
	if Features.ReplaceTooltipPlaceholders or Features.FixChaosDamageDisplay or Features.TooltipGrammarHelper then
		for i,element in pairs(tooltip:GetElements("StatusDescription")) do
			if element ~= nil then
				if Features.ReplaceTooltipPlaceholders then
					element.Label = GameHelpers.Tooltip.ReplacePlaceholders(element.Label, character)
				end

				if Features.TooltipGrammarHelper then
					element.Label = string.gsub(element.Label, "a 8", "an 8")
					local startPos,endPos = string.find(element.Label , "a <font.->8")
					if startPos then
						local text = string.sub(element.Label, startPos, endPos)
						element.Label = string.gsub(element.Label, text, text:gsub("a ", "an "))
					end
				end

				if Features.FixChaosDamageDisplay and not Data.EngineStatus[status.StatusId] then
					local statusType = Ext.StatGetAttribute(status.StatusId, "StatusType")
					local descParams = Ext.StatGetAttribute(status.StatusId, "DescriptionParams")
					if statusType == "DAMAGE" 
						and not StringHelpers.IsNullOrEmpty(descParams)
						and string.find(descParams, "Damage") 
						and not string.find(element.Label:lower(), "chaos damage")
					then
						local startPos,endPos,damage = string.find(element.Label, chaosDamagePattern)
						if damage ~= nil then
							damage = string.gsub(damage, "%s+", "")
							local removeText = string.sub(element.Label, startPos, endPos):gsub("%-", "%%-")
							element.Label = string.gsub(element.Label, removeText, GameHelpers.GetDamageText("Chaos", damage))
						end
					end
				end
			end
		end
	end
end

---@param character EclCharacter
---@param skill EsvStatus
---@param tooltip TooltipData
local function OnSkillTooltip(character, skill, tooltip)
	if character ~= nil then UI.ClientCharacter = character.MyGuid or character.NetID end
	if Features.TooltipGrammarHelper then
		-- This fixes the double spaces from removing the "tag" part of Requires tag
		local element = tooltip:GetElement("SkillRequiredEquipment")
		if element ~= nil and not element.RequirementMet and string.find(element.Label, "Requires  ") then
			element.Label = string.gsub(element.Label, "  ", " ")
		end
	end

	if Features.ReplaceTooltipPlaceholders or (Features.FixChaosDamageDisplay or Features.FixCorrosiveMagicDamageDisplay) or Features.TooltipGrammarHelper then
		for i,element in pairs(tooltip:GetElements("SkillDescription")) do
			if element ~= nil then
				if Features.TooltipGrammarHelper == true then
					element.Label = string.gsub(element.Label, "a 8", "an 8")
					local startPos,endPos = string.find(element.Label , "a <font.->8")
					if startPos then
						local text = string.sub(element.Label, startPos, endPos)
						element.Label = string.gsub(element.Label, text, text:gsub("a ", "an "))
					end
				end
				if Features.FixChaosDamageDisplay == true and not string.find(element.Label:lower(), "chaos damage") then
					local startPos,endPos,damage = string.find(element.Label, chaosDamagePattern)
					if damage ~= nil then
						damage = string.gsub(damage, "%s+", "")
						local removeText = string.sub(element.Label, startPos, endPos):gsub("%-", "%%-")
						element.Label = string.gsub(element.Label, removeText, GameHelpers.GetDamageText("Chaos", damage))
					end
				end
				if Features.FixCorrosiveMagicDamageDisplay == true then
					local status,err = xpcall(function()
						local lowerLabel = string.lower(element.Label)
						local damageText = ""
						if string.find(lowerLabel, "corrosive damage") then
							damageText = "corrosive damage"
						elseif string.find(lowerLabel, "magic damage") then
							damageText = "magic damage"
						end
						if damageText ~= "" then
							local startPos,endPos = string.find(lowerLabel, "destroy <font.->[%d-]+ "..damageText..".-</font> on")
							print(startPos,endPos,damageText)
							if startPos and endPos then
								local str = string.sub(element.Label, startPos, endPos)
								local replacement = string.gsub(str, "Destroy","Deal"):gsub("destroy","deal"):gsub(" on"," to")
							element.Label = replacement..string.sub(element.Label, endPos+1)
							end
						end
						return true
					end, debug.traceback)
					if not status then
						print(err)
					end
				end
				if Features.ReplaceTooltipPlaceholders == true then
					element.Label = GameHelpers.Tooltip.ReplacePlaceholders(element.Label, character)
				end
			end
		end
	end
end

--- @param skill StatEntrySkillData
--- @param character StatCharacter
--- @param isFromItem boolean
--- @param param string
local function SkillGetDescriptionParam(skill, character, isFromItem, param1, param2)
	if character.Character ~= nil then UI.ClientCharacter = character.Character.MyGuid or character.NetID end
	if Features.ReplaceTooltipPlaceholders then
		if param1 == "ExtraData" then
			local value = Ext.ExtraData[param2]
			if value ~= nil then
				if value == math.floor(value) then
					return string.format("%i", math.floor(value))
				else
					if value <= 1.0 and value >= 0.0 then
						-- Percentage display
						value = value * 100
						return string.format("%i", math.floor(value))
					else
						return tostring(value)
					end
				end
			end
		end
	end
end

Ext.RegisterListener("SkillGetDescriptionParam", SkillGetDescriptionParam)

---@param status EsvStatus
---@param statusSource StatCharacter
---@param target StatCharacter
---@param param1 string
---@param param2 string
---@param param3 string
local function StatusGetDescriptionParam(status, statusSource, target, param1, param2, param3)
	if Features.StatusParamSkillDamage then
		if param1 == "Skill" and param2 ~= nil then
			if param3 == "Damage" then
				local success,result = xpcall(function()
					local skillSource = statusSource or target
					local damageSkillProps = GameHelpers.Ext.CreateSkillTable(param2)
					local damageRange = Game.Math.GetSkillDamageRange(skillSource, damageSkillProps)
					if damageRange ~= nil then
						local damageTexts = {}
						local totalDamageTypes = 0
						for damageType,damage in pairs(damageRange) do
							local min = damage.Min or damage[1]
							local max = damage.Max or damage[2]
							if min > 0 or max > 0 then
								if max == min then
									table.insert(damageTexts, GameHelpers.GetDamageText(damageType, string.format("%i", max)))
								else
									table.insert(damageTexts, GameHelpers.GetDamageText(damageType, string.format("%i-%i", min, max)))
								end
							end
							totalDamageTypes = totalDamageTypes + 1
						end
						if totalDamageTypes > 0 then
							if totalDamageTypes > 1 then
								return StringHelpers.Join(", ", damageTexts)
							else
								return damageTexts[1]
							end
						end
					end
				end, debug.traceback)
				if not success then
					Ext.PrintError(result)
				else
					return result
				end
			elseif param3 == "ExplodeRadius" then
				return tostring(Ext.StatGetAttribute(param2, param3))
			end
		end
	end
	if Features.ReplaceTooltipPlaceholders then
		if param1 == "ExtraData" then
			local value = Ext.ExtraData[param2]
			if value ~= nil then
				if value == math.floor(value) then
					return string.format("%i", math.floor(value))
				else
					if value <= 1.0 and value >= 0.0 then
						-- Percentage display
						value = value * 100
						return string.format("%i", math.floor(value))
					else
						return tostring(value)
					end
				end
			end
		end
	end
end

Ext.RegisterListener("StatusGetDescriptionParam", StatusGetDescriptionParam)

---@param character EclCharacter
---@param stat string
---@param tooltip TooltipData
local function OnStatTooltip(character, stat, tooltip)
	if character ~= nil then UI.ClientCharacter = character.MyGuid or character.NetID end
end

local tooltipSwf = {
	"Public/Game/GUI/LSClasses.swf",
	"Public/Game/GUI/tooltip.swf",
	"Public/Game/GUI/tooltipHelper.swf",
	"Public/Game/GUI/tooltipHelper_kb.swf",
}

local function ApplyLeading(tooltip_mc, element, amount)
	local val = 0
	if element then
		if amount == 0 or amount == nil then
			amount = tooltip_mc.m_Leading * 0.5
		end
		local heightPadding = 0
		if element.heightOverride then
			heightPadding = element.heightOverride / amount
		else
			heightPadding = element.height / amount
		end
		heightPadding = Ext.Round(heightPadding)
		if heightPadding <= 0 then
			heightPadding = 1
		end
		element.heightOverride = heightPadding * amount
	end
end

local function RepositionElements(tooltip_mc)
	--tooltip_mc.list.sortOnce("orderId",16,false)

	local leading = tooltip_mc.m_Leading * 0.5;
	local index = 0
	local element = nil
	local lastElement = nil
	while index < tooltip_mc.list.length do
		element = tooltip_mc.list.content_array[index]
		if element.list then
			element.list.positionElements()
		end
		if element == tooltip_mc.equipHeader then
			element.updateHeight()
		else
			if element.needsSubSection then
				if element.heightOverride == 0 or element.heightOverride == nil then
					element.heightOverride = element.height
				end
				--element.heightOverride = element.heightOverride + leading;
				element.heightOverride = element.heightOverride + leading
				if lastElement and not lastElement.needsSubSection then
					if lastElement.heightOverride == 0 or lastElement.heightOverride == nil then
						lastElement.heightOverride = lastElement.height
					end
					--lastElement.heightOverride = lastElement.heightOverride + leading;
					lastElement.heightOverride = lastElement.heightOverride + leading
				end
			end
			--tooltip_mc.applyLeading(element)
			ApplyLeading(tooltip_mc, element)
		end
		lastElement = element
		index = index + 1
	end
	--tooltip_mc.repositionElements()
	tooltip_mc.list.positionElements()
	tooltip_mc.resetBackground()
end

local function FormatTagElements(tooltip_mc, group, ...)
	group.iconId = 16
	--group.setupHeader()
	local groupHeight = 0
	local y = 0
	for i=0,#group.list.content_array,1 do
		local element = group.list.content_array[i]
		if element ~= nil then
			local b,result = xpcall(function()
				-- local icon = element.getChildAt(3) or element.getChildByName("tt_groupIcon")
				-- if icon ~= nil then
				-- 	icon.gotoAndStop(17)
				-- else
				-- 	element.removeChildAt(3)
				-- end
				element.removeChildAt(3) -- Removes the tag icon
				--element.removeChild(element.value_txt) -- Removes the tag icon

				element.label_txt.y = 0

				if element.value_txt.htmlText == "" then
					element.value_txt.y = 0
					element.value_txt.x = 0
					element.value_txt.height = 0
					element.value_txt.width = 0
				end
				element.warning_txt.y = 0
				element.label_txt.x = 0
				element.warning_txt.x = 0

				local tag = element.label_txt.htmlText
				local data = TagTooltips[tag]

				if data ~= nil then
					local tagName = ""
					if data.Title == nil then
						tagName = Ext.GetTranslatedStringFromKey(tag)
					else
						tagName = data.Title.Value
					end
					local tagDesc = ""
					if data.Description == nil then
						tagDesc = Ext.GetTranslatedStringFromKey(tag.."_Description")
					else
						tagDesc = data.Description.Value
					end
					tagName = GameHelpers.Tooltip.ReplacePlaceholders(tagName)
					tagDesc = GameHelpers.Tooltip.ReplacePlaceholders(tagDesc)
					-- The description gets loaded again so HTML formatting will be added (the swf tooltip function removes this normally).
					element.label_txt.autoSize = "none"
					element.warning_txt.autoSize = "none"
					element.value_txt.autoSize = "none"
					element.label_txt.y = element.label_txt.y + group.s_TextSpacing
					element.label_txt.htmlText = tagName
					element.warning_txt.htmlText = tagDesc
					element.warning_txt.y = element.label_txt.y + element.label_txt.textHeight
					
					groupHeight = groupHeight + math.ceil(element.label_txt.textHeight + element.warning_txt.textHeight) + -2
				end
			end, debug.traceback)
			if not b then
				print("[LeaderLib:FormatTagElements] Error:")
				print(result)
			end
		end
	end
	--group.heightOverride = math.ceil(element.label_txt.textHeight + element.warning_txt.textHeight) + (group.s_TextSpacing*2)
	group.heightOverride = groupHeight
	--tooltip_mc.list.positionElements()
	--tooltip_mc.resetBackground()
	--tooltip_mc.applyLeading(group)
	--tooltip_mc.repositionElements()
end


local lastItem = nil

local function AddTags(tooltip_mc)
	if lastItem == nil then
		return
	end
	if hasTagTooltip then
		local text = ""
		for tag,data in pairs(TagTooltips) do
			if lastItem:HasTag(tag) then
				local tagName = ""
				if data.Title == nil then
					tagName = Ext.GetTranslatedStringFromKey(tag)
				else
					tagName = data.Title.Value
				end
				local tagDesc = ""
				if data.Description == nil then
					tagDesc = Ext.GetTranslatedStringFromKey(tag.."_Description")
				else
					tagDesc = data.Description.Value
				end
				tagName = GameHelpers.Tooltip.ReplacePlaceholders(tagName)
				tagDesc = GameHelpers.Tooltip.ReplacePlaceholders(tagDesc)
				if text ~= "" then
					text = text .. "<br>"
				end
				text = text .. string.format("%s<br>%s", tagName, tagDesc)
			end
		end
		if text ~= "" then
			local group = tooltip_mc.addGroup(15)
			if group ~= nil then
				group.orderId = 0;
				group.addDescription(text)
				--group.addWhiteSpace(0,0)
			else
				print("Failed to create group")
			end
		end
	end
	lastItem = nil
end

local replaceText = {}

local function FormatTagText(tooltip_mc, group)
	local updatedText = false
	for i=0,#group.list.content_array,1 do
		local element = group.list.content_array[i]
		if element ~= nil then
			local b,result = xpcall(function()
				if element.label_txt ~= nil then
					local searchText = StringHelpers.Trim(element.label_txt.htmlText):gsub("[\r\n]", "")
					print(searchText)
					local tag = replaceText[searchText]
					local data = TagTooltips[tag]
					if data ~= nil then
						local tagName = ""
						if data.Title == nil then
							tagName = Ext.GetTranslatedStringFromKey(tag)
						else
							tagName = data.Title.Value
						end
						local tagDesc = ""
						if data.Description == nil then
							tagDesc = Ext.GetTranslatedStringFromKey(tag.."_Description")
						else
							tagDesc = data.Description.Value
						end
						tagName = GameHelpers.Tooltip.ReplacePlaceholders(tagName)
						tagDesc = GameHelpers.Tooltip.ReplacePlaceholders(tagDesc)
						element.label_txt.htmlText = string.format("<font color='#C7A758'>%s<br>%s</font>", tagName, tagDesc)
						--ApplyLeading(tooltip_mc, element)
						-- element.heightOverride = element.label_txt.textHeight + 200
						-- element.customElHeight = element.heightOverride
						-- group.list.m_NeedsSorting = true
						-- group.list.reOrderDepths()
						-- group.list.positionElements()
						updatedText = true
					end
					print(string.format("(%s) label_txt.htmlText(%s) color(%s)", group.groupID, element.label_txt.htmlText, element.label_txt.textColor))
				end
				return true
			end, debug.traceback)
			if not b then
				print("[LeaderLib:FormatTagElements] Error:")
				print(result)
			end
		end
	end
	if updatedText then
		group.iconId = 16
		group.setupHeader()
		--tooltip_mc.equipHeader.updateHeight()
		--tooltip_mc.list.m_NeedsSorting = true;
		--tooltip_mc.list.reOrderDepths()
		--tooltip_mc.list.positionElements()
		--RepositionElements(tooltip_mc)
		--tooltip_mc.resetBackground()
		--group.list.positionElements()
		--tooltip_mc.list.positionElements()
	end
end

local function FormatTagTooltip(ui, tooltip_mc, ...)
	--AddTags(tooltip_mc)
	local length = #tooltip_mc.list.content_array
	if length > 0 then
		for i=0,length,1 do
			local group = tooltip_mc.list.content_array[i]
			if group ~= nil then
				-- if group.groupID == 15 then
				-- 	group.orderId = 254
				-- 	--tooltip_mc.list.moveElementToPosition(i, length-3)
				-- 	print(group.orderId)
				-- end
				print(string.format("[%i] groupID(%i) orderId(%s) icon(%s)", i, group.groupID or -1, group.orderId or -1, group.iconId))
				if group.list ~= nil then
					FormatTagText(tooltip_mc, group)
				end
				-- if group.groupID == 13 and group.list ~= nil then
				-- 	FormatTagElements(tooltip_mc, group, ...)
				-- 	-- group.base is the LSTooltipClass
				-- 	--group.base.list.setFrame(group.width, 40)
				-- 	--group.base.middleBg_mc.height = 40
				-- 	--group.base.middleBg_mc.setBgWSubsections(group.base.width,group.base.height-40,group.base.list);
				-- 	RepositionElements(tooltip_mc)
				-- 	print(i, group.groupID, group.height, tooltip_mc.hasSubSections)
				-- end
			end
		end
	end
	--RepositionElements(tooltip_mc)
	--tooltip_mc.list.sortOnce("orderId",16,true)
	--tooltip_mc.list.redoSort()
	--tooltip_mc.list.m_SortOnFieldName = "orderId"
	--tooltip_mc.list.m_SortOnOptions = 16
	--tooltip_mc.list.INTSort()
	--tooltip_mc.list.content_array.sortOn(16, "orderId")
	-- tooltip_mc.list.positionElements()
	-- for i=0,#tooltip_mc.list.content_array do
	-- 	local element = tooltip_mc.list.content_array[i]
	-- 	if element ~= nil then
	-- 		print(i, element.groupID, element.orderId)
	-- 	else
	-- 		print(i, "null")
	-- 	end
	-- end
	--tooltip_mc.resetBackground()
	--tooltip_mc.repositionElements()
	--tooltip_mc.list.sortOnce("orderId",16,false);
end

local function OnTooltipPositioned(ui, ...)
	if hasTagTooltip or #UIListeners.OnTooltipPositioned > 0 then
		local root = ui:GetRoot()
		if root ~= nil then
			local tooltips = {}

			if root.formatTooltip ~= nil then
				tooltips[#tooltips+1] = root.formatTooltip.tooltip_mc
			end
			if root.compareTooltip ~= nil then
				tooltips[#tooltips+1] = root.compareTooltip.tooltip_mc
			end
			if root.offhandTooltip ~= nil then
				tooltips[#tooltips+1] = root.offhandTooltip.tooltip_mc
			end
	
			if #tooltips > 0 then
				for i,tooltip_mc in pairs(tooltips) do
					if Features.FormatTagElementTooltips then
						FormatTagTooltip(ui, tooltip_mc)
					end
					for i,callback in pairs(UIListeners.OnTooltipPositioned) do
						local status,err = xpcall(callback, debug.traceback, ui, tooltip_mc, ...)
						if not status then
							Ext.PrintError("[LeaderLib:AdjustTagElements] Error invoking callback:")
							Ext.PrintError(err)
						end
					end
				end
			end
		end
	end
end

local function AppendCharacter(str, char, amount)
	for i=0,amount do
		str = str .. char
	end
	return str
end

---@param item EsvItem
---@param tooltip TooltipData
local function OnItemTooltip(item, tooltip)
	--print(item.StatsId, Ext.JsonStringify(item.WorldPos), Ext.JsonStringify(tooltip.Data))
	if item ~= nil then
		lastItem = item
		if Features.FixItemAPCost == true then
			local character = nil
			if UI.ClientCharacter ~= nil then
				character = Ext.GetCharacter(UI.ClientCharacter)
			elseif item.ParentInventoryHandle ~= nil then
				character = Ext.GetCharacter(item.ParentInventoryHandle)
			end
			if character ~= nil then
				local apElement = tooltip:GetElement("ItemUseAPCost")
				if apElement ~= nil then
					local ap = apElement.Value
					if ap > 0 then
						for i,status in pairs(character:GetStatuses()) do
							if not Data.EngineStatus[status] then
								local potion = Ext.StatGetAttribute(status, "StatsId")
								if potion ~= nil and potion ~= "" then
									local apCostBoost = Ext.StatGetAttribute(potion, "APCostBoost")
									if apCostBoost ~= nil and apCostBoost ~= 0 then
										ap = math.max(0, ap + apCostBoost)
									end
								end
							end
						end
						apElement.Value = ap
					end
				end
			end
		end

		if Features.ResistancePenetration == true then
			-- Resistance Penetration display
			if item:HasTag("LeaderLib_HasResistancePenetration") then
				local tagsCheck = {}
				for _,damageType in Data.DamageTypes:Get() do
					local tags = Data.ResistancePenetrationTags[damageType]
					if tags ~= nil then
						local totalResPen = 0
						for i,tagEntry in pairs(tags) do
							if item:HasTag(tagEntry.Tag) then
								totalResPen = totalResPen + tagEntry.Amount
								tagsCheck[#tagsCheck+1] = tagEntry.Tag
							end
						end

						if totalResPen > 0 then
							local tString = LocalizedText.ItemBoosts.ResistancePenetration
							local resistanceText = GameHelpers.GetResistanceNameFromDamageType(damageType)
							local result = tString:ReplacePlaceholders(GameHelpers.GetResistanceNameFromDamageType(damageType))
							--PrintDebug(tString.Value, resistanceText, totalResPen, result)
							local element = {
								Type = "ResistanceBoost",
								Label = result,
								Value = totalResPen,
							}
							tooltip:AppendElement(element)
						end
					end
				end
				--print("ResPen tags:", Ext.JsonStringify(tagsCheck))
			end
		end
		if hasTagTooltip then
			for tag,data in pairs(TagTooltips) do
				if item:HasTag(tag) then
					local fulltext = ""
					local tagName = ""
					if data.Title == nil then
						tagName = Ext.GetTranslatedStringFromKey(tag)
					else
						tagName = data.Title.Value
					end
					local tagDesc = ""
					if data.Description == nil then
						tagDesc = Ext.GetTranslatedStringFromKey(tag.."_Description")
					else
						tagDesc = data.Description.Value
					end
					tagName = GameHelpers.Tooltip.ReplacePlaceholders(tagName)
					tagDesc = GameHelpers.Tooltip.ReplacePlaceholders(tagDesc)
					fulltext = string.format("%s<br>%s",tagName,tagDesc)
					tooltip:AppendElement({
						Type="StatsTalentsBoost",
						--Label=tag.."xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
						--Label=AppendCharacter(tag, "x", math.ceil(string.len(fulltext)*0.4))
						Label=fulltext
					})
					local searchText = fulltext:gsub("<font.->", ""):gsub("</font>", ""):gsub("<br>", "")
					print(searchText, tag)
					replaceText[searchText] = tag
				end
			end
		end
		if Features.TooltipGrammarHelper then
			local requirements = tooltip:GetElements("ItemRequirement")
			if requirements ~= nil then
				for i,element in pairs(requirements) do
					if string.find(element.Label, "Requires  ") then
						element.Label = string.gsub(element.Label, "  ", " ")
					end
				end
			end
		end
		if item:HasTag("LeaderLib_AutoLevel") then
			local element = tooltip:GetElement("ItemDescription")
			if element ~= nil and not string.find(element.Label, "Automatically levels") then
				if not StringHelpers.IsNullOrEmpty(element.Label) then
					element.Label = element.Label .. "<br>" .. AutoLevelingDescription.Value
				else
					element.Label = AutoLevelingDescription.Value
				end
			end
		end
		if Features.ReduceTooltipSize and Ext.IsDeveloperMode() then
			--print(Ext.JsonStringify(tooltip.Data))
			local elements = tooltip:GetElements("ExtraProperties")
			if elements ~= nil and #elements > 0 then
				local result = CondenseItemStatusText(tooltip, elements)
				if result ~= nil then
					local combined = {
						Type = "ExtraProperties",
						Label = result
					}
					tooltip:AppendElement(combined)
				end
			end
		end
	end
end

Ext.RegisterListener("SessionLoaded", function()
	Game.Tooltip.RegisterListener("Item", nil, OnItemTooltip)
	Game.Tooltip.RegisterListener("Skill", nil, OnSkillTooltip)
	Game.Tooltip.RegisterListener("Status", nil, OnStatusTooltip)
	Game.Tooltip.RegisterListener("Stat", nil, OnStatTooltip)

	Ext.RegisterUINameInvokeListener("showFormattedTooltipAfterPos", function(ui, ...)
		OnTooltipPositioned(ui)
	end)
end)

local function EnableTooltipOverride()
	--Ext.AddPathOverride("Public/Game/GUI/tooltip.swf", "Public/LeaderLib_543d653f-446c-43d8-8916-54670ce24dd9/GUI/tooltip.swf")
	Ext.AddPathOverride("Public/Game/GUI/LSClasses.swf", "Public/LeaderLib_543d653f-446c-43d8-8916-54670ce24dd9/GUI/LSClasses_Fixed.swf")
	--Ext.AddPathOverride("Public/Game/GUI/tooltipHelper_kb.swf", "Public/LeaderLib_543d653f-446c-43d8-8916-54670ce24dd9/GUI/tooltipHelper_kb_Fixed.swf")
	Ext.Print("[LeaderLib] Enabled tooltip override.")
end

if UI == nil then
	UI = {}
end

---Registers a tag to display on item tooltips.
---@param tag string
---@param title TranslatedString
---@param description TranslatedString
function UI.RegisterItemTooltipTag(tag, title, description)
	local data = {}
	if title ~= nil then
		data.Title = title
	end
	if description ~= nil then
		data.Description = description
	end
	TagTooltips[tag] = data
	hasTagTooltip = true
end

-- Ext.RegisterListener("ModuleLoading", EnableTooltipOverride)
-- Ext.RegisterListener("ModuleLoadStarted", EnableTooltipOverride)
-- Ext.RegisterListener("ModuleResume", EnableTooltipOverride)
-- Ext.RegisterListener("SessionLoading", EnableTooltipOverride)
-- Ext.RegisterListener("SessionLoaded", EnableTooltipOverride)