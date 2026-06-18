-- Glock-17: High-caliber pistol based on CS:Source Glock model
-- Heavier hitting than the Glock-18

SWEP.PrintName = "Glock-17"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — стрелять. Присядьте для большей точности."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 17
SWEP.Primary.DefaultClip = 102
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.Delay = 0.22
SWEP.Primary.Damage = 19
SWEP.Primary.Recoil = 1.9
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.013
SWEP.Primary.MaxSpread = 0.038
SWEP.Primary.SpreadIncrease = 0.003
SWEP.Primary.SpreadRecovery = 0.028
SWEP.Primary.Force = 6

SWEP.CrouchSpreadMul = 0.35

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 2
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 1
SWEP.SlotPos = 5

SWEP.ViewModel = "models/weapons/cstrike/c_pist_glock18.mdl"
SWEP.WorldModel = "models/weapons/w_pist_glock18.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("pistol")
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
    if (not self:CanPrimaryAttack()) then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local maxSpread = self:GetModifiedMaxSpread()
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease,
        maxSpread
    )
    self.LastFireTime = CurTime()

    self:EmitSound("Weapon_Glock.Single")
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self:GetModifiedSpread())
    self:TakePrimaryAmmo(1)

    if owner.ViewPunch then
        owner:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
    end

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
        self.LastFireTime = CurTime()
    end
end

function SWEP:ShootBullet(damage, num_bullets, aimcone)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local bullet = {}
    bullet.Num = num_bullets
    bullet.Src = owner:GetShootPos()
    bullet.Dir = owner:GetAimVector()
    bullet.Spread = Vector(aimcone, aimcone, 0)
    bullet.Tracer = 1
    bullet.TracerName = "Tracer"
    bullet.Force = self.Primary.Force
    bullet.Damage = damage
    bullet.AmmoType = self.Primary.Ammo

    owner:FireBullets(bullet)
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
