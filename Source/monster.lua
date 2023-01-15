import "CoreLibs/graphics"
local gfx <const> = playdate.graphics


local function coroutineCreate(parent, co, f, p1, p2, p3, p4)
    parent[co] = coroutine.create(f)
    coroutine.resume(parent[co], p1, p2, p3, p4)
end

local function coroutineRun(parent, co)
    if(parent[co] and coroutine.status(parent[co])~='dead') then
        coroutine.resume(parent[co])
    else parent[co]=nil end
end

class("Monster").extends()

local function attack(monster, sequence, hero)
    for b=1, #sequence do
        local dmgdSectors = {}
        local vulnSectors = {}

        if sequence[b].attacking ~= nil then
            for s=1, #sequence[b].attacking do
                monster.attacks[sequence[b].attacking[s]].img:reset()
                dmgdSectors[#dmgdSectors+1] = sequence[b].attacking[s]
            end
        end
        if sequence[b].vulnerable ~= nil then
            for s=1, #sequence[b].vulnerable do
                monster.vulnerability[sequence[b].vulnerable[s]].img:setPaused(false)
                vulnSectors[#vulnSectors+1] = monster.vulnerability[sequence[b].vulnerable[s]]
                monster.vulnerableSectors[#monster.vulnerableSectors+1] = sequence[b].vulnerable[s]
            end
        end

        for d=1, monster.patternDelay do coroutine.yield() end

        for k,sect in ipairs(dmgdSectors) do
            if (hero.sector == sect) then
                if hero.parrying == false then
                    hero:takeDmg(monster.dmg)
                else
                    monster:takeDmg(hero.attackDmg, hero.sector)
                    SoundManager:playSound(SoundManager.kSoundPerfectGuard)
                end
            end
        end
        for k,sect in ipairs(vulnSectors) do
            sect.img:setPaused(true)
            monster.vulnerableSectors = {}
        end
    end
end

local function attackPattern(monster, hero)
    local sequence = {{attacking = {2, 3}, vulnerable = {1, 4}}, {attacking = {4, 5}, vulnerable = {3, 6}}, {attacking = {6, 1}, vulnerable = {5, 2}}, {}}
    for i=1, 20 do
        coroutineCreate(monster.co, "attack", attack, monster, sequence, hero)
        for d=1, monster.patternDelay * #sequence do coroutine.yield() end
    end
end


function Monster:init()

-- variables
    self.sprite = {
        img = nil
    }
    self.maxHP = 100
    self.hp = 100
    self.attacks = {
        {img = nil, flip = gfx.kImageFlippedY}, --n
        {img = nil, flip = gfx.kImageFlippedXY}, --ne
        {img = nil, flip = gfx.kImageFlippedX}, --se
        {img = nil, flip = gfx.kImageUnflipped}, --s
        {img = nil, flip = gfx.kImageUnflipped}, --sw
        {img = nil, flip = gfx.kImageFlippedY}  --nw
    }
    self.vulnerability = {
        {img = nil, pos = {x=0,y=0}},
        {img = nil, pos = {x=0,y=0}},
        {img = nil, pos = {x=0,y=0}},
        {img = nil, pos = {x=0,y=0}},
        {img = nil, pos = {x=0,y=0}},
        {img = nil, pos = {x=0,y=0}}
    }
    self.vulnerableSectors = {}
    self.patternDelay = 60
    self.co = {
        attackPattern = nil,
        attack = nil,
        damaged = nil
    }
    self.dmg = 10

-- initialization
    self.sprite.img = gfx.image.new("images/monster.png")
    assert(self.sprite.img)

    self.attacks[1].img = AnimatedImage.new("Images/attackSouth.gif", {delay = 100, loop = false})
    assert(self.attacks[1])
    self.attacks[2].img = AnimatedImage.new("Images/attackSouthWest.gif", {delay = 100, loop = false})
    assert(self.attacks[2])
    self.attacks[3].img = AnimatedImage.new("Images/attackSouthWest.gif", {delay = 100, loop = false})
    assert(self.attacks[3])
    self.attacks[4].img = AnimatedImage.new("Images/attackSouth.gif", {delay = 100, loop = false})
    assert(self.attacks[4])
    self.attacks[5].img = AnimatedImage.new("Images/attackSouthWest.gif", {delay = 100, loop = false})
    assert(self.attacks[5])
    self.attacks[6].img = AnimatedImage.new("Images/attackSouthWest.gif", {delay = 100, loop = false})
    assert(self.attacks[6])

    for i=1, #self.vulnerability do
        self.vulnerability[i].img = AnimatedImage.new("Images/vulnerability.gif", {delay = 100, loop = true})
        self.vulnerability[i].img:setPaused(true)
        local sectorAngle = 60
        local _x = 42 * math.cos((sectorAngle*(i-1)-90)*3.14159/180) + 265
        local _y = 42 * math.sin((sectorAngle*(i-1)-90)*3.14159/180) + 120
        self.vulnerability[i].pos = {x=_x, y=_y}
    end
end

local function damageFrames(img)
    local delay = 6
    for i=1,2 do
        img:setInverted(true)
        for d=1,delay do coroutine.yield() end
        img:setInverted(false)
        for d=1,delay do coroutine.yield() end
    end
end

function Monster:startAttacking(hero)
    coroutineCreate(self.co, "attackPattern", attackPattern, self, hero)
end

function Monster:takeDmg(dmg, sector)
    spec:clear()
    local dmgScale = 0.5
    if #self.vulnerableSectors >= 1 then
        for i=1, #self.vulnerableSectors do
            if sector == self.vulnerableSectors[i] then
                SoundManager:playSound(SoundManager.kSoundCriticalHit)
                dmgScale = 1.5
                break
            else
                SoundManager:playSound(SoundManager.kSoundIneffectiveHit)
            end
        end
    else
        print ("no sectors")
        SoundManager:playSound(SoundManager.kSoundIneffectiveHit)
    end

    dmg *= dmgScale
    self.hp -= dmg
    spec:print(dmg.." dmg")
    if dmgScale > 1 then spec:print("critical hit!") end

    coroutineCreate(self.co, "damaged", damageFrames, self.sprite.img)
end

function Monster:drawAttacks()
    for i, v in ipairs(self.attacks) do
        if not v.img:loopFinished() then
            v.img:drawCentered(265, 120, v.flip)
        end
    end

    for i, v in ipairs(self.vulnerability) do
        if not v.img:getPaused() then
            v.img:drawAnchored(v.pos.x, v.pos.y, 0.3125, 0.625)
        end
    end
end

function Monster:update()
    if (self.co.attackPattern~=nil) then coroutineRun(self.co, "attackPattern") end
    if (self.co.attack~=nil) then coroutineRun(self.co, "attack") end
    if (self.co.damaged~=nil) then coroutineRun(self.co, "damaged") end
end