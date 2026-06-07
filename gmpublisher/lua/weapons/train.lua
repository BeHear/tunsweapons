-- TRAIN weapon: epic calling card — one train per minute with shockwave and multi-explosions

SWEP.PrintName = "TRAIN"
SWEP.Author = "GPT"
SWEP.Instructions = "ЛКМ — вызвать поезд-катастрофу. Один вызов в минуту. Взорвёт всё в радиусе."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminOnly = true
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

SWEP.Weight = 10
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Slot = 1
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/crossbow.mdl"
SWEP.WorldModel = "models/props_trainstation/train001.mdl"
SWEP.UseHands = true

SWEP.TrainExplosiveRadius = 2600
SWEP.TrainExplosiveDamage = 66000
SWEP.TrainImpactSound = "ambient/explosions/explode_4.wav"

function SWEP:Initialize()
    self:SetHoldType("rpg")
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsAdmin() then return end

    self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay or 0))

    local tr = owner:GetEyeTrace()
    if not tr.Hit then
        owner:ChatPrint("TRAIN: нет цели для вызова поезда.")
        return
    end

    local targetPos = tr.HitPos

    local spawnPos = targetPos + Vector(
        math.random(-800, 800),
        math.random(-800, 800),
        4500
    )

    local train = ents.Create("prop_physics")
    if not IsValid(train) then
        owner:ChatPrint("TRAIN: не удалось создать поезд.")
        return
    end

    local modelCandidates = {
        "models/props_trainstation/train001.mdl",
        "models/props_vehicles/train_engine.mdl",
        "models/props_lab/hookedsawblade.mdl",
        "models/props_combine/combine_interface.mdl"
    }
    local chosenModel = modelCandidates[1]
    for _,m in ipairs(modelCandidates) do
        if file.Exists(m, "GAME") then
            chosenModel = m
            break
        end
    end

    train:SetModel(chosenModel)
    train:SetPos(spawnPos)
    train:SetAngles(Angle(0, math.random(0, 360), 0))
    train:Spawn()

    local phys = train:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(20000)
        phys:Wake()
        phys:EnableGravity(true)
        phys:SetDragCoefficient(0.005)

        local dir = (targetPos - spawnPos):GetNormalized()
        phys:SetVelocity(dir * 4000 + Vector(0, 0, -800))
    end

    train:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
    train:SetOwner(owner)

    train._TRAIN_TargetPos = targetPos
    train._TRAIN_Owner = owner
    train._TRAIN_StartTime = CurTime()

    local timerName = "TRAIN_Move_"..train:EntIndex()

    train:AddCallback("PhysicsCollide", function(ent, data)
        if not IsValid(ent) then return end
        if ent._TRAIN_Exploded then return end

        local speed = data.Speed or 0
        if speed > 80 then
            ent._TRAIN_Exploded = true
            local pos = ent:GetPos()

            self:EpicExplosion(pos, ent._TRAIN_Owner)

            SafeRemoveEntity(ent)
            timer.Remove(timerName)
        end
    end)

    timer.Create(timerName, 0.05, 0, function()
        if not IsValid(train) then timer.Remove(timerName) return end

        if train._TRAIN_Exploded then
            timer.Remove(timerName)
            return
        end

        local curPos = train:GetPos()
        local dist = curPos:DistToSqr(train._TRAIN_TargetPos)

        if dist <= (350 * 350) then
            train._TRAIN_Exploded = true
            local pos = train:GetPos()

            self:EpicExplosion(pos, train._TRAIN_Owner)

            SafeRemoveEntity(train)
            timer.Remove(timerName)
            return
        end

        if (CurTime() - train._TRAIN_StartTime) >= 20 then
            train._TRAIN_Exploded = true
            local pos = train:GetPos()

            self:EpicExplosion(pos, train._TRAIN_Owner)

            SafeRemoveEntity(train)
            timer.Remove(timerName)
            return
        end

        local phys2 = train:GetPhysicsObject()
        if IsValid(phys2) then
            local desiredVel = (train._TRAIN_TargetPos - curPos):GetNormalized() * 4000
            local curVel = phys2:GetVelocity()
            local newVel = LerpVector(0.04, curVel, desiredVel)

            if curPos.z > train._TRAIN_TargetPos.z + 80 then
                newVel.z = newVel.z - 300
            end

            phys2:SetVelocity(newVel)
        end
    end)

    net.Start("tuns_train_warning")
        net.WriteVector(targetPos)
    net.Broadcast()

    owner:EmitSound("buttons/button14.wav", 90, 100)
    owner:ChatPrint("TRAIN вызван. Всем бежать!")
