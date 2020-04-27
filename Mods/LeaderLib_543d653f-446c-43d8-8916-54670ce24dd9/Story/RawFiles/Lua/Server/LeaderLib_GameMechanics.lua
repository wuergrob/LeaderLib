---Returns true if a hit isn't Dodged, Missed, or Blocked.
---Pass in an object if this is a status.
---@param target string
---@param handle integer
---@param is_hit integer
---@return boolean
local function HitSucceeded(target, handle, is_hit)
    if is_hit == 1 or is_hit == true then
        return NRD_HitGetInt(handle, "Dodged") == 0 and NRD_HitGetInt(handle, "Missed") == 0 and NRD_HitGetInt(handle, "Blocked") == 0
    else
        return NRD_StatusGetInt(target, handle, "Dodged") == 0 and NRD_StatusGetInt(target, handle, "Missed") == 0 and NRD_StatusGetInt(target, handle, "Blocked") == 0
    end
end

--Ext.NewQuery(HitSucceeded, "LeaderLib_Ext_QRY_HitSucceeded", "[in](GUIDSTRING)_Target, [in](INTEGER64)_Handle, [in](INTEGER)_IsHitType, [out](INTEGER)_Bool")

---Returns true if a hit is from a weapon.
---@param target string
---@param handle integer
---@param is_hit integer
---@return boolean
local function HitWithWeapon(target, handle, is_hit)
    local hit_type = -1
    local hitWithWeapon = false
    if is_hit == 1 or is_hit == true then
        hit_type = NRD_HitGetInt(handle, "HitType")
        hitWithWeapon = NRD_HitGetInt(handle, "HitWithWeapon") == 1
    else
        hit_type = NRD_StatusGetInt(target, handle, "HitReason")
        local source_type = NRD_StatusGetInt(target, handle, "DamageSourceType")
        hitWithWeapon = source_type == 6 or source_type == 7
    end
    return (hit_type == 0 or hit_type == 2 or hit_type == 3) and hitWithWeapon
end

--Ext.NewQuery(HitWithWeapon, "LeaderLib_Ext_QRY_HitWithWeapon", "[in](GUIDSTRING)_Target, [in](INTEGER64)_Handle, [in](INTEGER)_IsHitType, [out](INTEGER)_Bool")

---Reduce damage by a percentage (ex. 0.5)
---@param target string
---@param attacker string
---@param handle_param integer
---@param reduction_perc number
---@param is_hit_param integer
---@return boolean
local function ReduceDamage(target, attacker, handle_param, reduction_perc, is_hit_param)
    local handle = Common.SafeguardParam(handle_param, "integer", nil)
    if handle == nil then error("[LeaderLib_GameMechanics.lua:ReduceDamage] Handle is null! Skipping.") end
    local reduction = Common.SafeguardParam(reduction_perc, "number", 0.5)
    local is_hit = Common.SafeguardParam(is_hit_param, "integer", 0)
	PrintDebug("[LeaderLib_GameMechanics.lua:ReduceDamage] Reducing damage to ("..tostring(reduction)..") of total. Handle("..tostring(handle).."). Target("..tostring(target)..") Attacker("..tostring(attacker)..") IsHit("..tostring(is_hit)..")")
	local success = false
    for k,v in pairs(Data.DamageTypes) do
        local damage = nil
        if is_hit == 0 then
            damage = NRD_HitStatusGetDamage(target, handle, v)
        else
            damage = NRD_HitGetDamage(handle, v)
        end
        if damage ~= nil and damage > 0 then
            --local reduced_damage = math.max(math.ceil(damage * reduction), 1)
            --NRD_HitStatusClearDamage(target, handle, v)
            local reduced_damage = (damage * reduction) * -1
            if is_hit == 0 then
                NRD_HitStatusAddDamage(target, handle, v, reduced_damage)
            else
                NRD_HitAddDamage(handle, v, reduced_damage)
            end
			Log("[LeaderLib_GameMechanics.lua:ReduceDamage] Reduced damage: "..tostring(damage).." => "..tostring(reduced_damage).." for type: "..v)
			success = true
        end
	end
	return success
end

Ext.NewCall(ReduceDamage, "LeaderLib_Hit_ReduceDamage", "(GUIDSTRING)_Target, (GUIDSTRING)_Attacker, (INTEGER64)_Handle, (REAL)_Percentage, (INTEGER)_IsHitHandle")

