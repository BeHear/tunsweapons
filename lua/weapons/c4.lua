-- C4 для Garry's Mod с динамическим ускоряющимся beep'ом и топовым поведением CS:GO
-- (модели как в CS:S)

SWEP.PrintName = "C4 Bomb"
SWEP.Author = "GPT"
SWEP.Instructions = "Установить С4 на поверхность (ЛКМ). После таймера — БУМ."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.5

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 3
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Slot = 4
SWEP.SlotPos = 1

-- Используем модели C4 из Counter-Strike: Source
SWEP.ViewModel = "models/weapons/v_c4.mdl"
SWEP.WorldModel = "models/weapons/w_c4.mdl"
SWEP.UseHands = true

SWEP.C4Timer = 40 -- секунд до взрыва
SWEP.C4BeepIntervalStart = 1     -- начальный интервал (сек)
SWEP.C4BeepIntervalEnd = 0.15    -- финальный интервал (сек)

-- Альтернативные стандартные звуки Half-Life 2 (или GMod), чтобы не было ошибок "file missing"
SWEP.C4BeepSound1 = "buttons/blip1.wav"
SWEP.C4BeepSound2 = "buttons/blip2.wav"
SWEP.C4PlantSound = "weapons/c4/c4_plant.wav"
SWEP.C4ExplodeSound1 = "weapons/c4/c4_explode1.wav"
SWEP.C4ExplodeSound2 = "ambient/explosions/explode_8.wav"

function SWEP:Initialize()
    self:SetHoldType("slam")
end

local function CanPlantC4OnTrace(tr)
    if not tr or not tr.Hit then return false end
    if tr.HitSky or tr.AllSolid or tr.StartSolid then return false end
    if (tr.HitDistance or 0) > 100 then return false end

    local contents = tr.Contents or 0
    if bit.band(contents, CONTENTS_WATER) ~= 0 then return false end
    if bit.band(contents, CONTENTS_SLIME) ~= 0 then return false end

    return true
end

-- PRIMARY: Установить бомбу
function SWEP:PrimaryAttack()
    if CLIENT then return end
    local ply = self.Owner or self:GetOwner()
    if not IsValid(ply) then return end
    if self.Planted then return end

    -- Дать задержку между попытками
    self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay or 0.5))

    -- Трассируем вперёд
    local tr = util.TraceLine({
            start = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * 100,
            filter = ply
        })
    if not CanPlantC4OnTrace(tr) then return end

    if IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsNPC()) then return end

    -- Позиция и угол для C4
    local pos = tr.HitPos + tr.HitNormal * 2
    local ang = tr.HitNormal:Angle()
    ang:RotateAroundAxis(ang:Right(),-90)

    -- Создать энтити C4 с моделью из CS:S (w_c4.mdl)
    local c4 = ents.Create("prop_physics")
    if not IsValid(c4) then return end
    c4:SetModel("models/weapons/w_c4.mdl")
    c4:SetPos(pos)
    c4:SetAngles(ang)
    c4:Spawn()
    c4:SetMoveType(MOVETYPE_NONE)
    c4:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    c4:SetOwner(ply)

    -- Метаданные
    c4.C4_PlantedBy = ply
    c4.C4_Weapon = self

    -- "Приклеиваем" к поверхности
    local phys = c4:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    -- Запускаем продвинутый тикер
    local timerId = "C4Bomb_Beep_"..c4:EntIndex()
    self:StartC4BeepTicker(c4, self.C4Timer, timerId)

    -- Эффект установки
    ply:EmitSound(self.C4PlantSound or "buttons/button17.wav", 75, 100, 1)

    self.Planted = true
    -- Убрать оружие после установки
    self:Remove()
end

function SWEP:SecondaryAttack()
    -- Не используется (нет дефюза)
end

-- Умное ускоряющееся бипанье
function SWEP:StartC4BeepTicker(c4, seconds, timerId)
    if not IsValid(c4) then return end

    -- Фиксы на всякий
    if seconds == nil or type(seconds) ~= "number" then seconds = 40 end
    seconds = math.floor(seconds)
    if seconds < 1 then seconds = 40 end

    c4.C4_SecondsLeft = seconds

    -- Круто: прогрессия между стартовым и финальным интервалом
    local interval_start = self.C4BeepIntervalStart or 1
    local interval_end = self.C4BeepIntervalEnd or 0.15
    local total_time = seconds

    local C4_BEEP1 = self.C4BeepSound1 or "buttons/blip1.wav"
    local C4_BEEP2 = self.C4BeepSound2 or "buttons/blip2.wav"
    local C4_PLANT = self.C4PlantSound or "buttons/button17.wav"
    local C4_EXPLODE = self.C4ExplodeSound1 or "ambient/explosions/explode_2.wav"
    local C4_EXPLODE2 = self.C4ExplodeSound2 or "ambient/explosions/explode_8.wav"

    local function BeepThink()
        if not IsValid(c4) then timer.Remove(timerId) return end
        local secondsLeft = tonumber(c4.C4_SecondsLeft) or 0

        -- Звук бипа в зависимости от времени
        local beepSound
        if secondsLeft > 10 then
            beepSound = C4_BEEP1
        elseif secondsLeft > 0 then
            beepSound = C4_BEEP2
        end

        if beepSound then
            local pitch = 100
            if secondsLeft <= 8 then pitch = math.Clamp(110 + (8-secondsLeft)*5, 110, 160) end -- убыстряем и пич
            c4:EmitSound(beepSound, 92 + math.random(-2,2), pitch, 1, CHAN_STATIC)
        end

        -- Доп бипы перед концом — частые
        if secondsLeft <= 5 and secondsLeft > 0 then
            timer.Simple(0.25, function()
                if IsValid(c4) then
                    c4:EmitSound(C4_BEEP2, 97, 120 + math.random(-2,2), 1)
                end
            end)
        end

        -- ВЗРЫВ!!
        if secondsLeft <= 0 then
            if IsValid(c4) then
                local explodePos = c4:GetPos()
                local effect = EffectData()
                effect:SetOrigin(explodePos)
                util.Effect("Explosion", effect, true, true)

                c4:EmitSound(C4_EXPLODE, 120, 100, 1)
                c4:EmitSound(C4_EXPLODE2, 115, 96, 1)

                -- Сильный урон, чуть больше радиус (для эпика)
                util.BlastDamage(c4, c4.C4_PlantedBy or c4, explodePos, 700, 360)

                c4:Remove()
            end
            timer.Remove(timerId)
            return
        end

        -- Вычисление ускоренного интервала (чистый lerp обратный)
        local progress = 1 - (secondsLeft / total_time)
        local beepInterval = Lerp(progress, interval_start, interval_end)     -- плавное ускорение beep

        -- Запуск след. бипа
        c4.C4_SecondsLeft = secondsLeft - beepInterval
        timer.Simple(beepInterval, BeepThink)
    end

    BeepThink()
end

-- Вспомогательные материалы:
-- Стандартные звуки GMod/HL2 для C4:
-- Plant:       "buttons/button17.wav" (или "weapons/c4/c4_plant.wav" если есть)
-- Beep 1:      "buttons/blip1.wav"
-- Beep 2:      "buttons/blip2.wav"
-- Explode:     "ambient/explosions/explode_2.wav" или "ambient/explosions/explode_8.wav"
