local global_settings = {}

---@class LeaderLibIntegerVariable
local LeaderLibIntegerVariable = { 
	name = "",
	value = 0,
	defaultValue = 0
}

LeaderLibIntegerVariable.__index = LeaderLibIntegerVariable

---@param name string
---@param defaultValue integer
function LeaderLibIntegerVariable:Create(name,defaultValue)
    local this =
    {
		name = name,
		value = defaultValue,
		defaultValue = defaultValue
	}
	setmetatable(this, self)
    return this
end

---@class LeaderLibFlagVariable
local LeaderLibFlagVariable = {
	name = "",
	saveWhenFalse = false
}

LeaderLibFlagVariable.__index = LeaderLibFlagVariable

function LeaderLibFlagVariable:Create(name)
    local this =
    {
		name = name
	}
	setmetatable(this, self)
    return this
end

---@class LeaderLibModSettings
local LeaderLibModSettings = {
	name = "",
	author = "",
	globalflags = {},
	integers = {},
	version = -1,
	uuid = ""
}

LeaderLibModSettings.__index = LeaderLibModSettings

function LeaderLibModSettings:Create(uuid)
    local this =
    {
		name = "",
		author = "",
		globalflags = {},
		integers = {},
		uuid = uuid
	}
	if Common.StringIsNullOrEmpty(uuid) == false and Ext.IsModLoaded(uuid) then
		local modinfo = Ext.GetModInfo(uuid)
		if modinfo ~= nil then
			this.name = modinfo.Name
			this.author = modinfo.Author
			this.version = tonumber(modinfo.Version)
		end
	end
	setmetatable(this, self)
    return this
end

local function do_addflags(tbl, x)
	if type(x) == "string" then
		tbl[x] = LeaderLibFlagVariable:Create(x)
	elseif type(x) == "table" then
		for _,y in ipairs(x) do
			do_addflags(tbl, y)
		end
	end
end

function LeaderLibModSettings:AddFlags(...)
	local flags = {...}
	local target = self.globalflags
	for _,f in ipairs(flags) do
		do_addflags(target, f)
	end
	self.globalflags = target
	--PrintDebug("Test: " .. Common.Dump(self))
end

function LeaderLibModSettings:Export()
	--PrintDebug("Exporting: " .. Common.Dump(self))
	local export_table = LeaderLibModSettings:Create(self.uuid)
	export_table.version = self.version
	table.sort(self.globalflags)
	for flag,v in pairs(self.globalflags) do
		if GlobalGetFlag(flag) == 1 then
			export_table.globalflags[flag] = true
		elseif v.saveWhenFalse == true or Ext.IsModLoaded(self.uuid) == false then
			export_table.globalflags[flag] = false
		end
		--PrintDebug("Flag: " .. flag .. " | " .. GlobalGetFlag(flag))
	end
	if Ext.IsModLoaded(self.uuid) then
		local last_pricemod = GetGlobalPriceModifier()
		for name,v in pairs(self.integers) do
			SetGlobalPriceModifier(123456)
			if self.uuid ~= nil and self.uuid ~= "" then
				Osi.LeaderLib_GlobalSettings_Internal_GetIntegerVariable(self.uuid, name)
			else
				Osi.LeaderLib_GlobalSettings_Internal_GetIntegerVariable_Old(self.name, self.author, name)
			end
			local int_value = GetGlobalPriceModifier()
			if int_value ~= 123456 then
				export_table.integers[name] = int_value
				--GlobalClearFlag("LeaderLib_Internal_GlobalSettings_IntegerVarSet")
			end
			--PrintDebug("Got int var ("..name..") Value ("..int_value..")")
		end
		SetGlobalPriceModifier(last_pricemod)
		--PrintDebug("GlobalPriceModifier reverted back to ("..GetGlobalPriceModifier()..")")
	else
		export_table.name = self.name
		export_table.author = self.author
		for name,v in pairs(self.integers) do
			if v ~= nil then
				export_table.integers[name] = v
			else
				Ext.PrintError("[LeaderLib:GlobalSettings.lua:LeaderLibModSettings:Export] [*ERROR*] Global Integer ("..tostring(name)..") has no value.")
			end
		end
	end
	return export_table
