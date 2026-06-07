-- XT10-RPG - Мощное и быстрое ракетное оружие для Garry's Mod
-- Улучшенная версия с высоким уроном и скорострельностью

SWEP.PrintName = "XT10-RPG"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — Выпустить ракету. Быстро и мощно!"
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 32
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "rocket_rpg"
SWEP.Primary.Delay = 0.4 -- Очень быстро для RPG
SWEP.Primary.Damage = 250 -- Огромный урон
SWEP.Primary.Recoil = 5
SWEP.Primary.NumShots = 1
SWEP.Primary.Force = 50

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 10
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 4
SWEP.SlotPos = 2

SWEP.ViewModel = "models/weapons/cstrike/c_snip_scout.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"
SWEP.UseHands = true

SWEP.TracerName = "Tracer"

function SWEP:Initialize()
    self:SetHoldType("rpg")
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    self:EmitSound("Weapon_RPG.Single")
    
    -- Создаем ракету
    local ply = self.Owner
    if not IsValid(ply) then return end

    local pos = ply:GetShootPos()
    local ang = ply:GetAimVector():Angle()
    
    -- Создаем ракету
    local rocket = ents.Create("rocket_rpg")
    if not IsValid(rocket) then 
        self:TakePrimaryAmmo(1)
        self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
        return 
    end
    
    rocket:SetPos(pos)
    rocket:SetAngles(ang)
    rocket:SetOwner(ply)
    rocket:Spawn()
    
    -- Активируем физику ракеты
    local phys = rocket:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetVelocity(ply:GetAimVector() * 1500) -- Очень быстрая ракета
    end

    -- Добавляем отдачу
    ply:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
    
    self:TakePrimaryAmmo(1)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
end

function SWEP:Deploy()
    self:SetNextPrimaryFire(CurTime() + 0.5)
    return true
end
