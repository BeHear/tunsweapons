-- Админское оружие "Admin Gun" на базе gun2.lua с максимальным уроном, скорострельностью и без разброса

SWEP.PrintName = "Ba-97"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — уничтожает всё. Только для админов."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminOnly = true -- Только для админов
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 800
SWEP.Primary.DefaultClip = 8000
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 1 / 120 -- 80 выстрелов в секунду
SWEP.Primary.Damage = 9999999 -- Максимальный урон
SWEP.Primary.Recoil = 0
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0 -- Без разброса
SWEP.Primary.MaxSpread = 0
SWEP.Primary.SpreadIncrease = 0
SWEP.Primary.SpreadRecovery = 0
SWEP.Primary.Force = 800000

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 0
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 0
SWEP.SlotPos = 0

SWEP.ViewModel = "models/weapons/cstrike/c_rif_ak47.mdl"
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("ar2")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    self:EmitSound("Weapon_AR2.Single")
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self.Primary.Spread)
    self:TakePrimaryAmmo(1)

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
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

    -- Для красоты, всегда наносить крит-урон при выстреле в голову игроку
    bullet.Callback = function(attacker, tr, dmginfo)
        local ent = tr.Entity
        if IsValid(ent) and ent:IsPlayer() and tr.HitGroup == HITGROUP_HEAD then
            dmginfo:SetDamage(999999)
        end
    end

    self.Owner:FireBullets(bullet)
    self:ShootEffects()
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
end

function SWEP:CanPrimaryAttack()
    if self:Clip1() <= 0 and self.Primary.ClipSize > 0 then return false end
    return true
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
