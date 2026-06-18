-- Gravity Hammer: Melee weapon that knocks enemies back

SWEP.PrintName = "Gravity Hammer"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — мощный удар с отбрасыванием."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "None"
SWEP.Primary.Delay = 0.5
SWEP.Primary.Damage = 40
SWEP.Primary.Force = 5000

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 6
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 5

SWEP.ViewModel = "models/weapons/c_stunstick.mdl"
SWEP.WorldModel = "models/weapons/w_stunbaton.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("melee")
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:EmitSound("weapons/stunstick/stunstick_swing1.wav", 100, 80)
    self:ShootEffects()

    if not SERVER then return end

    local shootPos = owner:GetShootPos()
    local aimDir = owner:GetAimVector()

    local tr = util.TraceLine({
        start = shootPos,
        endpos = shootPos + aimDir * 96,
        filter = owner,
        mask = MASK_SHOT
    })

    if not tr.Hit then
        -- Check a wider arc for melee (slight spread)
        local ang = aimDir:Angle()
        ang:RotateAroundAxis(ang:Up(), math.Rand(-15, 15))
        ang:RotateAroundAxis(ang:Right(), math.Rand(-15, 15))
        local spreadDir = ang:Forward()
        tr = util.TraceLine({
            start = shootPos,
            endpos = shootPos + spreadDir * 96,
            filter = owner,
            mask = MASK_SHOT
        })
    end

    if tr.Hit and IsValid(tr.Entity) then
        local ent = tr.Entity

        -- Apply damage
        local dmginfo = DamageInfo()
        dmginfo:SetDamage(self.Primary.Damage)
        dmginfo:SetAttacker(owner)
        dmginfo:SetInflictor(self)
        dmginfo:SetDamageType(DMG_CRUSH)
        dmginfo:SetDamageForce(aimDir * self.Primary.Force)
        ent:TakeDamageInfo(dmginfo)

        -- Apply knockback force
        if ent:IsPlayer() or ent:IsNPC() then
            ent:SetVelocity(aimDir * self.Primary.Force * 2)
        else
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(aimDir * self.Primary.Force * 10)
            end
        end

        -- Effects
        local fx = EffectData()
        fx:SetOrigin(tr.HitPos)
        fx:SetStart(shootPos)
        fx:SetNormal(tr.HitNormal)
        fx:SetScale(1)
        util.Effect("StunstickImpact", fx, true, true)

        local fx2 = EffectData()
        fx2:SetOrigin(tr.HitPos)
        fx2:SetScale(1)
        util.Effect("cball_explode", fx2, true, true)
    end

    self:ShootEffects()
end

function SWEP:SecondaryAttack()
end
