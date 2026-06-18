-- Оружие "Thanos Snap" (щелчок Таноса) на базе gun1.lua
SWEP.PrintName = "Thanos Snap"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — уничтожает всех и всё в мире с красивым эффектом."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 5
SWEP.Primary.Damage = math.huge
SWEP.Primary.Recoil = 0
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0
SWEP.Primary.MaxSpread = 0
SWEP.Primary.SpreadIncrease = 0
SWEP.Primary.SpreadRecovery = 0
SWEP.Primary.Force = 1000000

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 99
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Slot = 9
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/cstrike/c_knife_t.mdl"
SWEP.WorldModel = "models/weapons/w_knife_t.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:PrimaryAttack()
    if not SERVER then return end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- Эффект: громкий щелчок
    owner:EmitSound("ambient/machines/catapult_throw.wav", 150, 65, 1, CHAN_STATIC)

    -- Вспышка экрана, тряска (для всех)
    net.Start("thanos_snap_flash")
    net.Broadcast()

    -- Уничтожить всех игроков (кроме владельца)
    for _, ply in ipairs(player.GetAll()) do
        if ply ~= owner and ply:Alive() then
            -- Эффект исчезновения пыли
            local effectdata = EffectData()
            effectdata:SetOrigin(ply:GetPos() + Vector(0,0,40))
            util.Effect("StunstickImpact", effectdata, true, true)
            ply:Kill()
        end
    end

    -- Уничтожить всех NPC
    for _, npc in ipairs(ents.GetAll()) do
        if IsValid(npc) and string.find(npc:GetClass(), "npc_") == 1 then
            local effectdata = EffectData()
            effectdata:SetOrigin(npc:GetPos() + Vector(0,0,40))
            util.Effect("StunstickImpact", effectdata, true, true)
            npc:Remove()
        end
    end

    -- Уничтожить все пропы (prop_physics, prop_dynamic и др)
    for _, ent in ipairs(ents.GetAll()) do
        if ent ~= owner and IsValid(ent) and (string.find(ent:GetClass(), "prop_") or ent:GetClass() == "gmod_sent_vehicle_fphysics_base") then
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                local effectdata = EffectData()
                effectdata:SetOrigin(ent:GetPos())
                util.Effect("StunstickImpact", effectdata, true, true)
            end
            ent:Remove()
        end
    end

    -- Молекулярная "пылизация": немного эффектов рядом с игроком
    timer.Simple(0.5, function()
        if not IsValid(owner) then return end
        local effectdata = EffectData()
        effectdata:SetOrigin(owner:GetPos() + Vector(0,0,40))
        util.Effect("StunstickImpact", effectdata, true, true)
    end)
end

if SERVER then
    util.AddNetworkString("thanos_snap_flash")
end

if CLIENT then
    net.Receive("thanos_snap_flash", function()
        -- Эффект: экран ярко бледнеет
        local d = Derma_DrawBackgroundBlur
        hook.Add("HUDPaint", "ThanosSnapScreenEffect", function()
            surface.SetDrawColor(255,255,255,160)
            surface.DrawRect(0,0, ScrW(), ScrH())
        end)
        timer.Simple(1.3, function()
            hook.Remove("HUDPaint", "ThanosSnapScreenEffect")
        end)
    end)
end

function SWEP:SecondaryAttack()
    -- Нет функции
end
