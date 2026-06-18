-- TRAIN Free: Non-admin version - just spawns a train without explosion
-- Version 1.3 addition

SWEP.PrintName = "TRAIN Free"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — вызвать поезд. Один вызов каждые 15 секунд. Без взрыва."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Slot = 1
SWEP.SlotPos = 2

SWEP.ViewModel = "models/weapons/crossbow.mdl"
SWEP.WorldModel = "models/props_trainstation/train001.mdl"
SWEP.UseHands = true

SWEP.TrainSpeed = 3500
SWEP.Cooldown = 15

function SWEP:Initialize()
    self:SetHoldType("rpg")
    self.LastTrainTime = 0
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local curTime = CurTime()
    if curTime - (self.LastTrainTime or 0) < self.Cooldown then
        local remaining = math.ceil(self.Cooldown - (curTime - self.LastTrainTime))
        owner:ChatPrint("TRAIN Free: подождите " .. remaining .. " сек.")
        return
    end

    self:SetNextPrimaryFire(curTime + (self.Primary.Delay or 0))
    self.LastTrainTime = curTime

    local tr = owner:GetEyeTrace()
    if not tr.Hit then
        owner:ChatPrint("TRAIN Free: нет цели для вызова поезда.")
        return
    end

    local targetPos = tr.HitPos

    local spawnPos = targetPos + Vector(
        math.random(-600, 600),
        math.random(-600, 600),
        3500
    )

    local train = ents.Create("prop_physics")
    if not IsValid(train) then
        owner:ChatPrint("TRAIN Free: не удалось создать поезд.")
        return
    end

    train:SetModel("models/props_trainstation/train001.mdl")
    train:SetPos(spawnPos)
    train:SetAngles(Angle(0, math.random(0, 360), 0))
    train:Spawn()

    local phys = train:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(15000)
        phys:Wake()
        phys:EnableGravity(true)

        local dir = (targetPos - spawnPos):GetNormalized()
        phys:SetVelocity(dir * self.TrainSpeed + Vector(0, 0, -600))
    end

    train:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)

    local timerName = "TRAIN_Free_Move_" .. train:EntIndex()

    train._TRAIN_TargetPos = targetPos
    train._TRAIN_StartTime = CurTime()

    timer.Create(timerName, 0.05, 0, function()
        if not IsValid(train) then timer.Remove(timerName) return end

        if (CurTime() - train._TRAIN_StartTime) >= 15 then
            SafeRemoveEntity(train)
            timer.Remove(timerName)
            return
        end

        local curPos = train:GetPos()
        local dist = curPos:DistToSqr(train._TRAIN_TargetPos)

        if dist <= (200 * 200) then
            SafeRemoveEntity(train)
            timer.Remove(timerName)
            return
        end

        local phys2 = train:GetPhysicsObject()
        if IsValid(phys2) then
            local desiredVel = (train._TRAIN_TargetPos - curPos):GetNormalized() * self.TrainSpeed
            local curVel = phys2:GetVelocity()
            local newVel = LerpVector(0.06, curVel, desiredVel)

            if curPos.z > train._TRAIN_TargetPos.z + 60 then
                newVel.z = newVel.z - 200
            end

            phys2:SetVelocity(newVel)
        end
    end)

    net.Start("tuns_train_free_warning")
        net.WriteVector(targetPos)
    net.Broadcast()

    owner:EmitSound("buttons/button14.wav", 90, 100)
    owner:ChatPrint("TRAIN Free вызван!")
end

function SWEP:SecondaryAttack()
end

if SERVER then
    util.AddNetworkString("tuns_train_free_warning")
end

if CLIENT then
    local TRAIN_RADIUS = 1200

    net.Receive("tuns_train_free_warning", function()
        local targetPos = net.ReadVector()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local dist = ply:GetPos():Distance(targetPos)
        if dist > TRAIN_RADIUS * 2 then return end

        local warningText = "🚂 ПОЕЗД ЕДЕТ! 🚂"
        sound.Play("buttons/button6.wav", ply:GetPos(), 75, 100, 1, 0)

        hook.Add("HUDPaint", "TRAIN_Free_Warning_" .. game.GetMap(), function()
            local alpha = math.Clamp(dist / (TRAIN_RADIUS * 2), 0.2, 1)
            draw.SimpleText(warningText, "DermaLarge", ScrW() / 2, ScrH() * 0.15, Color(255, 60, 60, 255 * alpha), TEXT_ALIGN_CENTER)
        end)

        timer.Simple(8, function()
            hook.Remove("HUDPaint", "TRAIN_Free_Warning_" .. game.GetMap())
        end)
    end)
end