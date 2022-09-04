import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "card"
import "column"

local gfx <const> = playdate.graphics
local geo <const> = playdate.geometry
local easeOutQuint <const> = playdate.easingFunctions.outQuint

--#region Constants

local NUM_FOUNDATIONS <const> = 4
local NUM_COLUMNS <const> = 7
local NUM_WASTE_CARDS <const> = 3
local OUTER_PADDING <const> = 7
local CARD_WIDTH <const> = 44
local CARD_HEIGHT <const> = 50
local CARD_GAP <const> = 6
local CARD_GAP_Y <const> = 13
local CARD_GAP_Y_COMPRESSED <const> = 4
local FOUNDATION_POS_Y <const> = OUTER_PADDING
local COLUMNS_POS_Y <const> = FOUNDATION_POS_Y + CARD_HEIGHT + CARD_GAP

local CURSOR_CARD_OFFSET <const> = geo.vector2D.new(22, 7)
local DECK_CARD_POSITION <const> = geo.point.new(OUTER_PADDING, OUTER_PADDING)


--#endregion

---@alias CursorOnDeck { on: "deck" }
---@alias CursorOnWaste { on: "waste"}
---@alias CursorOnFoundation { on: "foundation", foundationIndex: number }
---@alias CursorOnColumn { on: "column", columnIndex: number, revealedIndex: number }
---@alias CursorOn CursorOnDeck | CursorOnWaste | CursorOnFoundation | CursorOnColumn

---@type CursorOn
local cursorOnDeck = { on = "deck" }

---@type CursorOn
local cursorOnWaste = { on = "waste" }


--#region Game State
---@type Card[]
local deck = Card.getShuffledDeck()

---@type CardListNode | nil
local waste = nil

---@type table<Card, unknown>
local cardSprites = {}

---@type table<1 | 2 | 3 | 4, CardListNode>
local foundations = {}

---@type table<1 | 2 | 3 | 4 | 5 | 6 | 7, Column>
local columns = {
  Column:new(),
  Column:new(),
  Column:new(),
  Column:new(),
  Column:new(),
  Column:new(),
  Column:new(),
}

---@type CursorOn
local cursor = cursorOnDeck

-- ---@type CardListNode | nil
-- local holdingCard

local cursorSprite = gfx.sprite.new(gfx.image.new("images/cursor-point"))
cursorSprite:setCenter(0, 0)
cursorSprite:setZIndex(100)
cursorSprite:add()

--#endregion

--#region Helpers

local deckCardPosition <const> = geo.point.new(OUTER_PADDING, OUTER_PADDING)

---@param wasteIndex number
---@return unknown
local function wasteCardPosition(wasteIndex)
  local x = OUTER_PADDING + CARD_WIDTH + CARD_GAP + ((wasteIndex - 1) * (CARD_WIDTH / 2))
  return geo.point.new(x, FOUNDATION_POS_Y)
end

---@param foundationIndex number
---@return unknown
local function foundationCardPosition(foundationIndex)
  local x = OUTER_PADDING + CARD_WIDTH + ((foundationIndex + 2) * (CARD_WIDTH + CARD_GAP))
  return geo.point.new(x, FOUNDATION_POS_Y)
end

---@param columnIndex number
---@param hiddenCardIndex number
---@param revealedIndex number | nil
---@return unknown
local function columnCardPosition(columnIndex, hiddenCardIndex, revealedIndex)
  local x = OUTER_PADDING + ((columnIndex - 1) * (CARD_WIDTH + CARD_GAP))
  local y = COLUMNS_POS_Y + ((hiddenCardIndex - 1) * CARD_GAP_Y_COMPRESSED)

  if revealedIndex then
    y = y + ((revealedIndex - 1) * CARD_GAP_Y)
  end

  return geo.point.new(x, y)
end

---@return unknown
local function cursorPosition()
  if cursor.on == "deck" then
    return DECK_CARD_POSITION + CURSOR_CARD_OFFSET
  elseif cursor.on == "waste" then
    local cardPosition = wasteCardPosition(waste and waste:length() or 1)
    return cardPosition + CURSOR_CARD_OFFSET
  elseif cursor.on == "foundation" then
    ---@cast cursor CursorOnFoundation
    local cardPosition = foundationCardPosition(cursor.foundationIndex)
    return cardPosition + CURSOR_CARD_OFFSET
  elseif cursor.on == "column" then
    ---@cast cursor CursorOnColumn
    local column = columns[cursor.columnIndex]
    local numHiddenCards = #column.faceDownCards
    local cardPosition = columnCardPosition(cursor.columnIndex, numHiddenCards + 1, cursor.revealedIndex)
    return cardPosition + CURSOR_CARD_OFFSET
  end
  error("unreachable")
