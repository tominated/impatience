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

function handSprite:animateBy(x, y)
  local line = playdate.geometry.lineSegment.new(self.x, self.y, self.x + x, self.y + y)
  local anim = gfx.animator.new(150, line, playdate.easingFunctions.outQuint)
  handSprite:setAnimator(anim)
end

GameState = {}
function GameState:new()
  local gameState = {
    deck = Card.getShuffledDeck(),
    waste = {},
    foundations = { {}, {}, {}, {} },
    piles = { {}, {}, {}, {}, {}, {}, {} }

  }

  self.__index = self
  return setmetatable(gameState, self)
end

function GameState:deal()
  for i, pile in ipairs(self.piles) do
    for _ = 1, i do
      table.insert(pile, table.remove(self.deck))
    end
  end
end

local gameState = GameState:new()
gameState:deal()

local outerPadding = 7
local width = 44
local gap = 6

for i, pile in ipairs(gameState.piles) do
  for j, card in ipairs(pile) do
    local sprite = gfx.sprite.new(card:createImage())
    sprite:setCenter(0, 0)

    local x = outerPadding + ((i - 1) * (width + gap))
    local y = outerPadding + ((j - 1) * 13)
    sprite:moveTo(x, y)

    sprite:add()
  end
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