---Increase damage by a percentage (0.5).
---@param target string
---@param attacker string
---@param handle_param integer
---@param increase_perc number
---@param is_hit_param integer
---@return boolean
local function IncreaseDamage(target, attacker, handle_param, increase_perc, is_hit_param)
    local handle = Common.SafeguardParam(handle_param, "number", nil)
    if handle == nil then error("[LeaderLib_GameMechanics.lua:IncreaseDamage] Handle is null! Skipping.") end
    local increase_amount = Common.SafeguardParam(increase_perc, "number", 0.5)
    local is_hit = Common.SafeguardParam(is_hit_param, "number", 0)
	Log("[LeaderLib_GameMechanics.lua:IncreaseDamage] Increasing damage by ("..tostring(increase_amount).."). Handle("..tostring(handle).."). Target("..tostring(target)..") Attacker("..tostring(attacker)..") IsHit("..tostring(is_hit)..")")
	local success = false
    for k,v in pairs(Data.DamageTypes) do
        local damage = nil
        if is_hit == 0 then
            damage = NRD_HitStatusGetDamage(target, handle, v)
        else
            damage = NRD_HitGetDamage(handle, v)
        end
        if damage ~= nil and damage > 0 then
            --local increased_damage = damage + math.ceil(damage * increase_amount)
            --NRD_HitStatusClearDamage(target, handle, v)
            local increased_damage = math.ceil(damage * increase_amount)
            if is_hit == 0 then
                NRD_HitStatusAddDamage(target, handle, v, increased_damage)
            else
                NRD_HitAddDamage(handle, v, increased_damage)
            end
			Log("[LeaderLib_GameMechanics.lua:IncreaseDamage] Increasing damage: "..tostring(damage).." => "..tostring(damage + increased_damage).." for type: "..v)
			success = true
        end
	end
	return success
end

Ext.NewCall(IncreaseDamage, "LeaderLib_Hit_IncreaseDamage", "(GUIDSTRING)_Target, (GUIDSTRING)_Attacker, (INTEGER64)_Handle, (REAL)_Percentage, (INTEGER)_IsHitHandle")

---Redirect damage to another target.
---@param target string
---@param defender string
---@param attacker string
---@param handle_param integer
---@param reduction_perc number
---@param is_hit_param integer
---@return boolean
local function RedirectDamage(target, defender, attacker, handle_param, reduction_perc, is_hit_param)
    local handle = Common.SafeguardParam(handle_param, "integer", nil)
    if handle == nil then error("[LeaderLib_GameMechanics.lua:RedirectDamage] Handle is null! Skipping.") end
    local reduction = Common.SafeguardParam(reduction_perc, "number", 0.5)
    local is_hit = Common.SafeguardParam(is_hit_param, "integer", 0)
	Log("[LeaderLib_GameMechanics.lua:RedirectDamage] Reducing damage to ("..tostring(reduction)..") of total. Handle("..tostring(handle).."). Target("..tostring(target)..") Defender("..tostring(defender)..") Attacker("..tostring(attacker)..") IsHit("..tostring(is_hit)..")")
    --if CanRedirectHit(defender, handle, hit_type) then -- Ignore surface, DoT, and reflected damage
    --local hit_type_name = NRD_StatusGetString(defender, handle, "DamageSourceType")
    --local hit_type = NRD_StatusGetInt(defender, handle, "HitType")
    --Log("[LeaderLib_GameMechanics.lua:RedirectDamage] Redirecting damage Handle("..handlestr.."). Blocker(",target,") Target(",defender,") Attacker(",attacker,")")
    local redirected_hit = NRD_HitPrepare(target, attacker)
    local damageRedirected = false

    for k,v in pairs(Data.DamageTypes) do
        local damage = nil
        if is_hit == 0 then
            damage = NRD_HitStatusGetDamage(defender, handle, v)
        else
            damage = NRD_HitGetDamage(handle, v)
        end
        if damage ~= nil and damage > 0 then
            local reduced_damage = math.max(math.ceil(damage * reduction), 1)
            --NRD_HitStatusClearDamage(defender, handle, v)
            local removed_damage = damage * -1
            if is_hit == 0 then
                NRD_HitStatusAddDamage(defender, handle, v, removed_damage)
            else
                NRD_HitAddDamage(handle, v, removed_damage)
            end
            NRD_HitAddDamage(redirected_hit, v, reduced_damage)
            Log("[LeaderLib_GameMechanics.lua:RedirectDamage] Redirected damage: "..tostring(damage).." => "..tostring(reduced_damage).." for type: "..v)
            damageRedirected = true
        end
    end

    if damageRedirected then
        local is_crit = 0
        if is_hit == 0 then
            is_crit = NRD_StatusGetInt(defender, handle, "CriticalHit") == 1
        else
            is_crit = NRD_HitGetInt(handle, "CriticalHit") == 1
        end
        if is_crit then
            NRD_HitSetInt(redirected_hit, "CriticalRoll", 1);
        else
            NRD_HitSetInt(redirected_hit, "CriticalRoll", 2);
        end
        NRD_HitSetInt(redirected_hit, "SimulateHit", 1);
        NRD_HitSetInt(redirected_hit, "HitType", 6);
        NRD_HitSetInt(redirected_hit, "Hit", 1);
        NRD_HitSetInt(redirected_hit, "NoHitRoll", 1);
        NRD_HitExecute(redirected_hit);
	end
	return damageRedirected;
