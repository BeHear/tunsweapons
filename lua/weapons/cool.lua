-- Удалятель: Современный Админ-Ган
SWEP.PrintName = "Удалятель 2.0 (Админ)"
SWEP.Author = "AI"
SWEP.Instructions = [[
Для админов! ЛКМ — быстро удаляет все, что ты видишь (obj, prop, ragdoll, NPC, транспорт и др). 
ПКМ — луч сразу удаляет всех сущностей в области (радиус 100)
ВНИМАНИЕ: Используйте с умом!
]]
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.Category = "TUNS Weapons"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.001 -- 1000 выстрелов в сек

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel = "models/weapons/w_pist_deagle.mdl"

if SERVER then
    util.AddNetworkString("cool_removal_effect")
end

-- Вспомогательный визуальный эффект удаления (и звук)
local function RemovalEffect(pos)
    if SERVER then
        net.Start("cool_removal_effect")
            net.WriteVector(pos)
        net.Broadcast()
    end
end

if CLIENT then
    net.Receive("cool_removal_effect", function()
        local pos = net.ReadVector()
        local ef = EffectData()
        ef:SetOrigin(pos)
        util.Effect("cball_explode", ef, true, true)
        surface.PlaySound("buttons/button15.wav")
    end)
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay or 0.001))
    self:EmitSound("Weapon_AR2.Single", 80, 180, 0.5) -- Более лазерный звук

    if SERVER then
        -- Трассер обычный
        local tr = util.TraceLine({
            start = owner:GetShootPos(),
            endpos = owner:GetShootPos() + owner:GetAimVector()*4096,
            filter = owner
        })

        local ent = tr.Entity
        if IsValid(ent) and ent:GetClass() ~= "worldspawn" and ent:GetMoveType() ~= MOVETYPE_NONE then
            local pos = ent:GetPos()
            local class = ent:GetClass()
            ent:Remove()
            RemovalEffect(pos)
        else
            -- Просто пустой луч и эффект
            local ef = EffectData()
            ef:SetOrigin(tr.HitPos)
            ef:SetStart(owner:GetShootPos())
            ef:SetAttachment(1)
            util.Effect("ToolTracer", ef, true, true)
        end
    end
end

function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsAdmin() then return end
    self:SetNextSecondaryFire(CurTime() + 0.5)
    self:EmitSound("ambient/levels/labs/electric_explosion1.wav", 85, 120, 0.6)
    if SERVER then
        local tr = util.TraceLine({
            start = owner:GetShootPos(),
            endpos = owner:GetShootPos() + owner:GetAimVector()*2048,
            filter = owner
        })

        local center = tr.HitPos
        local count = 0
        for _, ent in ipairs(ents.FindInSphere(center, 100)) do
            if IsValid(ent)
            and ent:GetClass() ~= "worldspawn"
            and ent ~= owner
            and ent:GetMoveType() ~= MOVETYPE_NONE
            and not ent:IsPlayer() then
                local pos = ent:GetPos()
                local class = ent:GetClass()
                ent:Remove()
                RemovalEffect(pos)
                count = count + 1
            end
        end
            -- Визуальный эффект для области
        local ef = EffectData()
        ef:SetOrigin(center)
        ef:SetScale(1.5)
        util.Effect("HelicopterMegaBomb", ef)
    end
end
