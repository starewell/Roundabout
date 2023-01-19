local gfx <const> = playdate.graphics

local function entranceAnim(hero)
    local to = hero.moveDist
    local from = hero.dist
    for d=1,hero.entranceDuration do
        hero.dist = from+d/hero.entranceDuration*(to - from)
        coroutine.yield()
    end
end

local function exitAnim(hero)
    for d=1,hero.driftDelay*2 do coroutine.yield() end
    local from = hero.crankProd
    local to = 0
    if from > 180 then to = 360 end
    local dur = hero.crankProd
    if hero.crankProd > 180 then dur = 360 - hero.crankProd end
    print (dur)
    for f=1,dur do
        hero.crankProd = from+f/dur*(to - from)
        coroutine.yield()
    end
    from = hero.moveDist
    to = 170
    for d=1,hero.entranceDuration do
        hero.dist = from+d/hero.entranceDuration*(to - from)
        coroutine.yield()
    end
end

local function cooldown(hero)
    while hero.cooldown > 0 do
        hero.cooldown -= hero.cooldownRate
        coroutine.yield()
    end
    if hero.cooldown < 0 then hero.cooldown = 0 end
end

local function prodDrift(hero)
    for d=1,hero.driftDelay do coroutine.yield() end

    local sectorAngle = 360/hero.battleRing.divisions
    local from
    if hero.crankProd > 360/hero.battleRing.divisions * (hero.battleRing.divisions - .5) then
        from = -(360 - hero.crankProd)
    else
        from = hero.crankProd
    end

    local dest = (hero.sector - 1) * sectorAngle

    local t = math.abs(from - dest) / hero.driftSpeed
    for f=1,t do
    
        hero.crankProd = from+f/t*(dest - from)
        coroutine.yield()
    end
end

local function chargeAttack(hero)
    hero.attackCharge = 0
    hero.attacking = true
    local to = hero.attackDist
    local from = hero.dist
    hero.smearSprite.img:reset()
    hero.smearSprite.img:setPaused(true)
    while hero.attackCharge < hero.maxCharge do
        hero.attackCharge += hero.chargeRate * hero.moveSpeed
        hero.cooldown += hero.chargeRate * hero.moveSpeed
        hero.moveSpeed = 1 - hero.slowSpeed * hero.attackCharge/hero.maxCharge
        hero.dist = from+hero.attackCharge/hero.maxCharge*(to - from)
        coroutine.yield()
    end
end

local function attack(hero)
    hero.cooldown += hero.attackCost
    hero.moveSpeed = 1
    hero.attackCharge = 0
    hero.smearSprite.img:reset()
    hero.smearSprite.img:setPaused(false)
    local to = hero.moveDist
    local from = hero.dist
    for f=1,hero.attackSpeed do
        hero.dist = from+f/hero.attackSpeed*(to - from)
        coroutine.yield()
    end
    CoCreate(hero.co, "cooldown", cooldown, hero)
end

