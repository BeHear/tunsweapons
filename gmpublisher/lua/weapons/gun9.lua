-- Снайперская винтовка для Garry's Mod
-- Мгновенное убийство, нет разброса. Экран трясётся после убийства!

SWEP.PrintName = "KiScout"
SWEP.Author = "GPT"
SWEP.Instructions = "Любой противник падает с одного выстрела. Практически нет разброса. После убийства экран трясётся."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 5
SWEP.Primary.DefaultClip = 25
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "357"
SWEP.Primary.Delay = 1.2
SWEP.Primary.Damage = math.huge -- бесконечный урон
SWEP.Primary.Recoil = 0
SWEP.Primary.NumShots = 8
SWEP.Primary.Spread = 0 -- без разброса
SWEP.Primary.MaxSpread = 0 -- полностью убираем разброс
SWEP.Primary.SpreadIncrease = 0
SWEP.Primary.SpreadRecovery = 0
SWEP.Primary.Force = 999999 -- Очень большое значение, чтобы жертву сильно отбрасывало

SWEP.CrouchSpreadMul = 1 -- Не влияет, так как нет разброса

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 10
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 3
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/cstrike/c_snip_scout.mdl"
SWEP.WorldModel = "models/weapons/w_snip_scout.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("ar2")
    self.CurrentSpread = self.Primary.Spread
    self.LastFireTime = 0
end

function SWEP:GetModifiedSpread()
    return 0 -- абсолютно никакого разброса
end

function SWEP:GetModifiedBaseSpread()
    return 0
end

function SWEP:GetModifiedMaxSpread()
    return 0
end

-- Тряска после убийства
function SWEP:DoKillShake()
    if not IsValid(self.Owner) or not self.Owner:IsPlayer() then return end

    -- Только на клиенте владельца: тряска экрана (ViewPunch)
    if CLIENT and LocalPlayer() == self.Owner then
        -- Сильная тряска
        self.Owner:ViewPunch(Angle(math.Rand(-10, 10), math.Rand(-5, 5), 0))
    end
end

function SWEP:PrimaryAttack()
    if (not self:CanPrimaryAttack()) then return end
    self.LastFireTime = CurTime()
    self:EmitSound("Weapon_AWP.Single")

    -- Модифицированный выстрел с детектом убийств
    local wasKill = false

    local function BulletCallback(attacker, tr, dmginfo)
        -- Проверяем убитую сущность
        if SERVER then
            local ent = tr.Entity
                if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC()) then
                -- Подождём тик, чтобы убийство засчиталось
                timer.Simple(0, function()
                    if IsValid(ent) and ent:Health() <= 0 then
                        -- Сигнал владельцу что он убил врага
                        if IsValid(attacker) and attacker:IsPlayer() and attacker == self.Owner then
                            net.Start("tuns_gun9_killshake")
                            net.Send(attacker)
                        end
                    end
                end)
            end
        end
    end

    -- Передаём ShootBullet свой callback
    self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, 0, BulletCallback)
    self:TakePrimaryAmmo(1)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Think()
    -- нет необходимости восстанавливать разброс
end

if SERVER then
    util.AddNetworkString("tuns_gun9_killshake")
end

if CLIENT then
    net.Receive("tuns_gun9_killshake", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        -- Мощная тряска
        ply:ViewPunch(Angle(math.Rand(-10, 10), math.Rand(-5, 5), 0))
    end)
end

function SWEP:ShootBullet(damage, num_bullets, aimcone, cb)
    local bullet = {}
    bullet.Num = num_bullets
    bullet.Src = self.Owner:GetShootPos()
    bullet.Dir = self.Owner:GetAimVector()
    bullet.Spread = Vector(0, 0, 0) -- полностью без разброса
    bullet.Tracer = 1
    bullet.TracerName = "Tracer"
    bullet.Force = self.Primary.Force
    bullet.Damage = damage
    bullet.AmmoType = self.Primary.Ammo

    if cb then
        bullet.Callback = cb
    end

    self.Owner:FireBullets(bullet)
    self:ShootEffects()
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
    timer.Simple(self.Owner:GetViewModel():SequenceDuration(), function()
        if IsValid(self) then
            self.CurrentSpread = 0 -- сброс не нужен, но на всякий случай
        end
    end)
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