end

Ext.NewCall(RedirectDamage, "LeaderLib_Hit_RedirectDamage", "(GUIDSTRING)_Target, (GUIDSTRING)_Defender, (GUIDSTRING)_Attacker, (INTEGER64)_Handle, (REAL)_Percentage, (INTEGER)_IsHitHandle")

---Get a skill's slot and cooldown, and store it in DB_LeaderLib_Helper_Temp_RefreshUISkill.
---@param char string
---@param skill string
local function StoreSkillData(char, skill)
    local slot = NRD_SkillBarFindSkill(char, skill)
    if slot ~= nil then
        local success,cd = pcall(NRD_SkillGetCooldown, char, skill)
        if success == false or cd == nil then cd = 0.0; end
        cd = math.max(cd, 0.0)
        --Osi.LeaderLib_RefreshUI_Internal_StoreSkillData(char, skill, slot, cd)
        Osi.DB_LeaderLib_Helper_Temp_RefreshUISkill(char, skill, slot, cd)
        NRD_SkillBarClear(char, slot)
        Osi.LeaderLog_Log("DEBUG", "[lua:LeaderLib_RefreshSkill] Refreshing (" .. tostring(skill) ..") for (" .. tostring(char) .. ") [" .. tostring(cd) .. "]")
    end
 end

local function StoreSkillSlots(char)
	-- Until we can fetch the active skill bar, iterate through every skill slot for now
   for i=0,144 do
	   local skill = NRD_SkillBarGetSkill(char, i)
	   if skill ~= nil then
		   local success,cd = pcall(NRD_SkillGetCooldown, char, skill)
		   if success == false or cd == nil then cd = 0.0 end;
		   cd = math.max(cd, 0.0)
		   Osi.LeaderLib_RefreshUI_Internal_StoreSkillData(char, skill, i, cd)
		   Osi.LeaderLog_Log("DEBUG", "[lua:LeaderLib_RefreshSkills] Storing skill slot data (" .. tostring(skill) ..") for (" .. tostring(char) .. ") [" .. tostring(cd) .. "]")
	   end
   end
end

---Sets a skill into an empty slot, or finds empty space.
local function TrySetSkillSlot(char, slot, addskill)
    if type(slot) == "string" then
        slot = math.tointeger(slot)
    end
    if slot == nil or slot < 0 then slot = 0 end
    local skill = NRD_SkillBarGetSkill(char, slot)
    if skill == nil then
        NRD_SkillBarSetSkill(char, slot, addskill)
        return true
    elseif skill == addskill then
        return true
    else
        local maxslots = 144 - slot
        local nextslot = slot + 1
        while nextslot < maxslots do
            skill = NRD_SkillBarGetSkill(char, nextslot)
            if skill == nil then
                NRD_SkillBarSetSkill(char, slot, addskill)
                return true
            elseif skill == addskill then
                return true
            end
            nextslot = nextslot + 1
        end
    end
    return false
end
Ext.NewCall(TrySetSkillSlot, "LeaderLib_Ext_TrySetSkillSlot", "(CHARACTERGUID)_Character, (INTEGER)_Slot, (STRING)_Skill")

---Refreshes a skill if the character has it.
local function RefreshSkill(char, skill)
    if CharacterHasSkill(char, skill) == 1 then
        NRD_SkillSetCooldown(skill, 0.0)
    end
end
Ext.NewCall(RefreshSkill, "LeaderLib_Ext_RefreshSkill", "(CHARACTERGUID)_Character, (STRING)_Skill")

