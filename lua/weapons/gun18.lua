-- Burst-X9: Burst-fire assault rifle (3-round bursts)
-- Dynamic spread system with crouch improvement

SWEP.PrintName = "Burst-X9"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — очередь из 3 патронов. Присядьте для большей точности."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 36
SWEP.Primary.DefaultClip = 144
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.25
SWEP.Primary.Damage = 18
SWEP.Primary.Recoil = 1.2
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.014
SWEP.Primary.MaxSpread = 0.065
SWEP.Primary.SpreadIncrease = 0.005
SWEP.Primary.SpreadRecovery = 0.025
SWEP.Primary.Force = 4

SWEP.CrouchSpreadMul = 0.35

SWEP.BurstCount = 3
SWEP.BurstDelay = 0.06

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 5
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 10

SWEP.ViewModel = "models/weapons/cstrike/c_rif_famas.mdl"
SWEP.WorldModel = "models/weapons/w_rif_famas.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("ar2")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
    self.Bursting = false
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
    if self.Bursting then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self.Bursting = true
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    self:EmitSound("Weapon_Famas.Single")

    for i = 1, self.BurstCount do
        timer.Simple((i - 1) * self.BurstDelay, function()
            if not IsValid(self) or not IsValid(owner) then
                self.Bursting = false
                return
            end
            if self:Clip1() <= 0 then
                self.Bursting = false
                self:Reload()
                return
            end

            local maxSpread = self:GetModifiedMaxSpread()
            self.CurrentSpread = math.min(
                (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease,
                maxSpread
            )
            self.LastFireTime = CurTime()

            self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self:GetModifiedSpread())
            self:TakePrimaryAmmo(1)
        end)
    end

    timer.Simple((self.BurstCount - 1) * self.BurstDelay + 0.05, function()
        if IsValid(self) then
            self.Bursting = false
        end
    end)
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
