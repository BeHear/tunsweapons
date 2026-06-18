-- ОГНЕМЕТ для Garry's Mod — поджигает, без взрыва, с корректной моделью

SWEP.PrintName = "TF-12 Flamethrower"
SWEP.Author = "GPT"
SWEP.Instructions = "Удерживайте ЛКМ чтобы выжечь всё. Эффективен в ближнем бою."
SWEP.Category = "TUNS Weapons"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Primary.ClipSize = 150
SWEP.Primary.DefaultClip = 600
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.04
SWEP.Primary.Damage = 6
SWEP.Primary.Recoil = 0.1
SWEP.Primary.NumShots = 1
SWEP.Primary.Spread = 0.10
SWEP.Primary.MaxSpread = 0.14
SWEP.Primary.SpreadIncrease = 0.003
SWEP.Primary.SpreadRecovery = 0.01
SWEP.Primary.Force = 2

SWEP.CrouchSpreadMul = 0.5

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "None"

SWEP.Weight = 7
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Slot = 2
SWEP.SlotPos = 2

-- Используем встроенные модели, максимально похожие на огнемёт (например, модель М249 из CS:S)
SWEP.ViewModel = "models/weapons/cstrike/c_mach_m249para.mdl"
SWEP.WorldModel = "models/weapons/w_mach_m249para.mdl"
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("ar2")
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

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    local maxSpread = self:GetModifiedMaxSpread()
    self.CurrentSpread = math.min(
        (self.CurrentSpread or self.Primary.Spread) + self.Primary.SpreadIncrease, 
        maxSpread
    )
    self.LastFireTime = CurTime()

    self:EmitSound("ambient/fire/ignite.wav", 75, math.random(96, 106), 1, CHAN_WEAPON)
    self:ShootFireFlame(self.Primary.Damage, self:GetModifiedSpread())
    self:TakePrimaryAmmo(1)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Think()
    if not self.LastFireTime then return end
    local baseSpread = self:GetModifiedBaseSpread()
    if (self.CurrentSpread or self.Primary.Spread) > baseSpread then
        self.CurrentSpread = math.max(
            baseSpread, 
            (self.CurrentSpread or self.Primary.Spread) - self.Primary.SpreadRecovery * FrameTime()
        )
    end
end

function SWEP:ShootFireFlame(damage, aimcone)
    if not IsValid(self.Owner) then return end

    local shootPos = self.Owner:GetShootPos()
    local aimVec = self.Owner:GetAimVector()
    local flameRange = 180
    local numFlames = 5

    for i = 1, numFlames do
        local spread = aimcone * 2.5
        local dir = aimVec + VectorRand() * spread
        dir:Normalize()
        local endPos = shootPos + dir * flameRange

        local tr = util.TraceLine({
            start = shootPos,
            endpos = endPos,
            filter = self.Owner
        })

        if SERVER then
            local fx = EffectData()
            fx:SetOrigin(tr.HitPos)
            fx:SetStart(shootPos)
            fx:SetNormal(dir)
            fx:SetMagnitude(2)
            fx:SetScale(2.8)
            fx:SetRadius(12)
            util.Effect("cball_explode", fx, true, true)

            if tr.Hit then
                if IsValid(tr.Entity) then
                    local dmginfo = DamageInfo()
                    dmginfo:SetDamage(damage)
                    dmginfo:SetDamageType(DMG_BURN)
                    dmginfo:SetAttacker(self.Owner)
                    dmginfo:SetInflictor(self)
                    dmginfo:SetDamagePosition(tr.HitPos)
                    tr.Entity:TakeDamageInfo(dmginfo)
                    if tr.Entity:IsPlayer() or tr.Entity:IsNPC() then
                        tr.Entity:Ignite(1.5, 16)
                    end
                end

                if tr.HitWorld and math.random(1, 3) == 1 then
                    local flame = ents.Create("env_fire")
                    if IsValid(flame) then
                        flame:SetPos(tr.HitPos + tr.HitNormal * 4)
                        flame:SetKeyValue("spawnflags", tostring(128 + 32))
                        flame:SetKeyValue("firesize", "22")
                        flame:SetKeyValue("fireattack", "9")
                        flame:SetKeyValue("health", "20")
                        flame:SetKeyValue("damagescale", "3.6")
                        flame:SetKeyValue("firetype", "0")
                        flame:SetOwner(self.Owner)
                        flame:Spawn()
                        flame:Fire("StartFire", "", 0)
                        timer.Simple(0.8, function()
                            if IsValid(flame) then flame:Remove() end
                        end)
                    end
                end
            end
        end
    end
    self:ShootEffects()
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local vm = owner:GetViewModel()
    if not IsValid(vm) then return end
    timer.Simple(vm:SequenceDuration(), function()
        if IsValid(self) then
            self.CurrentSpread = self.Primary.Spread
        end
    end)
end

function SWEP:SecondaryAttack()
    -- Нет вторичной атаки
end
