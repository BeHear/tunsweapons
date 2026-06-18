-- Основа: gun1.lua — модернизированный скорострельный пистолет-пулемет "MK-SMG"
-- Динамический разброс и восстановление как у автомата, но другие параметры баланса
-- В этой версии добавлен скин для оружия

SWEP.PrintName = "Mk-Smg 67"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — скоростной огонь. Приседайте для высокой точности."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 50
SWEP.Primary.DefaultClip = 200
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.08
SWEP.Primary.Damage = 17
SWEP.Primary.Recoil = 0.7
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.018  -- Базовый минимальный разброс
SWEP.Primary.MaxSpread = 0.055  -- Максимальный разброс
SWEP.Primary.SpreadIncrease = 0.0038 -- Насколько разброс увеличивается за выстрел
SWEP.Primary.SpreadRecovery = 0.025 -- Восстановление разброса в сек.
SWEP.Primary.Force = 3

SWEP.CrouchSpreadMul = 0.32 -- Во сколько раз уменьшается разброс при приседании

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 4
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 2

SWEP.ViewModel = "models/weapons/cstrike/c_smg_mp5.mdl"
SWEP.WorldModel = "models/weapons/w_smg_mp5.mdl"
SWEP.ViewModelSkin = 1 -- номер скина для вьюмодели (0 по умолчанию)
SWEP.WorldModelSkin = 1 -- номер скина для ворлдмодели (0 по умолчанию)
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("smg")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
end

-- Установка скинов при появлении в мире
function SWEP:Deploy()
    -- Для viewmodel
    if IsValid(self.Owner) and CLIENT then
        local vm = self.Owner:GetViewModel()
        if IsValid(vm) and self.ViewModelSkin then
            vm:SetSkin(self.ViewModelSkin)
        end
    end
    -- Для worldmodel (на сервере)
    if SERVER and IsValid(self) and self.WorldModelSkin then
        self:SetSkin(self.WorldModelSkin)
    end
    return true
end

if CLIENT then
    -- На случай если игрок достал оружие с другого скина
    function SWEP:PreDrawViewModel(vm)
        if self.ViewModelSkin then
            vm:SetSkin(self.ViewModelSkin)
        end
    end
end

function SWEP:Equip(newOwner)
    -- Для worldmodel (на сервере)
    if SERVER and IsValid(self) and self.WorldModelSkin then
        self:SetSkin(self.WorldModelSkin)
    end
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

    local maxSpread = self:GetModifiedMaxSpread()
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease, 
        maxSpread
    )
    self.LastFireTime = CurTime()

    self:EmitSound("Weapon_MP5Navy.Single")
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self:GetModifiedSpread())
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
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local vm = owner:GetViewModel()
    if not IsValid(vm) then return end
    timer.Simple(vm:SequenceDuration(), function()
        if IsValid(self) then
            self.CurrentSpread = self.Primary.Spread
        end
        if CLIENT then
            local owner2 = self:GetOwner()
            if IsValid(owner2) then
                local vm2 = owner2:GetViewModel()
                if IsValid(vm2) and self.ViewModelSkin then
                    vm2:SetSkin(self.ViewModelSkin)
                end
            end
        end
    end)
    if SERVER and IsValid(self) and self.WorldModelSkin then
        self:SetSkin(self.WorldModelSkin)
    end
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
