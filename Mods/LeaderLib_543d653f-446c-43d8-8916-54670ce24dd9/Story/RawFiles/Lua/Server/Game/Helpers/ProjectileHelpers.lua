function GameHelpers.ShootProjectile(source, target, skill, forceHit, sourcePosition)
    local level = 1
    if ObjectIsCharacter(source) == 1 then
        level = CharacterGetLevel(source)
    else
        level = Ext.GetItem(source).Stats.Level
    end

    NRD_ProjectilePrepareLaunch()

    NRD_ProjectileSetString("SkillId", skill)
    NRD_ProjectileSetInt("CasterLevel", level)

    NRD_ProjectileSetGuidString("Caster", source)
    NRD_ProjectileSetGuidString("Source", source)

    local x,y,z = GetPosition(source)
    if sourcePosition == nil then
        NRD_ProjectileSetVector3("SourcePosition", x,y+2,z)
    else
        NRD_ProjectileSetVector3("SourcePosition", sourcePosition[1],sourcePosition[2],sourcePosition[3])
    end

    if type(target) == "string" then
        if forceHit == true then
            NRD_ProjectileSetGuidString("HitObject", target)
            NRD_ProjectileSetGuidString("HitObjectPosition", target)
        end
        NRD_ProjectileSetGuidString("TargetPosition", target)
    elseif type(target) == "table" then
        local tx,ty,tz = table.unpack(target)
        if tx == nil then
            tx = x
        end
        if ty == nil then
            ty = y
        end
        if tz == nil then
            tz = z
        end
        if forceHit == true then
            NRD_ProjectileSetVector3("HitObjectPosition", tx,ty,tz)
        end
        NRD_ProjectileSetVector3("TargetPosition", tx,ty,tz)
    end
    NRD_ProjectileLaunch()
end

function GameHelpers.ShootProjectileAtPosition(source, tx, ty, tz, skill, forceHit)
    local level = 1
    if ObjectIsCharacter(source) == 1 then
        level = CharacterGetLevel(source)
    else
        SetStoryEvent(source, "LeaderLib_Commands_SetItemLevel")
        level = GetVarInteger(source, "LeaderLib_Level")
    end
    NRD_ProjectilePrepareLaunch()
    NRD_ProjectileSetString("SkillId", skill)
    NRD_ProjectileSetInt("CasterLevel", level)

    NRD_ProjectileSetGuidString("Caster", source)
    NRD_ProjectileSetGuidString("Source", source)
    NRD_ProjectileSetVector3("TargetPosition", tx,ty,tz)

    if forceHit == true then
        NRD_ProjectileSetGuidString("SourcePosition", source)
        NRD_ProjectileSetVector3("HitObjectPosition", tx,ty,tz)
    else
        local x,y,z = GetPosition(source)
        NRD_ProjectileSetVector3("SourcePosition", x,y+2,z)
    end
    NRD_ProjectileLaunch()
end

function GameHelpers.ExplodeProjectile(source, target, skill)
    local level = 1
    if ObjectIsCharacter(source) == 1 then
        level = CharacterGetLevel(source)
    else
        SetStoryEvent(source, "LeaderLib_Commands_SetItemLevel")
        level = GetVarInteger(source, "LeaderLib_Level")
    end
    NRD_ProjectilePrepareLaunch()
    NRD_ProjectileSetString("SkillId", skill)
    NRD_ProjectileSetInt("CasterLevel", level)
    NRD_ProjectileSetGuidString("Caster", source)
    NRD_ProjectileSetGuidString("Source", source)

    if type(target) == "string" then
        NRD_ProjectileSetGuidString("SourcePosition", target)
        NRD_ProjectileSetGuidString("HitObject", target)
        NRD_ProjectileSetGuidString("HitObjectPosition", target)
        NRD_ProjectileSetGuidString("TargetPosition", target)
    elseif type(target) == "table" then
        -- Exploding at a position
        local x,y,z = GetPosition(source)
        local tx,ty,tz = table.unpack(target)
        if tx == nil then
            tx = x
        end
        if ty == nil then
            ty = y
        end
        if tz == nil then
            tz = z
        end
        NRD_ProjectileSetVector3("SourcePosition", tx,ty,tz)
        NRD_ProjectileSetVector3("HitObjectPosition", tx,ty,tz)
        NRD_ProjectileSetVector3("TargetPosition", tx,ty,tz)
    end
    NRD_ProjectileLaunch()
end