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
    if IsValid(self.Owner) and self.Owner:Crouching() then
        return (self.CurrentSpread or self.Primary.Spread) * self.CrouchSpreadMul
    end
    return self.CurrentSpread or self.Primary.Spread
end

function SWEP:GetModifiedBaseSpread()
    if IsValid(self.Owner) and self.Owner:Crouching() then
        return self.Primary.Spread * self.CrouchSpreadMul
    end
    return self.Primary.Spread
end

function SWEP:GetModifiedMaxSpread()
    if IsValid(self.Owner) and self.Owner:Crouching() then
        return self.Primary.MaxSpread * self.CrouchSpreadMul
    end
    return self.Primary.MaxSpread
end

-- Супер-мощный удар "дубинкой-шокером" с электрошок-эффектом и гипер-отталкиванием при убийстве
function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end

    local owner = self.Owner or self:GetOwner()
    if not IsValid(owner) then return end

    owner:SetAnimation(PLAYER_ATTACK1)
    self.Weapon:SendWeaponAnim(ACT_VM_HITCENTER)

    -- Делаем trace до ~65 юнитов вперед
    if SERVER then
        timer.Simple(0.05, function()
            if not IsValid(self) or not IsValid(owner) then return end
            local spos = owner:GetShootPos()
            local epos = spos + owner:GetAimVector() * 65
            local tr = util.TraceLine({
                start = spos,
                endpos = epos,
                filter = owner,
                mask = MASK_SHOT_HULL
            })
            if not tr.Hit or not IsValid(tr.Entity) then
                tr = util.TraceHull({
                    start = spos,
                    endpos = epos,
                    mins = Vector(-8,-8,-4),
                    maxs = Vector(8,8,4),
                    filter = owner,
                    mask = MASK_SHOT_HULL
                })
            end

            local ent = tr.Entity
            if tr.Hit and IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:GetClass() ~= "worldspawn") then
                -- Электрический "разряд": звук, вспышка, урон
                local effect = EffectData()
                effect:SetOrigin(tr.HitPos)
                util.Effect("StunstickImpact", effect)
                util.Effect("cball_explode", effect)
                
                ent:EmitSound("weapons/stunstick/stunstick_fleshhit2.wav", 80, 110)
                self:EmitSound("weapons/stunstick/stunstick_swing2.wav", 70, 120)

                local dmginfo = DamageInfo()
                dmginfo:SetDamage(self.Primary.Damage)
                dmginfo:SetAttacker(owner)
                dmginfo:SetInflictor(self)
                dmginfo:SetDamageForce(owner:GetAimVector() * self.Primary.Force * 900)
                dmginfo:SetDamagePosition(tr.HitPos)
                dmginfo:SetDamageType(DMG_CLUB + DMG_SHOCK)
                
                -- до нанесения урона сохраняем старое здоровье
                local wasAlive = true
                local oldHealth = 0

                if ent:IsPlayer() or ent:IsNPC() then
                    if ent:IsPlayer() then
                        oldHealth = ent:Health() -- Если игрок, получаем здоровье
                        wasAlive = ent:Alive()
                    elseif ent:IsNPC() then
                        oldHealth = ent:Health()
                        wasAlive = ent:Health() > 0
                    end
                end

                ent:TakeDamageInfo(dmginfo)

                -- Проверяем был ли добит после удара
                local isDeadNow = false
                if ent:IsPlayer() then
                    isDeadNow = wasAlive and not ent:Alive()
                elseif ent:IsNPC() then
                    isDeadNow = wasAlive and ent:Health() <= 0
                end

                -- Гипер-отталкивание при убийстве
                if isDeadNow then
                    -- Используем phys объект, если есть
                    local phys = ent:GetPhysicsObject()
                    local pushDir = owner:GetAimVector()
                    if IsValid(phys) then
                        phys:ApplyForceCenter(pushDir * 200000) -- ОГРОМНАЯ сила
                    else
                        -- Если физикса нет, пробуем задать Velocity напрямую (обычно работает для игроков/нпц)
                        if ent.SetVelocity then
                            ent:SetVelocity(pushDir * 1500)
                        end
                    end

                    -- Доп. эффект — мощный звук при добивании
                    ent:EmitSound("physics/metal/metal_box_break2.wav", 100, 80)
                    
                    -- Доп. эффект — крутящий момент
                    if IsValid(phys) then
                        phys:AddAngleVelocity(VectorRand() * 800)
                    end
                end

                -- Оглушаем игрока/нпц (парализуем/замедляем на 1 сек, если есть MoveType/SetMoveType)
                if ent:IsPlayer() or ent:IsNPC() then
                    if ent:IsPlayer() then
                        ent:ScreenFade(SCREENFADE.IN, Color(140,200,255,128), 0.3, 1.1)
                    end
                    if ent.SetMoveType then
                        ent:SetMoveType(MOVETYPE_NONE)
                        timer.Simple(1, function()
                            if IsValid(ent) and (not isDeadNow) then
                                ent:SetMoveType(MOVETYPE_WALK)
                            end
                        end)
                    end
                end
            else
                -- Мимо/по миру, другой ударный звук/эффект
                self:EmitSound("weapons/stunstick/stunstick_swing1.wav", 60, 105)
                if tr.Hit and tr.Entity and tr.Entity:GetClass() == "worldspawn" then
                    util.Decal("fadingscorch", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
                end
            end
        end)
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Think()
    -- Нет динамического разброса
end

function SWEP:Reload()
    -- Не перезаряжается
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