end

function SWEP:EpicExplosion(pos, attacker)
    util.ScreenShake(pos, 15000, 255, 5, self.TrainExplosiveRadius)

    local fx = EffectData()
    fx:SetOrigin(pos)
    util.Effect("Explosion", fx, true, true)

    sound.Play("ambient/explosions/explode_4.wav", pos, 140, 90)
    sound.Play("ambient/explosions/explode_2.wav", pos, 130, 80)

    util.BlastDamage(self, attacker or self, pos, self.TrainExplosiveRadius, self.TrainExplosiveDamage)

    local subCount = 12
    local subRadius = self.TrainExplosiveRadius * 0.7
    for i = 1, subCount do
        local angle = (360 / subCount) * i
        local offset = Vector(
            math.cos(math.rad(angle)) * (subRadius * 0.4),
            math.sin(math.rad(angle)) * (subRadius * 0.4),
            math.random(-60, 60)
        )
        local subPos = pos + offset

        timer.Simple(i * 0.08, function()
            if not IsValid(self) then return end

            local subFx = EffectData()
            subFx:SetOrigin(subPos)
            util.Effect("Explosion", subFx, true, true)
            sound.Play("ambient/explosions/explode_3.wav", subPos, 120, math.random(85, 115))

            util.BlastDamage(self, attacker or self, subPos, subRadius * 0.45, self.TrainExplosiveDamage * 0.6)
        end)
    end

    net.Start("tuns_train_flash")
        net.WriteVector(pos)
        net.WriteFloat(self.TrainExplosiveRadius)
    net.Broadcast()
end

function SWEP:SecondaryAttack()
end

if SERVER then
    util.AddNetworkString("tuns_train_warning")
    util.AddNetworkString("tuns_train_flash")
end

if CLIENT then
    local TRAIN_RADIUS = 1600

    net.Receive("tuns_train_warning", function()
        local targetPos = net.ReadVector()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local dist = ply:GetPos():Distance(targetPos)
        if dist > TRAIN_RADIUS * 2 then return end

        local warningText = "🚂 ПОЕЗД ИДЁТ! 🚂"
        sound.Play("buttons/button6.wav", ply:GetPos(), 75, 100, 1, 0)

        hook.Add("HUDPaint", "TRAIN_Warning_"..game.GetMap(), function()
            local alpha = math.Clamp(dist / (TRAIN_RADIUS * 2), 0.2, 1)
            draw.SimpleText(warningText, "DermaLarge", ScrW() / 2, ScrH() * 0.15, Color(255, 60, 60, 255 * alpha), TEXT_ALIGN_CENTER)
            draw.SimpleText("УБЕГАЙ!", "DermaLarge", ScrW() / 2, ScrH() * 0.15 + 40, Color(255, 200, 0, 255 * alpha), TEXT_ALIGN_CENTER)
        end)

        timer.Simple(12, function()
            hook.Remove("HUDPaint", "TRAIN_Warning_"..game.GetMap())
        end)
    end)

    net.Receive("tuns_train_flash", function()
        local pos = net.ReadVector()
        local radius = net.ReadFloat()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local dist = ply:GetPos():Distance(pos)
        if dist > radius * 1.5 then return end

        local flashIntensity = math.Clamp(1 - dist / (radius * 1.5), 0.3, 1)

        local col = Color(255, 255, 255, flashIntensity * 140)

        hook.Add("HUDPaint", "TRAIN_Flash_"..game.GetMap(), function()
            surface.SetDrawColor(col)
            surface.DrawRect(0, 0, ScrW(), ScrH())
        end)

        timer.Simple(0.6, function()
            hook.Remove("HUDPaint", "TRAIN_Flash_"..game.GetMap())
        end)
    end)
end