---Clone an item for a character.
---@param char string
---@param item string
---@param completion_event string
---@param autolevel string
local function CloneItemForCharacter(char, item, completion_event, autolevel)
    local autolevel_enabled = autolevel == "Yes"
	NRD_ItemCloneBegin(item)
    local cloned = NRD_ItemClone()
    if autolevel_enabled then
        local level = CharacterGetLevel(char)
        ItemLevelUpTo(cloned,level)
    end
    CharacterItemSetEvent(char, cloned, completion_event)
end

---Creates an item by stat, using cloning.
---@param stat string
---@param level integer
---@return string
local function CreateItemByStat(stat, level)
    local x,y,z = GetPosition(CharacterGetHostCharacter())
    local item = CreateItemTemplateAtPosition("LOOT_LeaderLib_BackPack_Invisible_98fa7688-0810-4113-ba94-9a8c8463f830",x,y,z)
    NRD_ItemCloneBegin(item)
    NRD_ItemCloneSetString("GenerationStatsId", stat)
    NRD_ItemCloneSetString("StatsEntryName", stat)
    NRD_ItemCloneSetInt("HasGeneratedStats", 0)
    NRD_ItemCloneSetInt("StatsLevel", level)
    --NRD_ItemCloneResetProgression()
    local cloned NRD_ItemClone()
    ItemLevelUpTo(cloned,level)
    return cloned
end

local function ExplodeProjectile(source, target, skill)
    local level = 1
    if ObjectIsCharacter(source) == 1 then
        level = CharacterGetLevel(source)
    else
        SetStoryEvent(source, "LeaderLib_Commands_SetItemLevel")
        level = GetVarInteger(source, "LeaderLib_Level")
    end
    local x,y,z = GetPosition(target)
    NRD_ProjectilePrepareLaunch();
    NRD_ProjectileSetString("SkillId", skill);
    NRD_ProjectileSetInt("CasterLevel", level);
    NRD_ProjectileSetGuidString("SourcePosition", target);
    NRD_ProjectileSetGuidString("Caster", source);
    NRD_ProjectileSetGuidString("Source", source);
    NRD_ProjectileSetGuidString("HitObject", target);
    NRD_ProjectileSetGuidString("HitObjectPosition", target);
    NRD_ProjectileSetGuidString("TargetPosition", target);
    NRD_ProjectileLaunch();
    PrintDebug("Exploded projectile ("..skill..") at ("..target..")")
end

--Ext.NewCall(ExplodeProjectile, "LeaderLib_Ext_ExplodeProjectile", "(GUIDSTRING)_Source, (GUIDSTRING)_Target, (STRING)_Skill")

function EquipInSlot(char, item, slot)
    if Ext.Version() >= 42 then
        NRD_CharacterEquipItem(char, item, slot, 0, 0, 1, 1)
    else
        CharacterEquipItem(char, item)
    end
end

function ItemIsEquipped(char, item)
    local itemObj = Ext.GetItem(item)
    if itemObj ~= nil then
        local slot = itemObj.Slot
        if slot <= 13 then -- 13 is the Overhead slot
            return true
        end
    else
        for i,slot in pairs(Data.EquipmentSlots) do
            if CharacterGetEquippedItem(char, slot) == item then
                return true
            end
        end
    end
    return false
end

---Removes matching rune templates from items in any equipment slots.
---@param character string
---@param runeTemplates table
local function RemoveRunes(character, runeTemplates)
	for _,slotName in pairs(VisibleEquipmentSlots) do
		local item = CharacterGetEquippedItem(character, slotName)
		if item ~= nil then
			for runeSlot=0,2,1 do
				local runeTemplate = ItemGetRuneItemTemplate(item, runeSlot)
				if runeTemplate ~= nil and runeTemplates[runeTemplate] == true then
					local rune = ItemRemoveRune(character, item, runeSlot)
					PrintDebug("[LeaderLib:RemoveRunes] Removed rune ("..tostring(rune)..") from item ("..item..")["..tostring(runeSlot).."] for character ("..character..")")
				end
			end
		end
	end
end

Game.ReduceDamage = ReduceDamage
Game.IncreaseDamage = IncreaseDamage
Game.HitSucceeded = HitSucceeded
Game.HitWithWeapon = HitWithWeapon
Game.RedirectDamage = RedirectDamage
Game.StoreSkillData = StoreSkillData
Game.StoreSkillSlots = StoreSkillSlots
Game.TrySetSkillSlot = TrySetSkillSlot
Game.RefreshSkill = RefreshSkill
Game.CloneItemForCharacter = CloneItemForCharacter
Game.ExplodeProjectile = ExplodeProjectile
Game.RemoveRunes = RemoveRunes