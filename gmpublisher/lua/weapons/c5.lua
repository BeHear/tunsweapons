-- C5 — подводный заряд, можно устанавливать только под водой
-- При попытке поставить на суше — установка отменяется и игрок получает сообщение

SWEP.PrintName = "C5 Underwater Charge"
SWEP.Author = "GPT"
SWEP.Instructions = "Установите заряд под водой (ЛКМ). На суше поставить нельзя."
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
SWEP.SlotPos = 2

SWEP.ViewModel = "models/weapons/v_c4.mdl"
SWEP.WorldModel = "models/weapons/w_c4.mdl"
SWEP.UseHands = true

SWEP.C5Timer = 30 -- секунд до взрыва

SWEP.C5BeepSound = "buttons/blip1.wav"
SWEP.C5PlantSound = "buttons/button17.wav"
SWEP.C5ExplodeSound = "ambient/explosions/explode_4.wav"

function SWEP:Initialize()
    self:SetHoldType("slam")
end

function SWEP:PrimaryAttack()
    if CLIENT then return end
    local ply = self.Owner or self:GetOwner()
    if not IsValid(ply) then return end
    if self.Planted then return end

    self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay or 0.5))

    local tr = ply:GetEyeTrace()
    if not tr.Hit or (tr.HitDistance or 0) > 100 then return end

    local pos = tr.HitPos + tr.HitNormal * 2

    -- Проверяем, находится ли точка в воде
    local contents = util.PointContents(pos)
    local inWater = false
    if contents and type(contents) == "number" then
        -- CONTENTS_WATER — глобальная константа в GMod
        if bit and bit.band then
            inWater = (bit.band(contents, CONTENTS_WATER) ~= 0)
        else
            -- Резервный вариант: если нет битовой библиотеки, проверим по игроку
            inWater = (ply:WaterLevel() > 1)
        end
    else
        inWater = (ply:WaterLevel() > 1)
    end

    if not inWater then
        -- Никогда не ставим на суше
        ply:EmitSound("buttons/button10.wav", 75, 100)
        ply:ChatPrint("C5 можно устанавливать только под водой.")
        return
    end

    -- Создаем энтити заряда (используем prop_physics как визуальную основу)
    local c5 = ents.Create("prop_physics")
    if not IsValid(c5) then return end
    c5:SetModel("models/weapons/w_c4.mdl")
    c5:SetPos(pos)
    local ang = tr.HitNormal:Angle()
    ang:RotateAroundAxis(ang:Right(), -90)
    c5:SetAngles(ang)
    c5:Spawn()

    -- Подвешиваем к поверхности: отключаем физику
    local phys = c5:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
    c5:SetMoveType(MOVETYPE_NONE)
    c5:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    c5:SetOwner(ply)

    -- Метаданные
    c5.C5_PlantedBy = ply
    c5.C5_Weapon = self
    c5.C5_SecondsLeft = self.C5Timer or 30

    -- Звук установки
    ply:EmitSound(self.C5PlantSound or "buttons/button17.wav", 75, 100)

    -- Запускаем тикер звуков и таймер взрыва
    local timerId = "C5_Beep_"..c5:EntIndex()

    local function BeepThink()
        if not IsValid(c5) then timer.Remove(timerId) return end
        local secondsLeft = math.floor(tonumber(c5.C5_SecondsLeft) or 0)

        if secondsLeft <= 0 then
            if IsValid(c5) then
                local explodePos = c5:GetPos()

                -- Водный эффект: используем стандартный эффект взрыва и добавим всплеск пузырей
                local effect = EffectData()
                effect:SetOrigin(explodePos)
                util.Effect("WaterSurfaceExplosion", effect, true, true)

                c5:EmitSound(self.C5ExplodeSound or "ambient/explosions/explode_4.wav", 140, 100, 1)

                -- Водный урон: учитываем, что BlastDamage работает и под водой
                util.BlastDamage(c5, c5.C5_PlantedBy or c5, explodePos, 400, 300)

                c5:Remove()
            end
            timer.Remove(timerId)
            return
        end

        -- Бип каждые 1 секунду, быстрее при 5 сек
        local beepInterval = 1
        if secondsLeft <= 5 then
            beepInterval = 0.25
        end

        if IsValid(c5) then
            c5:EmitSound(self.C5BeepSound or "buttons/blip1.wav", 90, 100)
            c5.C5_SecondsLeft = c5.C5_SecondsLeft - beepInterval
            timer.Simple(beepInterval, BeepThink)
        else
            timer.Remove(timerId)
        end
    end

    BeepThink()

    self.Planted = true
    self:Remove()
end

function SWEP:SecondaryAttack()
    -- Не используется
end

-- Примечание: этот заряд предназанчен только для установки под водой.
-- Если требуется, можно улучшить проверку размещения (например, искать ближайшую подводную поверхность),
-- или заменить модель на специализированную модель подводного мины.
