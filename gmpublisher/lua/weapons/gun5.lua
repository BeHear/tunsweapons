SWEP.PrintName = "XT9 RPG"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — выстрелить ракетой. Перезарядитесь после выстрела."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 3
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "RPG_Round"
SWEP.Primary.Delay = 1.5
SWEP.Primary.Damage = 170
SWEP.Primary.Radius = 300
SWEP.Primary.Force = 8600 -- Для взрывной волны

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 8
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = false

SWEP.Slot = 4
SWEP.SlotPos = 1

-- Исправленные модельки на стандартные из HL2, чтобы не было еррора:
SWEP.ViewModel = "models/weapons/v_rpg.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("rpg")
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    if SERVER then
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local rocket = ents.Create("rpg_missile")
        if not IsValid(rocket) then return end

        rocket:SetPos(owner:GetShootPos() + owner:GetAimVector()*16 + owner:GetRight()*6)
        rocket:SetAngles(owner:EyeAngles())
        rocket:SetOwner(owner)
        rocket:Spawn()
        rocket:Activate()

        local phys = rocket:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(owner:GetAimVector() * 3400)
        end
    end

    self:EmitSound("Weapon_RPG.Single")
    self:ShootEffects()
    self:TakePrimaryAmmo(1)
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
