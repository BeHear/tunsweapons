SWEP.PrintName = "BASSY"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — Мощный басс глушит и наносит урон всем в радиусе"
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 3
SWEP.Primary.DefaultClip = 9
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 3
SWEP.Primary.Damage = 75

SWEP.BassRadius = 600
SWEP.BassDamage = 75
SWEP.BassShakeIntensity = 25
SWEP.BassShakeLength = 2

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 3
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 4
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/cstrike/c_rif_galil.mdl"
SWEP.WorldModel = "models/weapons/w_rif_galil.mdl"
SWEP.UseHands = true

if SERVER then
    util.AddNetworkString("bassy_shake")
end

function SWEP:Initialize()
    self:SetHoldType("ar2")
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    if not IsValid(self.Owner) or not self.Owner:IsPlayer() then return end

    local owner = self.Owner
    local pos = owner:GetShootPos()
    local radius = self.BassRadius or 600

    self:TakePrimaryAmmo(1)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    self:EmitSound("weapons/physcannon/superphys_launch1.wav", 140, 40, 1, CHAN_AUTO)

    if SERVER then
        -- Apply blast damage to entities in radius but explicitly exclude the owner to avoid self-damage
        local damage = self.BassDamage or 75
        local entsInSphere = ents.FindInSphere(pos, radius)
        for _, ent in ipairs(entsInSphere) do
            if not IsValid(ent) then continue end
            if ent == owner then continue end

            if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
                local dmginfo = DamageInfo()
                dmginfo:SetDamage(damage)
                dmginfo:SetAttacker(owner)
                dmginfo:SetInflictor(self)
                dmginfo:SetDamageType(DMG_BLAST)
                ent:TakeDamageInfo(dmginfo)
            else
                -- Apply damage to props/other entities so they react to the blast
                if ent.TakeDamage then
                    ent:TakeDamage(damage, owner, self)
                end
            end
        end

        if not IsValid(owner) then return end
        timer.Simple(0.05, function()
            if not IsValid(owner) then return end
            local shootPos = owner:GetShootPos()
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:GetPos():DistToSqr(shootPos) <= (radius * radius) then
                    net.Start("bassy_shake")
                    net.WriteFloat(self.BassShakeIntensity or 25)
                    net.WriteFloat(self.BassShakeLength or 2)
                    net.Send(ply)
                end
            end
        end)
    end

    self:ShootEffects()
end

function SWEP:SecondaryAttack()
end

if CLIENT then
    net.Receive("bassy_shake", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local intensity = net.ReadFloat()
        local length = net.ReadFloat()
        util.ScreenShake(ply:GetPos(), intensity or 25, 180, length or 2, 600)
        ply:EmitSound("weapons/physcannon/energy_bounce"..math.random(1,2)..".wav", 140, 30, 1, CHAN_AUTO)
    end)
end
