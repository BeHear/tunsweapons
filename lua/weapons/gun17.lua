SWEP.PrintName = "Killer"
SWEP.Author = "GPT"
SWEP.Instructions = "Наведите прицел на NPC и нажмите на него, чтобы мгновенно его убить."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 90
SWEP.Primary.DefaultClip = 360
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.2

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 5
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel = "models/weapons/w_pist_deagle.mdl"
SWEP.UseHands = true

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local tr = owner:GetEyeTrace()
    local ent = tr.Entity

    if IsValid(ent) and ent:IsNPC() and tr.HitPos:DistToSqr(owner:GetShootPos()) < 1000000 then
        ent:TakeDamage(ent:Health() + 100, owner, self)
        self:EmitSound("Weapon_AWP.Single", 80, 100)
        local effect = EffectData()
        effect:SetOrigin(ent:GetPos() + Vector(0,0,40))
        util.Effect("StunstickImpact", effect, true, true)
    else
        self:EmitSound("Weapon_Pistol.Empty", 60, 100)
    end
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
