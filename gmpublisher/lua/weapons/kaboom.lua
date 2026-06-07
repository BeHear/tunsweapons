SWEP.PrintName = "Kaboominator"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — Подожди 'kaboom'"
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 1
SWEP.Primary.Damage = 9999999 -- Гипер много урона
SWEP.Primary.Force = 1000

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.Slot = 1
SWEP.SlotPos = 8

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/weapons/w_slam.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("slam")
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsPlayer() then return end

    -- Проиграть звук 'kaboom.wav' ГРОМКО!
    if SERVER then
        local played = false
        pcall(function()
            ply:EmitSound({sound = "kaboom.wav", volume = 1, level = 150, pitch = 100, gain = 2.5})
            played = true
        end)
        if not played then
            ply:EmitSound("kaboom.wav", 511, 100, 1, CHAN_AUTO)
        end

        local kaboomDuration = 5 -- Длительность аудио. Поправьте при необходимости.
        timer.Simple(kaboomDuration, function()
            if not IsValid(ply) then return end

            -- Создать визуальный эффект взрыва
            local effect = EffectData()
            effect:SetOrigin(ply:GetPos() + Vector(0,0,32))
            util.Effect("Explosion", effect, true, true)
            
            -- ОГРОМНЫЙ ВЗРЫВ: гипер много урона во всём радиусе
            local explosionPos = ply:GetPos()
            local explosionRadius = 512 -- Можно увеличить!
            local explosionDamage = 9999999 -- Гипер много урона

            util.BlastDamage(self, ply, explosionPos, explosionRadius, explosionDamage)

            -- Также нанести гипер урон самому игроку напрямую
            local dmginfo = DamageInfo()
            dmginfo:SetAttacker(ply)
            dmginfo:SetInflictor(self)
            dmginfo:SetDamage(explosionDamage)
            dmginfo:SetDamageType(DMG_BLAST)
            dmginfo:SetDamageForce(Vector(0,0,1))
            ply:TakeDamageInfo(dmginfo)

            -- Гипер СИЛЬНО отбросить игрока вверх!
            local up = Vector(0, 0, 1)
            ply:SetVelocity(up * 20000000 + VectorRand() * 20000) -- экстремально большое значение
            ply:EmitSound("ambient/explosions/explode_1.wav", 150, 80, 1, CHAN_AUTO)
        end)
    end

    self:SetNextPrimaryFire(CurTime() + 5)
end

function SWEP:Reload()
    -- Нет перезарядки
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