local function parryTiming(hero)
    hero.cooldown += hero.parryCost
    hero.parrying = true
    hero.smearSprite.img:reset()
    hero.smearSprite.img:setPaused(true)
    for d=1, hero.parryDelay do coroutine.yield() end
    if hero.smearSprite.img:getPaused() then
        hero.smearSprite.img:setPaused(false)
        hero.smearSprite.img:setFrame(#hero.smearSprite.img.image_table + 1)
    end
    hero.parrying = false
    CoCreate(hero.co, "cooldown", cooldown, hero)
end

local function damageFrames(img)
    local delay = 6
    for i=1,2 do
        img:setTableInverted(true)
        for d=1,delay do coroutine.yield() end
        img:setTableInverted(false)
        for d=1,delay do coroutine.yield() end
    end
end

class('Hero').extends()


function Hero:spriteAngle(slice)
    self.sprite.img:setFirstFrame(self.sprite.loops[slice].frames[1])
    self.sprite.img:setLastFrame(self.sprite.loops[slice].frames[2])
    self.smearSprite.img:setFirstFrame(self.smearSprite.loops[slice].frames[1])
    self.smearSprite.img:setLastFrame(self.smearSprite.loops[slice].frames[2])
end

function Hero:init(battleRing)
    self.battleRing = battleRing

    self.sprite = {
        img = AnimatedImage.new("Images/sprite-PC.gif", {delay = 100, loop = true}),
        loops = {
            {frames = {19, 24}, flip = gfx.kImageUnflipped},
            {frames = {13, 18}, flip = gfx.kImageFlippedX},
            {frames = {7, 12}, flip = gfx.kImageFlippedX},
            {frames = {1, 6}, flip = gfx.kImageUnflipped},
            {frames = {7, 12}, flip = gfx.kImageUnflipped},
            {frames = {13, 18}, flip = gfx.kImageUnflipped},
        }
    }
    assert(self.sprite.img)
    self.smearSprite = {
        img = AnimatedImage.new("Images/heroSmears.gif", {delay = 50, loop = false}),
        loops = {
            {frames = {1, 5}, flip = gfx.kImageFlippedY, topSort = true},
            {frames = {6, 11}, flip = gfx.kImageFlippedXY, topSort = true},
            {frames = {6, 11}, flip = gfx.kImageFlippedX, topSort = false},
            {frames = {1, 5}, flip = gfx.kImageUnflipped, topSort = false},
            {frames = {6, 11}, flip = gfx.kImageUnflipped, topSort = false},
            {frames = {6, 11}, flip = gfx.kImageFlippedY, topSort = true},
        }
    }
    assert(self.smearSprite.img)
    self.smearSprite.img:setTableInverted(true)

    self.pos = {x=self.battleRing.center.x,y=170}
    self.sector = 4
    self.dist = 160
    self.crankProd = 180

    self.moveSpeed = 1
    self.moveDist = 96
    self.slowSpeed = 0.5

    self.attacking = false
    self.attackDist = 32
    self.attackSpeed = 20
    self.attackDmg = 5

    self.chargeRate = 0.25
    self.maxCharge = 10
    self.attackCharge = 0

    self.driftDelay = 15
    self.driftSpeed = 2

    self.hp = 100

    self.moveCost = 5
    self.attackCost = 5
    self.parryCost = 5
    self.parryHitCost = 20

    self.cooldownRate = 1
    self.cooldown = 0

    self.parrying = false
    self.parryDelay = 15

    self.entranceDuration = 50

    self.co = {
        drift = nil,
        attack = nil,
        damaged = nil,
        charge = nil,
        parry = nil,
        cooldown = nil,
        entrance = nil,
        exit = nil
    }

    -- battle control scheme that is pushed onto playdate's battleHandler stack when in battle
    self.battleInputHandler = {
        -- crank input
            cranked = function(change, acceleratedChange)
        -- apply crank delta to stored crank product var at a ratio of 180 to 1 slice
                self.crankProd += change/(self.battleRing.divisions) * self.moveSpeed
        -- wrap our product inside the bounds of 0-360
                if self.crankProd > 360 then
                    self.crankProd -= 360
                elseif self.crankProd < 0 then
                    self.crankProd += 360
                end
                if (change ~= 0 and self.battleRing.state == 'battling') then
                    CoCreate(self.co, "drift", prodDrift, self)
                end
            end,
            upButtonDown = function() self:chargeAttack() end,
            upButtonUp = function() self:releaseAttack(self.battleRing.monster) end,
            downButtonDown = function() self:parry() end
        }

    self:spriteAngle(4)
end

function Hero:entrance()
    CoCreate(self.co, 'entrance', entranceAnim, self)
end

function Hero:exit()
    self.co.drift = nil
    CoCreate(self.co, 'exit', exitAnim, self)
end

function Hero:slain()
    self.co = {}
end

function Hero:takeDmg(dmg)
    self.hp -= dmg
    SoundManager:playSound(SoundManager.kSoundHeroDmg)
    if self.hp <= 0 then
        self.hp = 0
        self.battleRing:endBattle(false)
        self:slain()
    end
    CoCreate(self.co, "damaged", damageFrames, self.sprite.img)
end

function Hero:chargeAttack()
-- if the hero is able to initiate a new action
    if self.cooldown <= 0 then
        self.co.regen = nil
        self.co.drift = nil
        CoCreate(self.co, "charge", chargeAttack, self)
    end
end

function Hero:releaseAttack(target)
    if (self.co.attack==nil and self.attacking) then
-- reset affiliated coroutines and bool
        self.co.charge = nil
        self.attacking = false
-- damage and audio of action
        target:takeDmg(self.attackDmg + self.attackCharge, self.sector)
        SoundManager:playSound(SoundManager.kSoundHeroSwipe)
-- animation and translation of hero pos        
        CoCreate(self.co, "attack", attack, self)
        self.smearSprite.img:reset()
    end
end

function Hero:parry()
-- if the hero is able to initiate a new action
    if self.cooldown <= 0 then
        self.co.charge = nil
        self.co.regen = nil
        self.co.drift = nil
        CoCreate(self.co, "parry", parryTiming, self)
        SoundManager:playSound(SoundManager.kSoundGuardHold)
    end
end

function Hero:parryHit()
    self.cooldown += self.parryHitCost
    self.smearSprite.img:setPaused(false)
    SoundManager:playSound(SoundManager.kSoundPerfectGuard)
end

-- translates crankProd to a position along a circumference
function Hero:moveByCrank()
-- calculate what sector hero is in
    local sectorAngle = 60
    local prod = (self.crankProd+sectorAngle/2)/(6 * 10)
    prod = math.floor(prod) + 1
    if prod > 6 then prod = 1 end
    if self.battleRing.state ~= 'battling' then
        for i=1, 1 do 
            if prod == 3 then prod = 5 break end  if prod == 5 then prod = 3 break end  if prod == 2 then prod = 3 break end  if prod == 6 then prod = 5 break end if prod == 1 then prod = 4 break end
        end
    end
-- hero changes sectors
    if (prod ~= self.sector) then
        self.cooldown += self.moveCost
        self:spriteAngle(prod)
        SoundManager:playSound(SoundManager.kSoundDodgeRoll)
    end
-- calculate hero's position on circumference
    local _x = self.dist * math.cos((self.crankProd-90)*3.14159/180) + self.battleRing.center.x
    local _y = self.dist * math.sin((self.crankProd-90)*3.14159/180) + self.battleRing.center.y

    self.sector = prod
    self.pos = {x=_x, y=_y}
end


function Hero:update()
    self:moveByCrank()
    for co,f in pairs(self.co) do
        if co~=nil then CoRun(self.co, co) end
    end
    if self.co.attack == nil and self.attackCharge <= 0 and self.co.parry == nil and self.co.cooldown == nil  and self.cooldown > 0 then
        CoCreate(self.co, "cooldown", cooldown, self)
    end
end

function Hero:draw()
    self.sprite.img:drawCentered(self.pos.x, self.pos.y, self.sprite.loops[self.sector].flip)
    if not self.smearSprite.img:loopFinished() or self.smearSprite.img:getPaused() then
        self.smearSprite.img:drawCentered(self.pos.x, self.pos.y, self.smearSprite.loops[self.sector].flip)
    end
end