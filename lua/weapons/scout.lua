-- Scout: Sniper rifle based on CS:Source Scout model
-- Version 1.3 addition

SWEP.PrintName = "Scout"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — выстрел. ПКМ — прицел. Мгновенное убийство в любой части тела."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 10
SWEP.Primary.DefaultClip = 60
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "357"
SWEP.Primary.Delay = 1.0
SWEP.Primary.Damage = 9999999 -- мгновенное убийство
SWEP.Primary.Recoil = 3
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0
SWEP.Primary.MaxSpread = 0
SWEP.Primary.SpreadIncrease = 0
SWEP.Primary.SpreadRecovery = 0
SWEP.Primary.Force = 80000

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 10
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 3
SWEP.SlotPos = 10

SWEP.ViewModel = "models/weapons/cstrike/c_snip_scout.mdl"
SWEP.WorldModel = "models/weapons/w_snip_scout.mdl"
SWEP.UseHands = true

SWEP.IronZoom = 0.3
SWEP.ScopeOverlay = Material("effects/combine/muzzleflash001.vmt")

function SWEP:Initialize()
    self:SetHoldType("ar2")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
    self.IronSighting = false
end

function SWEP:PrimaryAttack()
    if (not self:CanPrimaryAttack()) then return end
    self.LastFireTime = CurTime()

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:EmitSound("Weapon_Scout.Single")
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, 0)
    self:TakePrimaryAmmo(1)

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self.IronSighting = not self.IronSighting
    if self.IronSighting then
        owner:SetFOV(self.IronZoom, 0.2)
    else
        owner:SetFOV(0, 0.2)
    end

    self:SetNextSecondaryFire(CurTime() + 0.3)
end

function SWEP:ShootBullet(damage, num_bullets, aimcone)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local bullet = {}
    bullet.Num = num_bullets
    bullet.Src = owner:GetShootPos()
    bullet.Dir = owner:GetAimVector()
    bullet.Spread = Vector(0, 0, 0)
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

function SWEP:Holster()
    self.IronSighting = false
    local owner = self:GetOwner()
    if IsValid(owner) then
        owner:SetFOV(0, 0.1)
    end
    return true
end