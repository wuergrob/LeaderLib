--- This script tweaks Game.Math functions to allow lowering resistance with Resistance Penetration tags on items of the attacker.

--- @param character StatCharacter
--- @param type string DamageType enumeration
--- @param type resistancePenetration integer
local function GetResistance(character, type, resistancePenetration)
    if type == "None" or type == "Chaos" then
        return 0
	end
	
	local res = character[type .. "Resistance"]
	if res > 0 and resistancePenetration ~= nil and resistancePenetration > 0 then
		--PrintDebug(res, " => ", math.max(res - resistancePenetration, 0))
		res = math.max(res - resistancePenetration, 0)
	end

    return res
end

--- @param character StatCharacter
--- @param damageList DamageList
--- @param resistancePenetration table<string,integer>
local function ApplyHitResistances(character, damageList, resistancePenetration)
	for i,damage in pairs(damageList:ToTable()) do
        local resistance = GetResistance(character, damage.DamageType, resistancePenetration[damage.DamageType])
        damageList:Add(damage.DamageType, math.floor(damage.Amount * -resistance / 100.0))
    end
end

--- @param character StatCharacter
--- @param attacker StatCharacter
--- @param damageList DamageList
--- @param resistancePenetration table<string,integer>
local function ApplyDamageCharacterBonuses(character, attacker, damageList, resistancePenetration)
    damageList:AggregateSameTypeDamages()
    ApplyHitResistances(character, damageList, resistancePenetration)

    Game.Math.ApplyDamageSkillAbilityBonuses(damageList, attacker)
end

--- @param damageList DamageList
--- @param armor integer
local function ComputeArmorDamage(damageList, armor)
    local damage = damageList:GetByType("Corrosive") + damageList:GetByType("Physical") + damageList:GetByType("Sulfuric")
    return math.min(armor, damage)
end

--- @param damageList DamageList
--- @param magicArmor integer
local function ComputeMagicArmorDamage(damageList, magicArmor)
    local damage = damageList:GetByType("Magic") 
        + damageList:GetByType("Fire") 
        + damageList:GetByType("Water")
        + damageList:GetByType("Air")
        + damageList:GetByType("Earth")
        + damageList:GetByType("Poison")
    return math.min(magicArmor, damage)
end

local doHitOriginal = Game.Math.DoHit

local function ComputeOverridesEnabled()
    return Features.BackstabCalculation == true or Features.ResistancePenetration == true
end

local function WithinMeleeDistance(pos1, pos2)
    --print(GameSettings.Settings.BackstabSettings.MeleeSpellBackstabMaxDistance, GameHelpers.Math.GetDistance(pos1,pos2))
    return GameHelpers.Math.GetDistance(pos1,pos2) <= (GameSettings.Settings.BackstabSettings.MeleeSpellBackstabMaxDistance or 2.5)
end

---@param weapon StatItem
local function CanBackstabWithTwoHandedWeapon(weapon)
    return (GameSettings.Settings.BackstabSettings.AllowTwoHandedWeapons or not weapon.IsTwoHanded)
end

local function BackstabSpellMechanicsEnabled(attacker, hitType)
    local backstabSettings = GameSettings.Settings.BackstabSettings
    local settings = nil
    if attacker.IsPlayer then
        settings = GameSettings.Settings.BackstabSettings.Player
    else
        settings = GameSettings.Settings.BackstabSettings.NPC
    end
    if settings.SpellsCanBackstab then
        return true
    end
    return false
end

--- This parses the GameSettings options for backstab settings, allowing both players and NPCs to backstab with other weapons if the condition is right.
--- Lets the Backstab talent work. Also lets ranged weapons backstab if the game settings option MeleeOnly is disabled.
--- @param attacker StatCharacter
--- @param weapon StatItem
--- @param hitType string
local function CanBackstab(attacker, weapon, hitType, target)
    if (weapon ~= nil and weapon.WeaponType == "Knife") then
        return true
    end

    -- Enemy Upgrade Overhaul - Backstabber Upgrade
    if Ext.IsModLoaded("046aafd8-ba66-4b37-adfb-519c1a5d04d7") and not attacker.IsPlayer and weapon ~= nil and (attacker.TALENT_Backstab or attacker.TALENT_RogueLoreDaggerBackStab) then
        return true
    end

    local backstabSettings = GameSettings.Settings.BackstabSettings
    local settings = nil
    if attacker.IsPlayer then
        settings = GameSettings.Settings.BackstabSettings.Player
    else
        settings = GameSettings.Settings.BackstabSettings.NPC
    end

    if settings.Enabled then
        if not settings.TalentRequired or (settings.TalentRequired and (attacker.TALENT_Backstab or attacker.TALENT_RogueLoreDaggerBackStab)) then
            if weapon ~= nil then
                return not settings.MeleeOnly or (settings.MeleeOnly and not Game.Math.IsRangedWeapon(weapon) and CanBackstabWithTwoHandedWeapon(weapon))
            elseif settings.SpellsCanBackstab then
                if settings.MeleeOnly then
                    return hitType == "Melee" or WithinMeleeDistance(attacker.Position, target.Position)
                else
                    return true
                end
            end
        end
    end
    return false
