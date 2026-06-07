-- TRAIN weapon: where you shoot, a train will come and explode very hard there.
-- Server-side heavy explosive vehicle simulated by a fast-moving prop_physics.

SWEP.PrintName = "TRAIN"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — вызывать поезд к месту прицеливания. Поезд взрывается при достижении цели."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 5

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 10
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Slot = 1
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/crossbow.mdl"
SWEP.WorldModel = "models/props_trainstation/train001.mdl"
SWEP.UseHands = true

-- Train parameters (tweak as needed)
SWEP.TrainSpeed = 5000         -- units per second initial impulse
SWEP.TrainLifetime = 25        -- seconds before self-destruct
SWEP.TrainExplosiveRadius = 1400
SWEP.TrainExplosiveDamage = 2000
SWEP.TrainImpactSound = "ambient/explosions/explode_4.wav"

function SWEP:Initialize()
    self:SetHoldType("rpg")
end

function SWEP:PrimaryAttack()
    if CLIENT then return end
    if not self:CanPrimaryAttack() then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay or 1))

    -- Trace where player is aiming
    local tr = owner:GetEyeTrace()
    if not tr.Hit then
        owner:ChatPrint("TRAIN: нет цели для вызова поезда.")
        return
    end

    local targetPos = tr.HitPos

    -- Determine spawn position for train (behind player, a bit above)
    local spawnOffset = -owner:GetAimVector() * 300 + Vector(0,0,80)
    local spawnPos = owner:GetPos() + spawnOffset

    -- Create train prop
    local train = ents.Create("prop_physics")
    if not IsValid(train) then
        owner:ChatPrint("TRAIN: не удалось создать поезд (ents.Create failed).")
        return
    end

    -- Choose model (fallbacks in case model missing)
    local modelCandidates = {
        "models/props_trainstation/train001.mdl",
        "models/props_vehicles/train_engine.mdl",
        "models/Combine_Helicopter/helicopter_bomb01.mdl",
        "models/props_junk/propane_tank001a.mdl"
    }
    local chosenModel = modelCandidates[1]
    for _,m in ipairs(modelCandidates) do
        if util.IsValidModel(m) then chosenModel = m break end
    end

    train:SetModel(chosenModel)
    train:SetPos(spawnPos)
    train:SetAngles((targetPos - spawnPos):Angle())
    train:Spawn()

    -- Physics setup
    local phys = train:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(8000)
        phys:Wake()
        -- Give a very large initial velocity towards target
        local dir = (targetPos - spawnPos):GetNormalized()
        phys:SetVelocityInstantaneous(dir * (self.TrainSpeed or 4000))
    else
        -- If no physics, try moving it manually
        train:SetMoveType(MOVETYPE_NONE)
    end

    train:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)
    train:SetOwner(owner)

    -- Metadata for later
    train._TRAIN_TargetPos = targetPos
    train._TRAIN_Owner = owner
    train._TRAIN_StartTime = CurTime()

    local entIndex = train:EntIndex()
    local timerName = "TRAIN_Move_"..entIndex

    -- Safety: explode on contact (touched) — add callback
    train:AddCallback("PhysicsCollide", function(ent, data)
        -- If collision speed is high, explode
        if not IsValid(ent) then return end
        local speed = data.Speed or 0
        if speed > 200 then
            -- Prevent double-explode
            if ent._TRAIN_Exploded then return end
            ent._TRAIN_Exploded = true
            local pos = ent:GetPos()
            -- Explosion effect and damage
            local fx = EffectData()
            fx:SetOrigin(pos)
            util.Effect("Explosion", fx, true, true)
            ent:EmitSound(ent.TrainImpactSound or "ambient/explosions/explode_4.wav", 140, 100)
            util.BlastDamage(ent, ent._TRAIN_Owner or ent, pos, ent.TrainExplosiveRadius or 1400, ent.TrainExplosiveDamage or 2000)
            util.ScreenShake(pos, 9999, 255, 3, ent.TrainExplosiveRadius or 1400)
            SafeRemoveEntity(ent)
            timer.Remove(timerName)
        end
    end)

    -- Timed thinker that checks distance to target and lifetime
    timer.Create(timerName, 0.1, 0, function()
        if not IsValid(train) then timer.Remove(timerName) return end

        -- If reached target area, explode
        local curPos = train:GetPos()
        local dist = curPos:DistToSqr(train._TRAIN_TargetPos or targetPos)
        local hitRadius = 200 * 200 -- squared
        if dist <= hitRadius or (CurTime() - (train._TRAIN_StartTime or CurTime())) >= (self.TrainLifetime or 25) then
            if train._TRAIN_Exploded then
                timer.Remove(timerName)
                return
            end
            train._TRAIN_Exploded = true
            local pos = train:GetPos()
            local fx = EffectData()
            fx:SetOrigin(pos)
            util.Effect("Explosion", fx, true, true)
            train:EmitSound(train.TrainImpactSound or "ambient/explosions/explode_4.wav", 160, 100)
            util.BlastDamage(train, train._TRAIN_Owner or train, pos, train.TrainExplosiveRadius or 1400, train.TrainExplosiveDamage or 2000)
            util.ScreenShake(pos, 9999, 255, 3, train.TrainExplosiveRadius or 1400)
            SafeRemoveEntity(train)
            timer.Remove(timerName)
            return
        end

        -- Optionally, steer the train slightly towards target by applying velocity
        local phys2 = train:GetPhysicsObject()
        if IsValid(phys2) then
            local desiredVel = (train._TRAIN_TargetPos - curPos):GetNormalized() * (self.TrainSpeed or 5000)
            -- Smooth steering
            local curVel = phys2:GetVelocity()
            local newVel = LerpVector(0.12, curVel, desiredVel)
            phys2:SetVelocityInstantaneous(newVel)
        else
            -- If no physics, teleport forward a bit
            local forward = (train._TRAIN_TargetPos - curPos):GetNormalized()
            train:SetPos(curPos + forward * ((self.TrainSpeed or 5000) * 0.1))
        end
    end)

    -- Feedback to owner
    owner:EmitSound("buttons/button14.wav", 90, 100)
    owner:ChatPrint("TRAIN вызван. Поезд движется к месту прицеливания.")

    self:TakePrimaryAmmo(1)
    self:ShootEffects()
end

function SWEP:SecondaryAttack()
    -- нет вторичной функции
end
