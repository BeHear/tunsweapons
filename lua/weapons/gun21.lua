-- Heal-Beam: Heals teammates, damages enemies

SWEP.PrintName = "Heal-Beam"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — лечит союзников, наносит урон врагам."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 60
SWEP.Primary.DefaultClip = 240
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.08
SWEP.Primary.Damage = 15
SWEP.Primary.HealAmount = 8
SWEP.Primary.Recoil = 0.1
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.015
SWEP.Primary.MaxSpread = 0.04
SWEP.Primary.SpreadIncrease = 0.002
SWEP.Primary.SpreadRecovery = 0.015
SWEP.Primary.Force = 1

SWEP.CrouchSpreadMul = 0.4

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 4
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 3
SWEP.SlotPos = 3

SWEP.ViewModel = "models/weapons/cstrike/c_rif_m4a1.mdl"
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"
SWEP.UseHands = true

if SERVER then
    util.AddNetworkString("heal_beam_effect")
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

    self:EmitSound("weapons/airboat/airboat_gun_lastround.wav", 60, math.random(195, 210))
    self:FireHealBeam(self:GetModifiedSpread())
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

function SWEP:FireHealBeam(aimcone)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local shootPos = owner:GetShootPos()
    local aimDir = owner:GetAimVector()
    local ang = aimDir:Angle()
    ang:RotateAroundAxis(ang:Up(), math.Rand(-aimcone * 50, aimcone * 50))
    ang:RotateAroundAxis(ang:Right(), math.Rand(-aimcone * 50, aimcone * 50))
    local dir = ang:Forward()

    if SERVER then
        local tr = util.TraceLine({
            start = shootPos,
            endpos = shootPos + dir * 4096,
            filter = owner
        })

        local ent = tr.Entity
        if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC()) then
            local isFriend = false
            if ent:IsPlayer() and owner:IsPlayer() then
                if ent:GetFriendStatus() == "friend" then
                    isFriend = true
                end
            end

            if isFriend then
                -- Heal the friendly entity
                ent:SetHealth(math.min(ent:GetMaxHealth(), ent:Health() + self.Primary.HealAmount))
            else
                -- Damage the enemy
                local dmginfo = DamageInfo()
                dmginfo:SetDamage(self.Primary.Damage)
                dmginfo:SetAttacker(owner)
                dmginfo:SetInflictor(self)
                dmginfo:SetDamageType(DMG_ENERGYBEAM)
                dmginfo:SetDamageForce(dir * self.Primary.Force)
                ent:TakeDamageInfo(dmginfo)
            end
        end

        -- Send green tracer effect to clients
        net.Start("heal_beam_effect")
        net.WriteVector(shootPos)
        net.WriteVector(tr.HitPos)
        net.Broadcast()
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
    net.Receive("heal_beam_effect", function()
        local startPos = net.ReadVector()
        local hitPos = net.ReadVector()

        -- Green tracer
        local fx = EffectData()
        fx:SetStart(startPos)
        fx:SetOrigin(hitPos)
        fx:SetScale(1)
        util.Effect("ToolTracer", fx, true, true)
    end)
end
