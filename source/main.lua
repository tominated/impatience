import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "card"

local gfx <const> = playdate.graphics

local handSprite = gfx.sprite.new(gfx.image.new("images/cursor-point"))
handSprite:setZIndex(100)
handSprite:add()

function handSprite:animateBy(x, y)
  local line = playdate.geometry.lineSegment.new(self.x, self.y, self.x + x, self.y + y)
  local anim = gfx.animator.new(150, line, playdate.easingFunctions.outQuint)
  handSprite:setAnimator(anim)
end

function handSprite:animateTo(x, y)
  local line = playdate.geometry.lineSegment.new(self.x, self.y, x, y)
  local anim = gfx.animator.new(150, line, playdate.easingFunctions.outQuint)
  handSprite:setAnimator(anim)
end

CardState = {}
function CardState:new(card)
  local image = Card.createHiddenImage()
  local sprite = gfx.sprite.new(image)
  sprite:setCenter(0, 0)

  local cardState = {
    card = card,
    sprite = sprite,
    revealed = false
  }

  self.__index = self
  return setmetatable(cardState, self)
end

function CardState:reveal()
  local image = self.card:createImage()
  self.sprite:setImage(image)
  self.sprite:markDirty()
  self.revealed = true
end

CursorState = {
  onDeck = { position = "deck", x = 7 + 20, y = 20 },
  onWaste = { position = "waste", x = 7 + 44 + 7 + 20, y = 20 },
}

function CursorState.onFoundation(foundationIndex)
  local x = 7 + 20 + ((foundationIndex + 2) * (44 + 6))
  return { position = "foundation", foundationIndex = foundationIndex, x = x, y = 20 }
end

function CursorState.onPile(pileIndex, cardIndex)
  local x = 7 + 26 + ((pileIndex - 1) * (44 + 6))
  local y = 78 + ((cardIndex - 1) * 13)
  return { position = "pile", pileIndex = pileIndex, cardIndex = cardIndex, x = x, y = y }
end

GameState = {}
function GameState:new()
  local gameState = {
    deck = Card.getShuffledDeck(),
    waste = {},
    foundations = { {}, {}, {}, {} },
    piles = { {}, {}, {}, {}, {}, {}, {} },
    cursor = CursorState.onDeck
  }

  self.__index = self
  return setmetatable(gameState, self)
end

function GameState:deal()
  for i, pile in ipairs(self.piles) do
    for _ = 1, i do
      local card = table.remove(self.deck)
      local cardState = CardState:new(card)
      table.insert(pile, cardState)
    end

    pile[#pile]:reveal()
  end
end

function GameState:nextCursorPositions()
  local piles = self.piles

  if self.cursor.position == "deck" then
    local cardIndex = #piles[1]
    return {
      right = CursorState.onFoundation(1),
      down = CursorState.onPile(1, cardIndex)
    }
  elseif self.cursor.position == "waste" then
    local cardIndex = #piles[2]
    return {
      left = CursorState.onDeck,
      right = CursorState.onFoundation(1),
      down = CursorState.onPile(2, cardIndex)
    }
  elseif self.cursor.position == "foundation" then
    local foundationIndex = self.cursor.foundationIndex
    local left = CursorState.onFoundation(foundationIndex - 1)
    local right = CursorState.onFoundation(foundationIndex + 1)

    -- Piles are offset by 3 cards
    local pileIndex = foundationIndex + 3
    local pile = self.piles[pileIndex]

    if foundationIndex == 1 then
      left = CursorState.onDeck
    elseif foundationIndex == 4 then
      right = nil
    end

    return {
      left = left,
      right = right,
      down = CursorState.onPile(pileIndex, #pile)
    }
  elseif self.cursor.position == "pile" then
    local pileIndex = self.cursor.pileIndex
    local currentPile = piles[pileIndex]
    local cardIndex = self.cursor.cardIndex
    local left = nil
    local right = nil
    local up = nil
    local down = nil

    if pileIndex > 1 then
      local leftPileIndex = pileIndex - 1
      left = CursorState.onPile(leftPileIndex, #piles[leftPileIndex])
    end

    if pileIndex < 7 then
      local rightPileIndex = pileIndex + 1
      right = CursorState.onPile(rightPileIndex, #piles[rightPileIndex])
    end

    if cardIndex > 1 then
      up = CursorState.onPile(pileIndex, cardIndex - 1)
    elseif pileIndex == 1 then
      up = CursorState.onDeck
    elseif pileIndex < 4 then
      up = CursorState.onWaste
    else
      -- foundation is offset by 3 cards
      local foundationIndex = pileIndex - 3
      up = CursorState.onFoundation(foundationIndex)
    end

    if cardIndex < #currentPile then
      down = CursorState.onPile(pileIndex, cardIndex + 1)
    end

    return { left = left, right = right, up = up, down = down }
  end
end

local gameState = GameState:new()
gameState:deal()

local outerPadding = 7
local width = 44
local gap = 6

local foundationsY = outerPadding
local stacksY = foundationsY + 50 + gap

for i, pile in ipairs(gameState.piles) do
  for j, cardState in ipairs(pile) do
    local x = outerPadding + ((i - 1) * (width + gap))
    local y = stacksY + ((j - 1) * 13)
    cardState.sprite:moveTo(x, y)
    cardState.sprite:add()
  end
end

handSprite:moveTo(gameState.cursor.x, gameState.cursor.y)
local nextCursorPositions = gameState:nextCursorPositions()

local directions = { "up", "down", "left", "right" }

function playdate.update()
  for _, direction in ipairs(directions) do
    if playdate.buttonJustPressed(direction) then
      print("pressed", direction)
      local nextCursorState = nextCursorPositions[direction]
      printTable(nextCursorState)
      if nextCursorState ~= nil then
        handSprite:animateTo(nextCursorState.x, nextCursorState.y)
        gameState.cursor = nextCursorState

        nextCursorPositions = gameState:nextCursorPositions()
      end
    end
  end

  playdate.graphics.sprite.update()
end