end

--#endregion

--#region Game Setup

-- create card sprites, don't add to drawlist
local hiddenCardImage <const> = Card.createHiddenImage()
for _, card in ipairs(deck) do
  local sprite = gfx.sprite.new(hiddenCardImage)
  sprite:setCenter(0, 0)
  cardSprites[card] = sprite
end

-- distribute deck to columns
for columnIndex, column in ipairs(columns) do
  for cardIndex = 1, columnIndex do
    local card = table.remove(deck)

    if cardIndex == columnIndex then
      column.revealedCards = CardListNode:new(card)
    else
      table.insert(column.faceDownCards, card)
    end
  end
end

-- for each card on the board, position, set the image and add to drawlist
for columnIndex, column in ipairs(columns) do
  -- Position each hidden card and add to drawlist
  local hiddenCount = 1
  for index, hiddenCard in ipairs(column.faceDownCards) do
    hiddenCount = hiddenCount + 1
    local sprite = cardSprites[hiddenCard]
    sprite:moveTo(columnCardPosition(columnIndex, index))
    sprite:add()
  end

  -- Position each revealed card, set image, and add to drawlist
  for index, revealedCardNode in column.revealedCards:iter_nodes() do
    local card = revealedCardNode.card
    local sprite = cardSprites[card]
    sprite:setImage(card:createImage())
    sprite:moveTo(columnCardPosition(columnIndex, hiddenCount, index))
    sprite:add()
  end
end

local deckSprite = gfx.sprite.new(hiddenCardImage)
deckSprite:setCenter(0, 0)
deckSprite:moveTo(deckCardPosition)
deckSprite:add()

for i = 1, NUM_FOUNDATIONS do
  local foundationSprite = gfx.sprite.new(hiddenCardImage)
  foundationSprite:setCenter(0, 0)
  foundationSprite:moveTo(foundationCardPosition(i))
  foundationSprite:add()
end

--#endregion

--#region Actions

---@alias direction "up" | "down" | "left" | "right"
---@return table<direction, CursorOn>
local function getNextCursors()
  if cursor.on == "deck" then
    local revealedIndex = columns[1].revealedCards:length()

    return {
      right = { on = "foundation", foundationIndex = 1 },
      down = { on = "column", columnIndex = 1, revealedIndex = revealedIndex }
    }
  elseif cursor.on == "waste" then
    local revealedIndex = columns[2].revealedCards:length()
    return {
      left = cursorOnDeck,
      right = { on = "foundation", foundationIndex = 1 },
      down = { on = "column", columnIndex = 2, revealedIndex = revealedIndex }
    }
  elseif cursor.on == "foundation" then
    ---@cast cursor CursorOnFoundation
    local foundationIndex = cursor.foundationIndex

    ---@type CursorOn
    local left = { on = "foundation", foundationIndex = foundationIndex - 1 }
    ---@type CursorOn
    local right = { on = "foundation", foundationIndex = foundationIndex + 1 }

    -- If there's no foundations to the left
    if foundationIndex == 1 then
      -- If there is a waste present, set it as left
      if waste then
        left = cursorOnWaste
      else
        left = cursorOnDeck
      end
    elseif foundationIndex == NUM_FOUNDATIONS then
      right = nil
    end

    -- Columns are offset by 3 cards
    local columnIndex = foundationIndex + 3
    local column = columns[columnIndex]
    local revealedIndex = column.revealedCards and column.revealedCards:length() or 1

    ---@type CursorOn
    local down = { on = "column", columnIndex = columnIndex, revealedIndex = revealedIndex }

    return { left = left, right = right, down = down }
  elseif cursor.on == "column" then
    ---@cast cursor CursorOnColumn

    local columnIndex = cursor.columnIndex
    local revealedIndex = cursor.revealedIndex
    local currentColumn = columns[columnIndex]
    local currentColumnNumRevealed = currentColumn.revealedCards
        and currentColumn.revealedCards:length()
        or 0

    ---@type CursorOn | nil
    local left = nil
    ---@type CursorOn | nil
    local right = nil
    ---@type CursorOn | nil
    local up = nil
    ---@type CursorOn | nil
    local down = nil

    if columnIndex > 1 then
      local leftColumnIndex = columnIndex - 1
      local leftColumn = columns[leftColumnIndex]
      -- TODO: Handle skipping empty columns
      local leftNumRevealed = leftColumn.revealedCards and leftColumn.revealedCards:length() or 1
      left = { on = "column", columnIndex = leftColumnIndex, revealedIndex = leftNumRevealed }
    end

    if columnIndex < NUM_COLUMNS then
      local rightColumnIndex = columnIndex + 1
      local rightColumn = columns[rightColumnIndex]
      -- TODO: Handle skipping empty columns
      local rightNumRevealed = rightColumn.revealedCards and rightColumn.revealedCards:length() or 1
      right = { on = "column", columnIndex = rightColumnIndex, revealedIndex = rightNumRevealed }
    end

    if revealedIndex > 1 then
      up = { on = "column", columnIndex = columnIndex, revealedIndex = revealedIndex - 1 }
    elseif columnIndex == 1 then
      up = cursorOnDeck
    elseif columnIndex < 4 then
      up = waste and cursorOnWaste or cursorOnDeck
    else
      -- foundation is offset by 3 cards
      up = { on = "foundation", foundationIndex = columnIndex - 3 }
    end

    if revealedIndex < currentColumnNumRevealed then
      down = { on = "column", columnIndex = columnIndex, revealedIndex = revealedIndex + 1 }
    end

    return { left = left, right = right, up = up, down = down }
  end

  error("unreachable")
