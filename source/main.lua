import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "card"

local gfx <const> = playdate.graphics
local geo <const> = playdate.geometry
local cursorEase <const> = playdate.easingFunctions.outQuint

local OUTER_PADDING = 7
local CARD_WIDTH = 44
local CARD_HEIGHT = 50
local CARD_GAP = 6
local CARD_GAP_Y = 13

local FOUNDATION_POS_Y = OUTER_PADDING
local COLUMNS_POS_Y = FOUNDATION_POS_Y + CARD_HEIGHT + CARD_GAP

local handSprite = gfx.sprite.new(gfx.image.new("images/cursor-point"))
handSprite:setCenter(0, 0)
handSprite:setZIndex(100)
handSprite:add()

function handSprite:animateBy(x, y)
  local line = geo.lineSegment.new(self.x, self.y, self.x + x, self.y + y)
  local anim = gfx.animator.new(150, line, cursorEase)
  handSprite:setAnimator(anim)
end

function handSprite:animateTo(point)
  local line = geo.lineSegment.new(self.x, self.y, point.x, point.y)
  local anim = gfx.animator.new(150, line, cursorEase)
  handSprite:setAnimator(anim)
end

local hiddenCardImage <const> = Card.createHiddenImage()

CardState = {}
function CardState:new(card)
  local sprite = gfx.sprite.new(hiddenCardImage)
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

local cursorOffset <const> = geo.vector2D.new(22, 7)

local deckCardPosition <const> = geo.point.new(OUTER_PADDING, OUTER_PADDING)

local function wasteCardPosition(wasteIndex)
  local x = OUTER_PADDING + CARD_WIDTH + CARD_GAP + ((wasteIndex - 1) * (CARD_WIDTH / 2))
  return geo.point.new(x, FOUNDATION_POS_Y)
end

local function foundationCardPosition(foundationIndex)
  local x = OUTER_PADDING + CARD_WIDTH + ((foundationIndex + 2) * (CARD_WIDTH + CARD_GAP))
  return geo.point.new(x, FOUNDATION_POS_Y)
end

local function columnCardPosition(column, cardIndex)
  local x = OUTER_PADDING + ((column - 1) * (CARD_WIDTH + CARD_GAP))
  local y = COLUMNS_POS_Y + ((cardIndex - 1) * CARD_GAP_Y)
  return geo.point.new(x, y)
end

CursorState = {
  onDeck = { position = "deck", point = deckCardPosition + cursorOffset },
  onWaste = { position = "waste", point = wasteCardPosition(1) + cursorOffset },
}

function CursorState.onFoundation(foundationIndex)
  return { position = "foundation", foundationIndex = foundationIndex,
    point = foundationCardPosition(foundationIndex) + cursorOffset }
end

function CursorState.onColumn(pileIndex, cardIndex)
  return { position = "pile", pileIndex = pileIndex, cardIndex = cardIndex,
    point = columnCardPosition(pileIndex, cardIndex) + cursorOffset }
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
      down = CursorState.onColumn(1, cardIndex)
    }
  elseif self.cursor.position == "waste" then
    local cardIndex = #piles[2]
    return {
      left = CursorState.onDeck,
      right = CursorState.onFoundation(1),
      down = CursorState.onColumn(2, cardIndex)
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
      down = CursorState.onColumn(pileIndex, #pile)
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
      left = CursorState.onColumn(leftPileIndex, #piles[leftPileIndex])
    end

    if pileIndex < 7 then
      local rightPileIndex = pileIndex + 1
      right = CursorState.onColumn(rightPileIndex, #piles[rightPileIndex])
    end

    if cardIndex > 1 then
      up = CursorState.onColumn(pileIndex, cardIndex - 1)
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
      down = CursorState.onColumn(pileIndex, cardIndex + 1)
    end

    return { left = left, right = right, up = up, down = down }
  end
end

local gameState = GameState:new()
gameState:deal()

local deckSprite = gfx.sprite.new(hiddenCardImage)
deckSprite:setCenter(0, 0)
deckSprite:moveTo(deckCardPosition)
deckSprite:add()

for i, _ in ipairs(gameState.foundations) do
  local foundationSprite = gfx.sprite.new(hiddenCardImage)
  foundationSprite:setCenter(0, 0)
  foundationSprite:moveTo(foundationCardPosition(i))
  foundationSprite:add()
end

for i, pile in ipairs(gameState.piles) do
  for j, cardState in ipairs(pile) do
    local position = columnCardPosition(i, j)
    cardState.sprite:moveTo(position.x, position.y)
    cardState.sprite:add()
  end
end

handSprite:moveTo(gameState.cursor.point)
local nextCursorPositions = gameState:nextCursorPositions()

local directions = { "up", "down", "left", "right" }

function playdate.update()
  for _, direction in ipairs(directions) do
    if playdate.buttonJustPressed(direction) then
      print("pressed", direction)
      local nextCursorState = nextCursorPositions[direction]
      printTable(nextCursorState)
      if nextCursorState ~= nil then
        handSprite:animateTo(nextCursorState.point)
        gameState.cursor = nextCursorState

        nextCursorPositions = gameState:nextCursorPositions()
      end
    end
  end

  playdate.graphics.sprite.update()
end
