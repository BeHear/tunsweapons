-- Cryo-Zero: Freeze ray that slows enemies on hit
-- Does not deal direct damage, applies heavy slow effect

SWEP.PrintName = "Cryo-Zero"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — заморозить врагов. Замедляет движение и стрельбу."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 60
SWEP.Primary.DefaultClip = 240
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.08
SWEP.Primary.Damage = 0
SWEP.Primary.Recoil = 0.1
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.02
SWEP.Primary.MaxSpread = 0.045
SWEP.Primary.SpreadIncrease = 0.002
SWEP.Primary.SpreadRecovery = 0.015
SWEP.Primary.Force = 1

SWEP.CrouchSpreadMul = 0.4

SWEP.FreezeDuration = 1.5
SWEP.FreezeSlowAmount = 0.15

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 4
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 3
SWEP.SlotPos = 2

SWEP.ViewModel = "models/weapons/cstrike/c_rif_galil.mdl"
SWEP.WorldModel = "models/weapons/w_rif_galil.mdl"
SWEP.UseHands = true

if SERVER then
    util.AddNetworkString("cryo_freeze_effect")
end

function SWEP:Initialize()
    self:SetHoldType("ar2")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
end

function SWEP:GetModifiedSpread()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:Crouching() then
        return (self.CurrentSpread or self.Primary.Spread) * self.CrouchSpreadMul
    end
    return self.CurrentSpread or self.Primary.Spread
end

function SWEP:GetModifiedBaseSpread()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:Crouching() then
        return self.Primary.Spread * self.CrouchSpreadMul
    end
    return self.Primary.Spread
end

function SWEP:GetModifiedMaxSpread()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:Crouching() then
        return self.Primary.MaxSpread * self.CrouchSpreadMul
    end
    return self.Primary.MaxSpread
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local maxSpread = self:GetModifiedMaxSpread()
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease,
        maxSpread
    )
    self.LastFireTime = CurTime()

    self:EmitSound("ambient/atmosphere/steam1.wav", 70, math.random(130, 160))
    self:FireFreezeRay(self:GetModifiedSpread())
    self:TakePrimaryAmmo(1)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Think()
    if not self.LastFireTime then return end
    local baseSpread = self:GetModifiedBaseSpread()
    if (self.CurrentSpread or self.Primary.Spread) > baseSpread then
        self.CurrentSpread = math.max(
            baseSpread,
            (self.CurrentSpread or self.Primary.Spread) - self.Primary.SpreadRecovery * FrameTime()
        )
    end
end

function SWEP:FireFreezeRay(aimcone)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if not SERVER then return end

    local shootPos = owner:GetShootPos()
    local aimDir = owner:GetAimVector()
    local ang = aimDir:Angle()
    ang:RotateAroundAxis(ang:Up(), math.Rand(-aimcone * 50, aimcone * 50))
    ang:RotateAroundAxis(ang:Right(), math.Rand(-aimcone * 50, aimcone * 50))
    local dir = ang:Forward()

    local tr = util.TraceLine({
        start = shootPos,
        endpos = shootPos + dir * 4096,
        filter = owner
    })

    -- Send tracer effect to clients
    net.Start("cryo_freeze_effect")
    net.WriteVector(shootPos)
    net.WriteVector(tr.HitPos)
    net.Broadcast()

    -- Apply slow effect on hit entities
    local ent = tr.Entity
    if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC()) then
        -- Apply a slow via SetWalkSpeed/SetRunSpeed for players
        if ent:IsPlayer() then
            local origWalk = ent:GetWalkSpeed()
            local origRun = ent:GetRunSpeed()
            ent:SetWalkSpeed(origWalk * self.FreezeSlowAmount)
            ent:SetRunSpeed(origRun * self.FreezeSlowAmount)
            timer.Simple(self.FreezeDuration, function()
                if IsValid(ent) then
                    ent:SetWalkSpeed(origWalk)
                    ent:SetRunSpeed(origRun)
                end
            end)
        elseif ent:IsNPC() then
            -- For NPCs, apply a temporary stun
            local oldSchedule = ent:GetSchedule()
            ent:SetSchedule(SCHED_PANIC)
            timer.Simple(self.FreezeDuration, function()
                if IsValid(ent) then
                    ent:SetSchedule(oldSchedule)
                end
            end)
        end

        -- Visual effect on hit
        local fx = EffectData()
        fx:SetOrigin(tr.HitPos)
        fx:SetStart(shootPos)
        fx:SetNormal(tr.HitNormal)
        fx:SetScale(1)
        util.Effect("cball_explode", fx, true, true)
    end

    self:ShootEffects()
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local vm = owner:GetViewModel()
    if not IsValid(vm) then return end
    timer.Simple(vm:SequenceDuration(), function()
        if IsValid(self) then
            self.CurrentSpread = self.Primary.Spread
        end
    end)
end

function SWEP:SecondaryAttack()
end

if CLIENT then
    net.Receive("cryo_freeze_effect", function()
        local startPos = net.ReadVector()
        local hitPos = net.ReadVector()

        local fx = EffectData()
        fx:SetStart(startPos)
        fx:SetOrigin(hitPos)
        fx:SetScale(1)
        util.Effect("AirboatGunTracer", fx, true, true)

        -- Small blue explosion at hit point
        local fx2 = EffectData()
        fx2:SetOrigin(hitPos)
        fx2:SetScale(0.5)
        util.Effect("cball_explode", fx2, true, true)
    end)
end