end

--- @param hit HitRequest
--- @param damageList DamageList
--- @param statusBonusDmgTypes DamageList
--- @param hitType string HitType enumeration
--- @param target StatCharacter
--- @param attacker StatCharacter
function Game.Math.DoHit(hit, damageList, statusBonusDmgTypes, hitType, target, attacker)
    if not ComputeOverridesEnabled() then
        return doHitOriginal(hit, damageList, statusBonusDmgTypes, hitType, target, attacker)
    end
    hit.EffectFlags = hit.EffectFlags | Game.Math.HitFlag.Hit;
    damageList:AggregateSameTypeDamages()
	damageList:Multiply(hit.DamageMultiplier)
	
    local totalDamage = 0
    for i,damage in pairs(damageList:ToTable()) do
        totalDamage = totalDamage + damage.Amount
    end

    if totalDamage < 0 then
        damageList:Clear()
	end

	local resistancePenetration = {}
	
	if attacker ~= nil and attacker.Character ~= nil then
		---@type EsvItem[]
		local resPenItems = {}
		for i,itemId in pairs(attacker.Character:GetInventoryItems()) do
			---@type EsvItem
			local item = Ext.GetItem(itemId)
			--print(i, item.Slot, item.StatsId)
			if item.Slot < 15 and item:HasTag("LeaderLib_HasResistancePenetration") then
				resPenItems[#resPenItems+1] = item
			elseif item.Slot >= 15 then
				break
			end
		end
		if #resPenItems > 0 then
			for i,item in pairs(resPenItems) do
				for damageType,tags in pairs(Data.ResistancePenetrationTags) do
					for i,tagEntry in pairs(tags) do
						if item:HasTag(tagEntry.Tag) then
							if resistancePenetration[damageType] == nil then
								resistancePenetration[damageType] = 0
							end
							resistancePenetration[damageType] = resistancePenetration[damageType] + tagEntry.Amount
						end
					end
				end
			end
        end
        
        if attacker.Character:HasTag("LeaderLib_IgnoreUndeadPoisonResistance") and target.TALENT_Zombie then
            resistancePenetration["Poison"] = 200
        end
	end

    ApplyDamageCharacterBonuses(target, attacker, damageList, resistancePenetration)
    damageList:AggregateSameTypeDamages()
    hit.DamageList = Ext.NewDamageList()

    for i,damageType in pairs(statusBonusDmgTypes) do
        damageList.Add(damageType, math.ceil(totalDamage * 0.1))
    end

    Game.Math.ApplyDamagesToHitInfo(damageList, hit)
    hit.ArmorAbsorption = hit.ArmorAbsorption + ComputeArmorDamage(damageList, target.CurrentArmor)
    hit.ArmorAbsorption = hit.ArmorAbsorption + ComputeMagicArmorDamage(damageList, target.CurrentMagicArmor)

    if hit.TotalDamageDone > 0 then
        Game.Math.ApplyLifeSteal(hit, target, attacker, hitType)
    else
        --hit.EffectFlags = hit.EffectFlags | Game.Math.HitFlag.DontCreateBloodSurface
    end

    if hitType == "Surface" then
        --hit.EffectFlags = hit.EffectFlags | Game.Math.HitFlag.Surface
    end

    if hitType == "DoT" then
        --hit.EffectFlags = hit.EffectFlags | Game.Math.HitFlag.DoT
	end
	
	return hit
end

--- @param target StatCharacter
--- @param attacker StatCharacter
--- @param weapon StatItem
--- @param damageList DamageList
--- @param hitType string HitType enumeration
--- @param noHitRoll boolean
--- @param forceReduceDurability boolean
--- @param hit HitRequest
--- @param alwaysBackstab boolean
--- @param highGroundFlag string HighGround enumeration
--- @param criticalRoll string CriticalRoll enumeration
local function ComputeCharacterHit(target, attacker, weapon, damageList, hitType, noHitRoll, forceReduceDurability, hit, alwaysBackstab, highGroundFlag, criticalRoll)
    if ComputeOverridesEnabled() then
        hit.DamageMultiplier = 1.0
        local statusBonusDmgTypes = {}
        
        if attacker == nil then
            Game.Math.DoHit(hit, damageList, statusBonusDmgTypes, hitType, target, attacker)
            return hit
        end

        local backstabbed = false
        if weapon == nil then
            weapon = attacker.MainWeapon
        end
        
        if hitType == "Magic" and BackstabSpellMechanicsEnabled(attacker) then
            if alwaysBackstab or (CanBackstab(attacker, weapon, hitType, target) and Game.Math.CanBackstab(target, attacker)) then
                hit.EffectFlags = hit.EffectFlags | Game.Math.HitFlag.Backstab
                backstabbed = true
            end
        end

        hit.DamageMultiplier = 1.0 + Game.Math.GetAttackerDamageMultiplier(target, attacker, highGroundFlag)
        if hitType == "Magic" or hitType == "Surface" or hitType == "DoT" or hitType == "Reflected" then
            Game.Math.ConditionalApplyCriticalHitMultiplier(hit, target, attacker, hitType, criticalRoll)
            Game.Math.DoHit(hit, damageList, statusBonusDmgTypes, hitType, target, attacker)
            return hit
        end

        if alwaysBackstab or (CanBackstab(attacker, weapon, hitType, target) and Game.Math.CanBackstab(target, attacker)) then
            hit.EffectFlags = hit.EffectFlags | Game.Math.HitFlag.Backstab
            backstabbed = true
        end

        if hitType == "Melee" then
            if Game.Math.IsInFlankingPosition(target, attacker) then
                hit.EffectFlags = hit.EffectFlags | Game.Math.HitFlag.Flanking
            end
        
            -- Apply Sadist talent
            if attacker.TALENT_Sadist then
                if (hit.EffectFlags & Game.Math.HitFlag.Poisoned) ~= 0 then
                    table.insert(statusBonusDmgTypes, "Poison")
                end
                if (hit.EffectFlags & Game.Math.HitFlag.Burning) ~= 0 then
                    table.insert(statusBonusDmgTypes, "Fire")
                end
                if (hit.EffectFlags & Game.Math.HitFlag.Bleeding) ~= 0 then
                    table.insert(statusBonusDmgTypes, "Physical")
                end
            end
        end

        if attacker.TALENT_Damage then
            hit.DamageMultiplier = hit.DamageMultiplier + 0.1
        end

        local hitBlocked = false

        if not noHitRoll then
            local hitChance = Game.Math.CalculateHitChance(attacker, target)
            local hitRoll = math.random(0, 99)
            if hitRoll >= hitChance then
                if target.TALENT_RangerLoreEvasionBonus and hitRoll < hitChance + 10 then
                    hit.EffectFlags = hit.EffectFlags | Game.Math.HitFlag.Dodged
                else
                    hit.EffectFlags = hit.EffectFlags | Game.Math.HitFlag.Missed
                end
                hitBlocked = true
            else
                local blockChance = target.BlockChance
                if not backstabbed and blockChance > 0 and math.random(0, 99) < blockChance then
                    hit.EffectFlags = hit.EffectFlags | Game.Math.HitFlag.Blocked;
                    hitBlocked = true
                end
            end
        end

        if weapon ~= nil and weapon.Name ~= "DefaultWeapon" and hitType ~= "Magic" and forceReduceDurability and (hit.EffectFlags & (Game.Math.HitFlag.Missed|Game.Math.HitFlag.Dodged)) == 0 then
            Game.Math.ConditionalDamageItemDurability(attacker, weapon)
        end

        if not hitBlocked then
            Game.Math.ConditionalApplyCriticalHitMultiplier(hit, target, attacker, hitType, criticalRoll)
            Game.Math.DoHit(hit, damageList, statusBonusDmgTypes, hitType, target, attacker)
        end

        return hit
    end
end

Ext.RegisterListener("ComputeCharacterHit", ComputeCharacterHit)