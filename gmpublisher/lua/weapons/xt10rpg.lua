-- XT10-RPG - Proper HL2 RPG with real rocket entity and physics
-- Uses actual rpg_missile for authentic HL2 rocket behavior

SWEP.PrintName = "XT10-RPG"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — стрельнуть ракетой. Правая кнопка — подствольный выстрел (если поддерживается)."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 32
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "RPG_Round"
SWEP.Primary.Delay = 1.2
SWEP.Primary.Damage = 200
SWEP.Primary.Radius = 512
SWEP.Primary.Recoil = 5
SWEP.Primary.Force = 300

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 10
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 4
SWEP.SlotPos = 2

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
        if not IsValid(rocket) then
            owner:ChatPrint("XT10: не удалось создать ракету")
            self:TakePrimaryAmmo(1)
            return
        end

        local spawnPos = owner:GetShootPos() + owner:GetAimVector() * 30 + owner:GetRight() * 8 + Vector(0, 0, -4)
        rocket:SetPos(spawnPos)
        rocket:SetAngles(owner:EyeAngles())
        rocket:SetOwner(owner)
        rocket:Spawn()

        local phys = rocket:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(owner:GetAimVector() * 2500 + owner:GetVelocity())
        end

        rocket:SetSaveValue("m_flDamage", self.Primary.Damage)

        local radius = self.Primary.Radius or 512
        rocket:SetSaveValue("m_DmgRadius", radius)

        timer.Simple(0.1, function()
            if IsValid(rocket) then
                rocket:SetSaveValue("m_flDamage", self.Primary.Damage)
                rocket:SetSaveValue("m_DmgRadius", radius)
            end
        end)
    end

    self:EmitSound("weapons/rpg/rocketfire.wav", 100, 100)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:TakePrimaryAmmo(1)

    local owner = self:GetOwner()
    if IsValid(owner) and owner.ViewPunch then
        owner:ViewPunch(Angle(-self.Primary.Recoil, 0, 0))
    end
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
end

function SWEP:SecondaryAttack()
end

function SWEP:Holster()
    return true
end
