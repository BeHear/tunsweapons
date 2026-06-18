-- Мега Stunstick для Garry's Mod, на базе gun1.lua с гипер-уроном и особыми эффектами

SWEP.PrintName = "Mega Stunstick"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — удар молнией. Присядьте для точного удара."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.32
SWEP.Primary.Damage = 50
SWEP.Primary.Recoil = 0
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.002 -- почти идеальная точность для удара
SWEP.Primary.MaxSpread = 0.01 
SWEP.Primary.SpreadIncrease = 0
SWEP.Primary.SpreadRecovery = 0
SWEP.Primary.Force = 64*64*64

SWEP.CrouchSpreadMul = 0.20 -- очень точен в присяде

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 3
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.Slot = 1
SWEP.SlotPos = 2

SWEP.ViewModel = "models/weapons/c_stunstick.mdl"
SWEP.WorldModel = "models/weapons/w_stunbaton.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("melee")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
end

function SWEP:GetModifiedSpread()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:Crouching() then
        return (self.CurrentSpread or self.Primary.Spread) * self.CrouchSpreadMul
    end
    return self.CurrentSpread or self.Primary.Spread
end

function SWEP:GetModifiedBaseSpread()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:Crouching() then
        return self.Primary.Spread * self.CrouchSpreadMul
    end
    return self.Primary.Spread
end

function SWEP:GetModifiedMaxSpread()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:Crouching() then
        return self.Primary.MaxSpread * self.CrouchSpreadMul
    end
    return self.Primary.MaxSpread
end

-- Супер-мощный удар "дубинкой-шокером" с электрошок-эффектом и гипер-отталкиванием при убийстве
function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    owner:SetAnimation(PLAYER_ATTACK1)
    self:SendWeaponAnim(ACT_VM_HITCENTER)

    -- Делаем trace до ~65 юнитов вперед
    if SERVER then
        timer.Simple(0.05, function()
            if not IsValid(self) or not IsValid(owner) then return end
            self:StunstickDealDamage(self.Primary.Damage, self.Primary.Force)
        end)
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Think()
    -- Нет динамического разброса
end

function SWEP:StunstickDealDamage(dmg, force)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local spos = owner:GetShootPos()
    local epos = spos + owner:GetAimVector() * 65
    local filter = owner

    -- Сначала line trace (работает хорошо для точного удара), затем hull (для широких взмахов)
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
        -- Электрический "разряд": звук, вспышка, урон
        local effect = EffectData()
        effect:SetOrigin(tr.HitPos)
        util.Effect("StunstickImpact", effect)
        util.Effect("cball_explode", effect)
        
        hitEnt:EmitSound("weapons/stunstick/stunstick_fleshhit2.wav", 80, 110)
        self:EmitSound("weapons/stunstick/stunstick_swing2.wav", 70, 120)

        local dmginfo = DamageInfo()
        dmginfo:SetDamage(dmg)
        dmginfo:SetAttacker(owner)
        dmginfo:SetInflictor(self)
        dmginfo:SetDamageForce(owner:GetAimVector() * force * 900)
        dmginfo:SetDamagePosition(tr.HitPos)
        dmginfo:SetDamageType(DMG_CLUB + DMG_SHOCK)

        -- Сохраняем старое здоровье для проверки убийства
        local wasAlive = true
        local oldHealth = 0

        if hitEnt:IsPlayer() then
            oldHealth = hitEnt:Health()
            wasAlive = hitEnt:Alive()
        elseif hitEnt:IsNPC() then
            oldHealth = hitEnt:Health()
            wasAlive = hitEnt:Health() > 0
        end

        hitEnt:TakeDamageInfo(dmginfo)

        -- Проверяем был ли добит после удара
        local isDeadNow = false
        if hitEnt:IsPlayer() then
            isDeadNow = wasAlive and not hitEnt:Alive()
        elseif hitEnt:IsNPC() then
            isDeadNow = wasAlive and hitEnt:Health() <= 0
        end

        -- Гипер-отталкивание при убийстве
        if isDeadNow then
            local phys = hitEnt:GetPhysicsObject()
            local pushDir = owner:GetAimVector()
            if IsValid(phys) then
                phys:ApplyForceCenter(pushDir * 200000) -- ОГРОМНАЯ сила
            else
                if hitEnt.SetVelocity then
                    hitEnt:SetVelocity(pushDir * 1500)
                end
            end

            hitEnt:EmitSound("physics/metal/metal_box_break2.wav", 100, 80)
            
            if IsValid(phys) then
                phys:AddAngleVelocity(VectorRand() * 800)
            end
        end

        -- Оглушаем игрока/нпц (замедляем на 1 сек)
        if hitEnt:IsPlayer() or hitEnt:IsNPC() then
            if hitEnt:IsPlayer() then
                hitEnt:ScreenFade(SCREENFADE.IN, Color(140,200,255,128), 0.3, 1.1)
                local vel = hitEnt:GetVelocity()
                hitEnt:SetVelocity(vel * 0.1)
                timer.Simple(1, function()
                    if IsValid(hitEnt) and (not isDeadNow) then
                        hitEnt:SetVelocity(hitEnt:GetVelocity() * 0.5)
                    end
                end)
            end
        end
    else
        self:EmitSound("weapons/stunstick/stunstick_swing1.wav", 60, 105)
        if tr.Hit and tr.Entity and tr.Entity:GetClass() == "worldspawn" then
            util.Decal("fadingscorch", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
        end
    end
end

function SWEP:Reload()
    -- Не перезаряжается
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end