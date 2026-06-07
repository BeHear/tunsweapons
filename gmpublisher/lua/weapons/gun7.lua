-- Гипер мощный дробовик с взрывными патронами "NeSPAS-69" (красный!)

SWEP.PrintName = "NeSPAS-1337"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ"
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 4
SWEP.Primary.DefaultClip = 16
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Buckshot"
SWEP.Primary.Delay = 1.05
SWEP.Primary.Damage = 260      -- большой урон на "пулю"
SWEP.Primary.NumShots = 8     -- дробовик - много дробин
SWEP.Primary.Recoil = 7
SWEP.Primary.Spread = 0.08   -- мощное / большое рассеяние
SWEP.Primary.Force = 64        -- физ. сила выстрела

SWEP.ExplosiveRadius = 768   -- увеличенный радиус взрыва от каждой дробины
SWEP.ExplosiveDamage = 82     -- урон от взрыва каждой дробины
SWEP.ShakeRadius = 4200       -- радиус тряски (для всем трясущегося экрана)

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 8
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = false

SWEP.Slot = 3
SWEP.SlotPos = 3

SWEP.ViewModel = "models/weapons/v_shotgun.mdl"
SWEP.WorldModel = "models/weapons/w_shotgun.mdl"
SWEP.UseHands = true

-- Добавляем красный цвет оружию на худе/инвентаре (GMod поддержка)
if CLIENT then
    SWEP.IconLetter = "B"
    SWEP.DrawWeaponSelection = function(self, x, y, w, h, a)
        draw.SimpleText("⛨", "WeaponIcons", x + w / 2, y + h * 0.25, Color(255,0,0,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    SWEP.SelectIcon = Material("vgui/entities/weapon_shotgun") -- Можно заменить на иконку или оставить GMod стандарт
    SWEP.WepColor = Color(255,0,0)
end

if SERVER then
    util.AddNetworkString("nspas69_shake")
end

function SWEP:Initialize()
    self:SetHoldType("shotgun")
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- Воспроизводим громкий мощный звук
    self:EmitSound("weapons/explosive_buckshot.wav", 135, 90, 1)

    -- Визуал эффект взрыва на дульном срезе (на клиентах)
    if SERVER then
        local effectdata = EffectData()
        effectdata:SetOrigin(owner:GetShootPos() + owner:GetAimVector()*32)
        util.Effect("Explosion", effectdata, true, true)
    end

    -- Мощная отдача (владельцу)
    owner:ViewPunch(Angle(-16, math.Rand(-6,6), 0))

    -- Экран ДИКО трясётся у всех в радиусе self.ShakeRadius от точки выстрела
    if SERVER then
        local shootPos = owner:GetShootPos()
        local shake_radius = self.ShakeRadius or 4200
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:GetPos():DistToSqr(shootPos) <= (shake_radius * shake_radius) then
                net.Start("nspas69_shake")
                net.Send(ply)
            end
        end
    end

    -- Основной выстрел с кастомными взрывными дробинами
    if SERVER then
        local shoot_origin = owner:GetShootPos()
        local shoot_dir = owner:GetAimVector()
        local spread = self.Primary.Spread

        for i = 1, self.Primary.NumShots do
            local ang = shoot_dir:Angle()
            ang:RotateAroundAxis(ang:Up(), math.Rand(-spread*70, spread*70))
            ang:RotateAroundAxis(ang:Right(), math.Rand(-spread*70, spread*70))
            local dir = ang:Forward()

            local tr = util.TraceLine({
                start = shoot_origin,
                endpos = shoot_origin + dir * 4096,
                filter = owner
            })

            -- Взрыв в конце траектории выстрела дробины с увеличенным радиусом
            util.BlastDamage(self, owner, tr.HitPos, self.ExplosiveRadius or 250, self.ExplosiveDamage or 82)

            -- Визуальный эффект — исправлено: используем правильное имя эффекта и отправляем его клиентам
            local fx = EffectData()
            fx:SetOrigin(tr.HitPos)
            util.Effect("Explosion", fx, true, true)

            -- Нарисуем красный трассер
            local trailEnt = ents.Create("info_target")
            if IsValid(trailEnt) then
                trailEnt:SetPos(shoot_origin)
                trailEnt:Spawn()
                util.SpriteTrail(
                    trailEnt, 0,
                    Color(255,0,0), false, 14, 1, 0.3, 1/12, "trails/laser.vmt"
                )
                -- Можно удалить сущность трейла через короткое время, чтобы не плодить энты
                timer.Simple(0.25, function() if IsValid(trailEnt) then trailEnt:Remove() end end)
            end
        end
    end

    self:ShootEffects()
    self:TakePrimaryAmmo(1)
end

-- Исправленная перезарядка с правильной анимацией
function SWEP:Reload()
    if self.Reloading then return end
    if self:Clip1() >= self.Primary.ClipSize then return end
    if self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0 then return end

    self.Reloading = true

    self:SetNextPrimaryFire(CurTime() + 0.5)
    self:SetNextSecondaryFire(CurTime() + 0.5)

    -- Начальная анимация перезарядки
    self:SendWeaponAnim(ACT_SHOTGUN_RELOAD_START)
    local vm = self:GetOwner():GetViewModel()
    if IsValid(vm) then
        vm:ResetSequence(ACT_SHOTGUN_RELOAD_START)
    end

    timer.Simple(vm:SequenceDuration(), function()
        if not IsValid(self) or not IsValid(self:GetOwner()) or not self.Reloading then return end

        self:StartShellInsert()
    end)
end

function SWEP:StartShellInsert()
    if not IsValid(self) or not IsValid(self:GetOwner()) then return end
    if self:Clip1() >= self.Primary.ClipSize or self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0 then
        self:FinishReload()
        return
    end

    -- Вставка патрона
    self:SendWeaponAnim(ACT_VM_RELOAD)
    local owner = self:GetOwner()
    local vm = owner:GetViewModel()
    if IsValid(vm) then
        vm:ResetSequence(ACT_VM_RELOAD)
    end

    timer.Simple(vm:SequenceDuration(), function()
        if not IsValid(self) or not IsValid(owner) or not self.Reloading then return end

        self:SetClip1(self:Clip1() + 1)
        owner:RemoveAmmo(1, self.Primary.Ammo)
        -- Проверяем, нужно ли продолжить вставлять патроны
        if self:Clip1() < self.Primary.ClipSize and owner:GetAmmoCount(self.Primary.Ammo) > 0 then
            self:StartShellInsert()
        else
            self:FinishReload()
        end
    end)
end

function SWEP:FinishReload()
    if not IsValid(self) or not IsValid(self:GetOwner()) then return end
    -- Завершающая анимация перезарядки
    self:SendWeaponAnim(ACT_SHOTGUN_RELOAD_FINISH)
    local vm = self:GetOwner():GetViewModel()
    if IsValid(vm) then
        vm:ResetSequence(ACT_SHOTGUN_RELOAD_FINISH)
    end

    local finishTime = vm and vm:SequenceDuration() or 0.5

    timer.Simple(finishTime, function()
        if IsValid(self) then
            self.Reloading = false
        end
    end)

    self:SetNextPrimaryFire(CurTime() + finishTime)
    self:SetNextSecondaryFire(CurTime() + finishTime)
end

function SWEP:CanPrimaryAttack()
    -- Не даём стрелять во время перезарядки
    if self.Reloading then return false end
    return self:Clip1() > 0
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end

-- Починка выхода из перезарядки при смене оружия
function SWEP:Holster()
    self.Reloading = false
    return true
end

-- Обработка выхода из прицела сбрасывает флаг перезарядки
function SWEP:Deploy()
    self.Reloading = false
    return true
end

-- Клиентский side-эффект экрана (ОЧЕНЬ мощная тряска)
if CLIENT then
    net.Receive("nspas69_shake", function()
        local ply = LocalPlayer()
        -- Используем экстремально сильный эффект тряски экрана
        if ply and ply.IsValid and ply:IsValid() then
            local intensity = 25     -- ОЧЕНЬ сильно
            local length = 1.8       -- Долгая тряска
            local speed = 74 * math.Rand(1.3, 1.6) -- очень быстро и мощно
            util.ScreenShake(Vector(0,0,0), intensity, speed, length, 6000)
        end
    end)
end
