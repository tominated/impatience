import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "card"

local gfx <const> = playdate.graphics

local handSprite = gfx.sprite.new(gfx.image.new("images/hand"))
local handAnimLine = playdate.geometry.lineSegment.new(200, 118, 200, 122)
local handAnim = gfx.animator.new(500, handAnimLine, playdate.easingFunctions.inOutQuad)
handAnim.reverses = true
handAnim.repeatCount = -1
handSprite:setZIndex(100)
handSprite:setAnimator(handAnim)
handSprite:add()

local cardSprites = {
  gfx.sprite.new(Card:new("hearts", 1):createImage()),
  gfx.sprite.new(Card:new("spades", 7):createImage()),
  gfx.sprite.new(Card:new("diamonds", 13):createImage()),
  gfx.sprite.new(Card:new("clubs", 2):createImage()),
}

for i, sprite in ipairs(cardSprites) do
  local offset = i * 10
  sprite:setCenter(0, 0)
  sprite:moveTo(offset + 7, offset + 7)
  sprite:add()
end

function handSprite:animateBy(x, y)
  local line = playdate.geometry.lineSegment.new(self.x, self.y, self.x + x, self.y + y)
  local anim = gfx.animator.new(150, line, playdate.easingFunctions.outQuint)
  handSprite:setAnimator(anim)
end

function playdate.update()
  local distance = 40

  if playdate.buttonIsPressed(playdate.kButtonUp) then
    handSprite:animateBy(0, -distance)
  end
  if playdate.buttonIsPressed(playdate.kButtonRight) then
    handSprite:animateBy(distance, 0)
  end
  if playdate.buttonIsPressed(playdate.kButtonDown) then
    handSprite:animateBy(0, distance)
  end
  if playdate.buttonIsPressed(playdate.kButtonLeft) then
    handSprite:animateBy(-distance, 0)
  end

  playdate.graphics.sprite.update()
end