end

---@class LeaderLibGlobalSettings
local LeaderLibGlobalSettings = { 
	mods = {}
}

LeaderLibGlobalSettings.__index = LeaderLibGlobalSettings

function LeaderLibGlobalSettings:Create()
    local this =
    {
		mods = {}
	}
	
	for _,v in ipairs(global_settings) do
		local export = v:Export()
		this.mods[#this.mods+1] = export
	end
	
	table.sort(this.mods, function(a,b)
		if a.name ~= nil and b.name ~= nil then
			return string.upper(a.name) < string.upper(b.name)
		else
			return false
		end
	end)
	
	setmetatable(this, self)
    return this
end

---Fetches stored settings, or returns a new settings table.
---@param uuid string
---@return LeaderLibModSettings
local function Get_Settings(uuid)
	if #global_settings > 0 then
		for _,v in pairs(global_settings) do
			if v.uuid == uuid then
				return v
			end
		end
	end
	local new_settings = LeaderLibModSettings:Create(uuid)
	global_settings[#global_settings+1] = new_settings
	return new_settings
end

local function TryGetUUID(modid, author)
	local loadOrder = Ext.GetModLoadOrder()
	for _,uuid in pairs(loadOrder) do
		local mod = Ext.GetModInfo(uuid)
		if Common.StringEquals(modid, mod.Name) and Common.StringEquals(author, mod.Author) then
			return uuid
		end
	end
	return ""
end

---Fetches stored settings, or returns a new settings table.
---@param modid string
---@param author string
---@return LeaderLibModSettings
local function Get_Settings_Old(modid, author)
	if #global_settings > 0 then
		for _,v in pairs(global_settings) do
			if v.name ~= nil and v.author ~= nil and author ~= nil and modid ~= nil then
				if Common.StringEquals(v.name, modid) and Common.StringEquals(v.author, author) then
					return v
				end
			end
		end
	end
	local uuid = TryGetUUID(modid, author)
	local new_settings = LeaderLibModSettings:Create(uuid)
	if uuid == "" then
		new_settings.name = modid
		new_settings.author = author
	end
	global_settings[#global_settings+1] = new_settings
	return new_settings
end

---@param uuid string
---@param flag string
function GlobalSettings_StoreGlobalFlag(uuid, flag, saveWhenFalse)
	if flag ~= nil then
		local mod_settings = Get_Settings(uuid)
		if mod_settings ~= nil then
			local flagvar = LeaderLibFlagVariable:Create(flag)
			if saveWhenFalse == "1" or saveWhenFalse == true then flagvar.saveWhenFalse = true end
			mod_settings.globalflags[flag] = flagvar
		else
			Ext.PrintError("[LeaderLib:GlobalSettings.lua:StoreGlobalFlag] [*ERROR]* Failed to find settings for UUID ("..tostring(uuid)..").")
		end
	end
end

---@param uuid string
---@param varname string
---@param defaultvalue string
function GlobalSettings_StoreGlobalInteger(uuid, varname, defaultvalue)
	--PrintDebug("[LeaderLib:GlobalSettings.lua:StoreGlobalInteger] Storing int: ", uuid, varname, defaultvalue)
	local mod_settings = Get_Settings(uuid)
	if mod_settings ~= nil then
		if mod_settings["integers"] == nil then
			mod_settings.integers = {}
		end
		mod_settings.integers[varname] = tonumber(defaultvalue)
	else
		Ext.PrintError("[LeaderLib:GlobalSettings.lua:StoreGlobalInteger] [*ERROR*] Failed to find settings for UUID ("..tostring(uuid)..").")
	end
end

---@param modid string
---@param author string
---@param flag string
function GlobalSettings_StoreGlobalFlag_Old(modid, author, flag, saveWhenFalse)
	if flag ~= nil then
		local mod_settings = Get_Settings_Old(modid, author)
		if mod_settings ~= nil then
			local flagvar = LeaderLibFlagVariable:Create(flag)
			if saveWhenFalse == "1" or saveWhenFalse == true then flagvar.saveWhenFalse = true end
			mod_settings.globalflags[flag] = flagvar
		else
			Ext.PrintError("[LeaderLib:GlobalSettings.lua:StoreGlobalFlag_Old] [*ERROR*] Failed to find settings for ("..tostring(modid)..","..tostring(author)..").")
		end
	end
end

---@param modid string
---@param author string
---@param varname string
---@param defaultvalue string
function GlobalSettings_StoreGlobalInteger_Old(modid, author, varname, defaultvalue)
	--PrintDebug("[LeaderLib:GlobalSettings.lua:StoreGlobalInteger_Old] Storing int: ", modid, author, varname, defaultvalue)
	local mod_settings = Get_Settings_Old(modid, author)
	if mod_settings ~= nil then
		mod_settings.integers[varname] = math.tointeger(defaultvalue)
	else
		Ext.PrintError("[LeaderLib:GlobalSettings.lua:StoreGlobalInteger_Old] [*ERROR*] Failed to find settings for UUID ("..tostring(modid)..","..tostring(author)..").")
	end
end

---@param uuid string
function GlobalSettings_GetAndStoreModVersion(uuid)
	local mod_settings = Get_Settings(uuid)
	local modinfo = Ext.GetModInfo(uuid)
	mod_settings.version = tonumber(modinfo.Version)
end

---@param uuid string
---@param version string
function GlobalSettings_StoreModVersion(uuid, version)
	local mod_settings = Get_Settings(uuid)
	if mod_settings ~= nil then
		mod_settings.version = math.tointeger(version)
	else
		Ext.PrintError("[LeaderLib:GlobalSettings.lua:StoreModVersion] [*ERROR*] Failed to find settings for UUID ("..tostring(uuid)..").")
	end
end

---@param modid string
---@param author string
function GlobalSettings_StoreModVersion_Old(modid, author, version_str)
	local mod_settings = Get_Settings_Old(modid, author)
	if mod_settings ~= nil then
		if mod_settings.uuid ~= "" then
			local mod_settings = Get_Settings(mod_settings.uuid)
			local modinfo = Ext.GetModInfo(mod_settings.uuid)
			mod_settings.version = tonumber(modinfo.Version)
		else
			mod_settings.version = VersionStringToVersionInteger(version_str, -1)
			PrintDebug("[LeaderLib:GlobalSettings.lua:StoreModVersion_Old] Transformed " .. version_str .. " into "..tostring(mod_settings.version))
		end
	else
		Ext.PrintError("[LeaderLib:GlobalSettings.lua:StoreModVersion_Old] [*ERROR*] Failed to find settings for ("..tostring(modid)..","..tostring(author)..").")
	end
end

local function parse_mod_data(uuid, modid, author, tbl)
	--Store settings for deactivated mods
	if Common.StringIsNullOrEmpty(uuid) == false and Ext.IsModLoaded(uuid) == false then
		local mod_settings = Get_Settings(uuid)
		if mod_settings ~= nil then
			mod_settings.name = modid
			mod_settings.author = author
			if mod_settings.version <= -1 and tbl["version"] ~= nil then
				mod_settings.version = math.tointeger(tbl["version"])
			end
			PrintDebug("[LeaderLib:GlobalSettings.lua] Configured global mod settings for deactivated mod (".. tostring(modid)..","..tostring(author)..")")
		end
	end

	local flags = tbl["globalflags"]
	if flags ~= nil and type(flags) == "table" then
		for flag,v in pairs(flags) do
			--PrintDebug("[LeaderLib:GlobalSettings.lua] Found global flag ("..flag..")["..tostring(v).."] for mod ["..uuid.."](".. modid.."|"..author..")")
			if v == false then
				if GlobalGetFlag(flag) == 1 then GlobalClearFlag(flag) end
			else
				if GlobalGetFlag(flag) == 0 then GlobalSetFlag(flag) end
			end
			local saveWhenFalse = v == false
			if Common.StringIsNullOrEmpty(uuid) == false then
				--GlobalSettings_StoreGlobalInteger(uuid, name, author, varname, defaultvalue)
				GlobalSettings_StoreGlobalFlag(uuid, flag, saveWhenFalse)
			else
				GlobalSettings_StoreGlobalFlag_Old(modid, author, flag, saveWhenFalse)
			end
		end
	end
	local integers = tbl["integers"]
	if integers ~= nil and type(integers) == "table" then
		for varname,v in pairs(integers) do
			local intnum = math.tointeger(v)
			if intnum == nil then intnum = 0 end
			--PrintDebug("[LeaderLib:GlobalSettings.lua] Found global integer variable ("..varname..")["..tostring(intnum).."] for mod (".. modid.."|"..author..")")
			if Common.StringIsNullOrEmpty(uuid) == false then
				Osi.LeaderLib_GlobalSettings_SetIntegerVariable(uuid, varname, intnum)
				--GlobalSettings_StoreGlobalInteger(uuid, name, author, varname, defaultvalue)
				GlobalSettings_StoreGlobalInteger(uuid, varname, tostring(intnum))
			else
				Osi.LeaderLib_GlobalSettings_SetIntegerVariable(modid, author, varname, intnum)
				--GlobalSettings_StoreGlobalInteger_Old(modid, author, varname, defaultvalue)
				GlobalSettings_StoreGlobalInteger_Old(modid, author, varname, tostring(intnum))
			end
		end
	end
	return true
end

local function parse_settings(tbl)
	for k,v in pairs(tbl) do
		if Common.StringEquals(k, "mods") then
			for k2,v2 in pairs(v) do
				local modid = v2["name"]
				local author = v2["author"]
				local uuid = v2["uuid"]
				local canParse = Common.StringIsNullOrEmpty(uuid) == false or (Common.StringIsNullOrEmpty(modid) == false and Common.StringIsNullOrEmpty(author) == false)
				if canParse then
					xpcall(parse_mod_data, function(err)
						PrintDebug("[LeaderLib:GlobalSettings.lua] Error parsing mod data in global settings: ", err)
						PrintDebug(debug.traceback())
						return false
					end, uuid, modid, author, v2)
				end
			end
		end
	end
end

local function LoadGlobalSettings_Run()
	local json = NRD_LoadFile("LeaderLib_GlobalSettings.json")
	if json ~= nil and json ~= "" then
		--PrintDebug("[LeaderLib:GlobalSettings.lua] Loading global settings. {" .. json .. "}")
		local json_tbl = Ext.JsonParse(json)
		PrintDebug("[LeaderLib:GlobalSettings.lua] Loaded global settings.")
		parse_settings(json_tbl)
	else
		PrintDebug("[LeaderLib:GlobalSettings.lua] No global settings found.")
	end
	return true
end

local function LoadGlobalSettings_Error (x)
	PrintDebug("[LeaderLib:GlobalSettings.lua] Error loading global settings: ", x)
	return false
end

function LoadGlobalSettings()
	if (xpcall(LoadGlobalSettings_Run, LoadGlobalSettings_Error)) then
		PrintDebug("[LeaderLib:GlobalSettings.lua] Loaded global settings.")
	end
end

local function SaveGlobalSettings_Run()
	local export_settings = LeaderLibGlobalSettings:Create()
	--PrintDebug(Common.Dump(export_settings))
	local mods = export_settings.mods
	if #mods > 0 then
		local json = Ext.JsonStringify(export_settings)
		NRD_SaveFile("LeaderLib_GlobalSettings.json", json)
		--PrintDebug("[LeaderLib:GlobalSettings.lua] Saved global settings. {" .. json .. "}")
		PrintDebug("[LeaderLib:GlobalSettings.lua] Saved global settings.")
	else
		PrintDebug("[LeaderLib:GlobalSettings.lua] No global settings to save. Skipping.")
	end
	return true
end

local function SaveGlobalSettings_Error (x)
	Ext.PrintError("[LeaderLib:GlobalSettings.lua] Error saving global settings: ", x)
	Ext.PrintError(debug.traceback())
	return false
end

function SaveGlobalSettings()
	if (xpcall(SaveGlobalSettings_Run, SaveGlobalSettings_Error)) then
		PrintDebug("[LeaderLib:GlobalSettings.lua] Saved global settings.")
	end
end

function GlobalSettings_Initialize()
	Osi.LeaderLib_GlobalSettings_Internal_Init()
end