end

local function cycleDeck()
  -- Hide the current waste pile and put at the back of the deck
  local currentWaste = waste
  while currentWaste do
    local card = currentWaste.card
    local sprite = cardSprites[card]
    sprite:remove()

    table.insert(deck, card)
    currentWaste = currentWaste.tail
  end

  ---@type CardListNode | nil
  waste = nil

  -- Move cards from deck to the waste pile
  for wasteIndex = 1, NUM_WASTE_CARDS do
    ---@type Card | nil
    local card = table.remove(deck, 1)

    -- if there's no more cards in the deck, exit early
    if not card then return end

    -- add to end of waste
    local newWaste = CardListNode:new(card)
    if waste then
      -- go to end and set tail
      local lastNode = waste
      while true do
        if not lastNode.tail then
          lastNode.tail = newWaste
          break
        end
        lastNode = lastNode.tail
      end
    else
      waste = newWaste
    end

    local sprite = cardSprites[card]
    sprite:setImage(card:createImage())
    sprite:moveTo(deckCardPosition)
    sprite:setZIndex(5 + wasteIndex)

    -- Animate the card in
    local position = wasteCardPosition(wasteIndex)
    local animationPath = geo.lineSegment.new(deckCardPosition.x, deckCardPosition.y, position.x, position.y)
    local startDelay = (wasteIndex - 1) * 50
    local animator = gfx.animator.new(150, animationPath, easeOutQuint, startDelay)
    sprite:setAnimator(animator)
    sprite:add()
  end
end

local function positionColumnCards()
  for columnIndex, column in ipairs(columns) do
    -- Position each hidden card
    local hiddenCount = 0
    for index, hiddenCard in ipairs(column.faceDownCards) do
      hiddenCount = hiddenCount + 1
      local sprite = cardSprites[hiddenCard]
      sprite:moveTo(columnCardPosition(columnIndex, index))
    end

    -- Position each revealed card and set image
    for index, revealedCardNode in column.revealedCards:iter_nodes() do
      local card = revealedCardNode.card
      local sprite = cardSprites[card]
      sprite:setImage(card:createImage())
      sprite:moveTo(columnCardPosition(columnIndex, hiddenCount, index))
    end
  end
end

-- local function placeCards()
--   if not holdingCard
--       or cursorDestination.destination == "deck"
--       or cursorDestination.destination == "waste"
--   then return end

--   if cursorDestination.destination == "foundation" then
--     ---@cast cursorDestination CursorDestinationFoundation
--     print("drop on foundation")
--   elseif cursorDestination.destination == "column" then
--     ---@cast cursorDestination CursorDestinationColumn
--     print("drop on column", cursorDestination.columnIndex, cursorDestination.revealedCardIndex)
--   end
-- end

--#endregion

cursorSprite:moveTo(cursorPosition())
local nextCursors = getNextCursors()

print("Starting cursors")
printTable(nextCursors)

function playdate.update()
  for direction, nextCursor in pairs(nextCursors) do
    if playdate.buttonJustPressed(direction) then
      -- animate the cursor to the next position
      cursor = nextCursor
      local position = cursorPosition()

      local line = geo.lineSegment.new(cursorSprite.x, cursorSprite.y, position.x, position.y)
      local anim = gfx.animator.new(150, line, easeOutQuint)
      cursorSprite:setAnimator(anim)

      nextCursors = getNextCursors()
    end
  end

  playdate.graphics.sprite.update()
end
