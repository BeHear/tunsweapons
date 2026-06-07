-- Автомат "RS-15 Raven" — точный быстро стреляющий оружие на базе gun1.lua

SWEP.PrintName = "RS-15 Raven"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — автоматический огонь. Присядьте для высокой точности."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 45
SWEP.Primary.DefaultClip = 180
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.09
SWEP.Primary.Damage = 23
SWEP.Primary.Recoil = 1.05
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.016
SWEP.Primary.MaxSpread = 0.059
SWEP.Primary.SpreadIncrease = 0.0045
SWEP.Primary.SpreadRecovery = 0.022
SWEP.Primary.Force = 4

SWEP.CrouchSpreadMul = 0.33

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 5
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 4

SWEP.ViewModel = "models/weapons/cstrike/c_rif_m4a1.mdl"
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("ar2")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
end

function SWEP:GetModifiedSpread()
    if IsValid(self.Owner) and self.Owner:Crouching() then
        return (self.CurrentSpread or self.Primary.Spread) * self.CrouchSpreadMul
    end
    return self.CurrentSpread or self.Primary.Spread
end

function SWEP:GetModifiedBaseSpread()
    if IsValid(self.Owner) and self.Owner:Crouching() then
        return self.Primary.Spread * self.CrouchSpreadMul
    end
    return self.Primary.Spread
end

function SWEP:GetModifiedMaxSpread()
    if IsValid(self.Owner) and self.Owner:Crouching() then
        return self.Primary.MaxSpread * self.CrouchSpreadMul
    end
    return self.Primary.MaxSpread
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    local maxSpread = self:GetModifiedMaxSpread()
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease,
        maxSpread
    )
    self.LastFireTime = CurTime()

    self:EmitSound("Weapon_M4A1.Single")
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self:GetModifiedSpread())
    self:TakePrimaryAmmo(1)

    if IsValid(self.Owner) and self.Owner.ViewPunch then
        self.Owner:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
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
    local bullet = {}
    bullet.Num = num_bullets
    bullet.Src = self.Owner:GetShootPos()
    bullet.Dir = self.Owner:GetAimVector()
    bullet.Spread = Vector(aimcone, aimcone, 0)
    bullet.Tracer = 1
    bullet.TracerName = "Tracer"
    bullet.Force = self.Primary.Force
    bullet.Damage = damage
    bullet.AmmoType = self.Primary.Ammo

    self.Owner:FireBullets(bullet)
    self:ShootEffects()
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
    timer.Simple(self.Owner:GetViewModel():SequenceDuration(), function()
        if IsValid(self) then
            self.CurrentSpread = self.Primary.Spread
        end
    end)
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
