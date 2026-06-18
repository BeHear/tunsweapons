-- Мощный дробовик для Garry's Mod, основанный на gun1.lua

SWEP.PrintName = "Ba-12 Shotgun"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — выстрел. Присядьте для большей кучности."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 32
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Buckshot"
SWEP.Primary.Delay = 0.85
SWEP.Primary.Damage = 13
SWEP.Primary.Recoil = 2.3
SWEP.Primary.NumShots = 7
SWEP.Primary.Spread = 0.045 -- базовый минимальный разброс
SWEP.Primary.MaxSpread = 0.11
SWEP.Primary.SpreadIncrease = 0.014 -- насколько разброс увеличивается за выстрел
SWEP.Primary.SpreadRecovery = 0.035 -- скорость восстановления разброса в секунду
SWEP.Primary.Force = 8

SWEP.CrouchSpreadMul = 0.48 -- уменьшение разброса при приседании

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 7
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 5

SWEP.ViewModel = "models/weapons/cstrike/c_shot_xm1014.mdl"
SWEP.WorldModel = "models/weapons/w_shot_xm1014.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("shotgun")
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
    if (not self:CanPrimaryAttack()) then return end

    -- Увеличиваем разброс при каждом выстреле (учитываем максимум с учетом приседания)
    local maxSpread = self:GetModifiedMaxSpread()
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease, 
        maxSpread
    )
    self.LastFireTime = CurTime()

    self:EmitSound("Weapon_XM1014.Single")
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self:GetModifiedSpread())
    self:TakePrimaryAmmo(1)

    -- Сильнее трясём экран (отдача выше)
    -- self.Owner:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Think()
    -- Постепенно восстанавливаем разброс, если не стреляем
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
    if self.Reloading then return end
    if self:Clip1() >= self.Primary.ClipSize then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if owner:GetAmmoCount(self.Primary.Ammo) <= 0 then return end

    self.Reloading = true
    self:InsertShell()
end

function SWEP:InsertShell()
    if not IsValid(self) then self.Reloading = false return end
    local owner = self:GetOwner()
    if not IsValid(owner) then self.Reloading = false return end
    if not self.Reloading then return end
    if self:Clip1() >= self.Primary.ClipSize or owner:GetAmmoCount(self.Primary.Ammo) <= 0 then
        self:FinishReload()
        return
    end

    self:SendWeaponAnim(ACT_VM_RELOAD)
    local vm = owner:GetViewModel()
    local delay = 0.45
    if IsValid(vm) then
        vm:ResetSequence(ACT_VM_RELOAD)
        delay = math.max(vm:SequenceDuration(), 0.3)
    end

    timer.Simple(delay, function()
        if not IsValid(self) or not IsValid(owner) or not self.Reloading then
            if IsValid(self) then self:FinishReload() end
            return
        end

        self:SetClip1(self:Clip1() + 1)
        owner:RemoveAmmo(1, self.Primary.Ammo)

        if self:Clip1() < self.Primary.ClipSize and owner:GetAmmoCount(self.Primary.Ammo) > 0 then
            self:InsertShell()
        else
            self:FinishReload()
        end
    end)
end

function SWEP:FinishReload()
    if IsValid(self) then
        self.Reloading = false
        self:SendWeaponAnim(ACT_VM_IDLE)
    end
end

function SWEP:CanPrimaryAttack()
    if self.Reloading then return false end
    return self:Clip1() > 0
end

function SWEP:Holster()
    self:FinishReload()
    return true
end

function SWEP:SecondaryAttack()
end
