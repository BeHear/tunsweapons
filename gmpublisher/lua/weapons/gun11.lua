-- Оружие: Нож (на базе gun1.lua), с анимациями, исправлено под melee-оружие
-- Делает игрока быстрее при взятии ножа

SWEP.PrintName = "Speedy Knife"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ - удар ножом. ПКМ - быстрый укол."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.53
SWEP.Primary.Damage = 115
SWEP.Primary.Force = 11

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 0.29
SWEP.Secondary.Damage = 85
SWEP.Secondary.Force = 7

SWEP.Weight = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.Slot = 1
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/cstrike/c_knife_t.mdl"
SWEP.WorldModel = "models/weapons/w_knife_t.mdl"
SWEP.UseHands = true

SWEP.SpeedMultiplier = 1.8 -- Можно изменить это число для регулировки скорости

local KNIFE_ANIMS = {
    Slash = ACT_VM_HITCENTER,
    Stab  = ACT_VM_SECONDARYATTACK,
    Miss  = ACT_VM_MISSCENTER,
    Draw  = ACT_VM_DRAW,
    Idle  = ACT_VM_IDLE
}

function SWEP:Initialize()
    self:SetHoldType("knife")
end

-- Улучшенная регистрация урона: используется trace line + hull и двойная проверка, сведение к минимуму пропусков из-за prediction
function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end

    self.Owner:SetAnimation(PLAYER_ATTACK1)
    self:SendWeaponAnim(KNIFE_ANIMS.Slash)

    if SERVER then
        timer.Simple(0.05, function() -- задержка для совпадения с анимацией
            if IsValid(self) and IsValid(self.Owner) then
                self:KnifeDealDamage(self.Primary.Damage, self.Primary.Force, false)
            end
        end)
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SetNextSecondaryFire(CurTime() + 0.1)
end

function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end

    self.Owner:SetAnimation(PLAYER_ATTACK1)
    self:SendWeaponAnim(KNIFE_ANIMS.Stab)

    if SERVER then
        timer.Simple(0.04, function()
            if IsValid(self) and IsValid(self.Owner) then
                self:KnifeDealDamage(self.Secondary.Damage, self.Secondary.Force, true)
            end
        end)
    end

    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
    self:SetNextPrimaryFire(CurTime() + 0.18)
end

-- Реализация регистрации урона: две попытки (trace line, затем trace hull), четкая маска, work по игрокам/энтитям
function SWEP:KnifeDealDamage(dmg, force, isStab)
    if not IsValid(self.Owner) then return end

    local spos = self.Owner:GetShootPos()
    local epos = spos + self.Owner:GetAimVector() * 64
    local filter = self.Owner

    -- Сначала line trace (работает хорошо для точного удара), потом hull (для широких взмахов)
    local tr = util.TraceLine({
        start = spos,
        endpos = epos,
        filter = filter,
        mask = MASK_SHOT_HULL
    })

    if not tr.Hit or not IsValid(tr.Entity) then
        tr = util.TraceHull({
            start = spos,
            endpos = epos,
            mins = Vector(-10,-10,-8),
            maxs = Vector(10,10,8),
            filter = filter,
            mask = MASK_SHOT_HULL
        })
    end

    local hitEnt = tr.Entity
    local hitOk = IsValid(hitEnt) and (hitEnt:IsNPC() or hitEnt:IsPlayer() or hitEnt:GetClass() ~= "worldspawn")

    if tr.Hit and hitOk then
        -- Кровь и звук только по игроку/нпц/т.п.
        if hitEnt:IsPlayer() or hitEnt:IsNPC() then
            local effect = EffectData()
            effect:SetOrigin(tr.HitPos)
            util.Effect("BloodImpact", effect, true, true)
        end

        local dmginfo = DamageInfo()
        dmginfo:SetDamage(dmg)
        dmginfo:SetAttacker(self.Owner)
        dmginfo:SetInflictor(self)
        dmginfo:SetDamageForce(self.Owner:GetAimVector() * force * 280)
        dmginfo:SetDamagePosition(tr.HitPos)
        dmginfo:SetDamageType(bit.bor(DMG_SLASH, isStab and DMG_NEVERGIB or 0))
        hitEnt:TakeDamageInfo(dmginfo)

        self:EmitSound("Weapon_Knife.Hit")

        -- Дублируем анимацию на клиенте
        self:SendWeaponAnim(isStab and KNIFE_ANIMS.Stab or KNIFE_ANIMS.Slash)
    else
        -- Промах или удар по миру
        if tr.Hit and hitEnt and hitEnt:GetClass() == "worldspawn" then
            self:EmitSound("Weapon_Knife.HitWall")
        else
            self:EmitSound("Weapon_Knife.Slash")
        end
        self:SendWeaponAnim(KNIFE_ANIMS.Miss)
    end
end

function SWEP:Deploy()
    self:SendWeaponAnim(KNIFE_ANIMS.Draw)
    if SERVER and IsValid(self.Owner) and self.Owner:IsPlayer() then
        if not self.Owner._OldKnifeWalkSpeed then
            self.Owner._OldKnifeWalkSpeed = self.Owner:GetWalkSpeed()
        end
        if not self.Owner._OldKnifeRunSpeed then
            self.Owner._OldKnifeRunSpeed = self.Owner:GetRunSpeed()
        end
        self.Owner:SetWalkSpeed(self.Owner:GetWalkSpeed() * self.SpeedMultiplier)
        self.Owner:SetRunSpeed(self.Owner:GetRunSpeed() * self.SpeedMultiplier)
    end
    return true
end

function SWEP:Holster()
    if SERVER and IsValid(self.Owner) and self.Owner:IsPlayer() then
        if self.Owner._OldKnifeWalkSpeed then
            self.Owner:SetWalkSpeed(self.Owner._OldKnifeWalkSpeed)
            self.Owner._OldKnifeWalkSpeed = nil
        end
        if self.Owner._OldKnifeRunSpeed then
            self.Owner:SetRunSpeed(self.Owner._OldKnifeRunSpeed)
            self.Owner._OldKnifeRunSpeed = nil
        end
    end
    return true
end

function SWEP:OnRemove()
    if SERVER and IsValid(self.Owner) and self.Owner:IsPlayer() then
        if self.Owner._OldKnifeWalkSpeed then
            self.Owner:SetWalkSpeed(self.Owner._OldKnifeWalkSpeed)
            self.Owner._OldKnifeWalkSpeed = nil
        end
        if self.Owner._OldKnifeRunSpeed then
            self.Owner:SetRunSpeed(self.Owner._OldKnifeRunSpeed)
            self.Owner._OldKnifeRunSpeed = nil
        end
    end
end

function SWEP:OwnerChanged()
    if SERVER and IsValid(self.Owner) and self.Owner:IsPlayer() then
        if not self.Owner._OldKnifeWalkSpeed then
            self.Owner._OldKnifeWalkSpeed = self.Owner:GetWalkSpeed()
        end
        if not self.Owner._OldKnifeRunSpeed then
            self.Owner._OldKnifeRunSpeed = self.Owner:GetRunSpeed()
        end
        self.Owner:SetWalkSpeed(self.Owner:GetWalkSpeed() * self.SpeedMultiplier)
        self.Owner:SetRunSpeed(self.Owner:GetRunSpeed() * self.SpeedMultiplier)
    end
end

function SWEP:Reload()
    -- нож не перезаряжается
end

function SWEP:Think()
end

function SWEP:ShouldDropOnDie()
    return false
end
