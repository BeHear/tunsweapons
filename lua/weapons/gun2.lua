-- Основа: gun1.lua, оружие-пистолет с уникальными характеристиками

SWEP.PrintName = "EagleD"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — стрелять. Сильное одиночное оружие (ваншот в голову)."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 12
SWEP.Primary.DefaultClip = 96
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.Delay = 0.22
SWEP.Primary.Damage = 50
SWEP.Primary.Recoil = 2.5
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.009 -- Базовый минимальный разброс (уменьшено)
SWEP.Primary.MaxSpread = 0.022 -- Максимальный разброс (уменьшено)
SWEP.Primary.SpreadIncrease = 0.003 -- За выстрел (уменьшено)
SWEP.Primary.SpreadRecovery = 0.04 -- Восстановление в сек.
SWEP.Primary.Force = 6

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 2
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 1
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel = "models/weapons/w_pist_deagle.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("pistol")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
end

function SWEP:PrimaryAttack()
    if (not self:CanPrimaryAttack()) then return end

    -- Увеличиваем разброс
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease,
        self.Primary.MaxSpread
    )
    self.LastFireTime = CurTime()

    self:EmitSound("Weapon_Deagle.Single")
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self.CurrentSpread)
    self:TakePrimaryAmmo(1)

    -- self.Owner:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Think()
    -- Восстановление разброса
    if not self.LastFireTime then return end
    if (self.CurrentSpread or self.Primary.Spread) > self.Primary.Spread then
        self.CurrentSpread = math.max(
            self.Primary.Spread,
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

    bullet.Callback = function(attacker, tr, dmginfo)
        local ent = tr.Entity
        if IsValid(ent) and ent:IsPlayer() and tr.HitGroup == HITGROUP_HEAD then
            dmginfo:SetDamage(ent:Health() + 100)
        elseif IsValid(ent) and ent:IsNPC() and tr.HitGroup == HITGROUP_HEAD then
            dmginfo:SetDamage(ent:Health() + 100)
        end
    end

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
    end)
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки для пистолета
end
