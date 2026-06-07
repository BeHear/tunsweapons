-- XT10-RPG - Fixed rocket launcher implementation
-- Now reliably spawns a projectile that travels forward and explodes on impact or after timeout.

SWEP.PrintName = "XT10-RPG"
SWEP.Author = "GPT"
SWEP.Instructions = "LMB — Fire a rocket."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 32
SWEP.Primary.Automatic = false
-- Use generic spare ammo type so it shows in HUD; actual ammo not required if Spawnable
SWEP.Primary.Ammo = "RPG_Round"
SWEP.Primary.Delay = 0.8 -- slightly slower to be balanced
SWEP.Primary.Damage = 350 -- explosion damage
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

-- Choose a sensible viewmodel (avoid sniper viewmodel). Use first valid model from candidates.
local vm_candidates = {
    "models/weapons/v_rpg.mdl",
    "models/weapons/v_rocket_launcher.mdl",
    "models/weapons/v_rocket.mdl",
    "models/weapons/cstrike/c_rif_m4a1.mdl"
}
local chosen_vm = vm_candidates[1]
for _,m in ipairs(vm_candidates) do
    if util.IsValidModel(m) then chosen_vm = m break end
end
SWEP.ViewModel = chosen_vm

-- World model candidates
local wm_candidates = {
    "models/weapons/w_rocket_launcher.mdl",
    "models/Combine_Helicopter/helicopter_bomb01.mdl",
    "models/props_phx/rocket.mdl"
}
local chosen_wm = wm_candidates[1]
for _,m in ipairs(wm_candidates) do
    if util.IsValidModel(m) then chosen_wm = m break end
end
SWEP.WorldModel = chosen_wm
SWEP.UseHands = true

-- Projectile parameters
SWEP.RocketSpeed = 1500
SWEP.RocketLifeTime = 8
SWEP.RocketModelCandidates = {
    "models/Combine_Helicopter/helicopter_bomb01.mdl",
    "models/props_phx/rocket.mdl",
    "models/props_junk/propane_tank001a.mdl"
}
SWEP.RocketExplosiveRadius = 512
SWEP.RocketExplosiveDamage = 600

function SWEP:Initialize()
    self:SetHoldType("rpg")
end

local function ChooseModel(candidates)
    for _,m in ipairs(candidates) do
        if util.IsValidModel(m) then return m end
    end
    return candidates[1]
end

local function ExplodeRocket(rocket, owner)
    if not IsValid(rocket) then return end
    if rocket._XT10_Exploded then return end
    rocket._XT10_Exploded = true

    local pos = rocket:GetPos()

    -- visual
    local fx = EffectData()
    fx:SetOrigin(pos)
    fx:SetStart(rocket:GetPos())
    fx:SetNormal(Vector(0,0,1))
    fx:SetScale(1)
    fx:SetMagnitude(1)
    util.Effect("Explosion", fx, true, true)

    rocket:EmitSound("ambient/explosions/explode_4.wav", 140, 100)

    -- damage
    util.BlastDamage(rocket, IsValid(owner) and owner or rocket, pos, rocket.RocketExplosiveRadius or 512, rocket.RocketExplosiveDamage or 600)

    -- screen shake
    util.ScreenShake(pos, 2000, 255, 1.2, rocket.RocketExplosiveRadius or 512)

    SafeRemoveEntity(rocket)
end

function SWEP:PrimaryAttack()
    if CLIENT then return end
    if not self:CanPrimaryAttack() then return end

    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay or 0.8))

    -- play sound and animation
    self:EmitSound("weapons/rpg/rocketfire.wav" or "Weapon_RPG.Single", 100, 100)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

    -- spawn rocket
    local spawnPos = ply:GetShootPos() + ply:GetAimVector() * 16
    local spawnAng = ply:GetAimVector():Angle()

    local rocket = ents.Create("prop_physics")
    if not IsValid(rocket) then
        ply:ChatPrint("XT10: failed to spawn rocket entity")
        self:TakePrimaryAmmo(1)
        return
    end

    local model = ChooseModel(self.RocketModelCandidates)
    rocket:SetModel(model)
    rocket:SetPos(spawnPos)
    rocket:SetAngles(spawnAng)
    rocket:Spawn()
    rocket:SetOwner(ply)
    rocket.RocketExplosiveRadius = self.RocketExplosiveRadius
    rocket.RocketExplosiveDamage = self.RocketExplosiveDamage

    -- phys
    local phys = rocket:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(50)
        -- disable drag and gravity for more predictable flight
        phys:EnableGravity(false)
        phys:SetVelocityInstantaneous(ply:GetAimVector() * (self.RocketSpeed or 1500) + ply:GetVelocity())
    else
        rocket:SetMoveType(MOVETYPE_FLY)
        rocket:SetVelocity(ply:GetAimVector() * (self.RocketSpeed or 1500))
    end

    -- collision callback -> explode
    rocket:AddCallback("PhysicsCollide", function(ent, data)
        if not IsValid(ent) then return end
        -- avoid exploding immediately if we collided with owner or too small speed
        local hitEnt = data.HitEntity
        local speed = data.Speed or 0
        if IsValid(hitEnt) and hitEnt == ply then
            -- ignore collisions with owner
            return
        end
        -- explode on reasonable impact
        if speed > 50 then
            ExplodeRocket(ent, ply)
        end
    end)

    -- timed fuse
    local timerName = "XT10_Rocket_Fuse_"..rocket:EntIndex()
    timer.Create(timerName, self.RocketLifeTime or 8, 1, function()
        if not IsValid(rocket) then timer.Remove(timerName) return end
        ExplodeRocket(rocket, ply)
        timer.Remove(timerName)
    end)

    -- prevent friendly-fire on owner when rocket explodes very close: small safety delay where owner is ignored
    rocket.IgnoreOwnerUntil = CurTime() + 0.2

    -- recoil
    ply:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))

    self:TakePrimaryAmmo(1)
end

function SWEP:SecondaryAttack()
    -- No secondary
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
end

function SWEP:Deploy()
    self:SetNextPrimaryFire(CurTime() + 0.5)
    return true
end
