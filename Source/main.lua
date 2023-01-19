import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "animatedimage"
import "battleRing"
import "soundManager"
import "gameManager"
import "spectacle"
import "coroutineShortcuts"
spec = Spectacle({font = "Fonts/FenwickWoodtype", line_height = 1.2, lines = 2, background=playdate.graphics.kColorWhite})


local gfx <const> = playdate.graphics
local timer <const> = playdate.timer


local gameManager = GameManager()

local function setup()
-- set frame rate; sync w/ AnimatedImage delay
    playdate.display.setRefreshRate(50)
    gfx.setBackgroundColor(gfx.kColorWhite)

-- Initialize crank alert
    playdate.ui.crankIndicator:start()
end

setup()

function playdate.update()
-- draw all sprites; clean into loop w/ classes
    gfx.clear()

    gameManager:update()

-- Display crank alert if crank is docked   
    if playdate.isCrankDocked() then
        playdate.ui.crankIndicator:update()
    end

    timer.updateTimers()
end