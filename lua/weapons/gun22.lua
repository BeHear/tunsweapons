-- Hive-MG: Minigun with spin-up mechanics

SWEP.PrintName = "Hive-MG"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — раскрутка и стрельба. Чем дольше стреляешь, тем выше темп."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 200
SWEP.Primary.DefaultClip = 600
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.12
SWEP.Primary.MinDelay = 0.04
SWEP.Primary.SpinUpRate = 0.002
SWEP.Primary.Damage = 14
SWEP.Primary.Recoil = 2.5
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.03
SWEP.Primary.MaxSpread = 0.09
SWEP.Primary.SpreadIncrease = 0.003
SWEP.Primary.SpreadRecovery = 0.008
SWEP.Primary.Force = 8

SWEP.CrouchSpreadMul = 0.5

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 10
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 4
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/cstrike/c_mach_m249para.mdl"
SWEP.WorldModel = "models/weapons/w_mach_m249para.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("ar2")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
    self.CurrentDelay = self.Primary.Delay
    self.SpinningUp = false
    self.FireStartTime = 0
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

    -- Track when we started firing for spin-up
    if not self.SpinningUp then
        self.SpinningUp = true
        self.FireStartTime = CurTime()
        self.CurrentDelay = self.Primary.Delay
    end

    -- Spin-up: decrease delay the longer we fire
    local timeFiring = CurTime() - self.FireStartTime
    local delayReduction = timeFiring * self.Primary.SpinUpRate
    self.CurrentDelay = math.max(self.Primary.MinDelay, self.Primary.Delay - delayReduction)

    -- Increase spread the longer we fire
    local maxSpread = self:GetModifiedMaxSpread()
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease,
        maxSpread
    )
    self.LastFireTime = CurTime()

    self:EmitSound("weapons/func_tank/func_tank_fire_loop1.wav", 100, math.random(95, 105))

    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self:GetModifiedSpread())

    self:TakePrimaryAmmo(1)
    self:SetNextPrimaryFire(CurTime() + self.CurrentDelay)
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

function SWEP:Think()
    local owner = self:GetOwner()
    -- Reset spin-up when not firing
    if self.SpinningUp and IsValid(owner) and not owner:KeyDown(IN_ATTACK) then
        self.SpinningUp = false
        self.CurrentDelay = self.Primary.Delay
    end

    -- Recover spread
    if not self.LastFireTime then return end
    local baseSpread = self:GetModifiedBaseSpread()
    if (self.CurrentSpread or self.Primary.Spread) > baseSpread then
        self.CurrentSpread = math.max(
            baseSpread,
            (self.CurrentSpread or self.Primary.Spread) - self.Primary.SpreadRecovery * FrameTime()
        )
    end
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
            self.CurrentDelay = self.Primary.Delay
            self.SpinningUp = false
        end
    end)
end

function SWEP:SecondaryAttack()
end

function SWEP:Holster()
    self.SpinningUp = false
    self.CurrentDelay = self.Primary.Delay
    return true
end

function SWEP:Deploy()
    self.SpinningUp = false
    self.CurrentDelay = self.Primary.Delay
    return true
end
