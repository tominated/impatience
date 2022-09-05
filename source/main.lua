import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "card"
import "list"
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
local HOLDING_CARD_OFFSET <const> = geo.vector2D.new(-12, -4)
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

---@type Card[]
local discard = {}

---@type List<Card> | nil
local waste = nil

---@type table<Card, unknown>
local cardSprites = {}

---@type table<1 | 2 | 3 | 4, List<Card>>
local foundations = {}

---@type table<1 | 2 | 3 | 4 | 5 | 6 | 7, Column>
local columns = {
  Column.new(),
  Column.new(),
  Column.new(),
  Column.new(),
  Column.new(),
  Column.new(),
  Column.new(),
}

---@type CursorOn
local cursor = cursorOnDeck

---@type List<Card>
local holdingCard

---@alias ReturnToWaste { to: "waste" }
---@alias ReturnToFoundation { to: "foundation", foundationIndex: number }
---@alias ReturnToColumn { to: "column", columnIndex: number }
---@alias ReturnTo ReturnToWaste | ReturnToFoundation | ReturnToColumn

---@type ReturnTo | nil
local returnTo

local cursorPointImage = gfx.image.new("images/cursor-point")
local cursorGrabImage = gfx.image.new("images/cursor-grab")
local cursorSprite = gfx.sprite.new(cursorPointImage)
local cursorAnimator = nil
cursorSprite:setCenter(0, 0)
cursorSprite:setZIndex(1000)
cursorSprite:add()

local deckImage = gfx.image.new("images/deck")
local deckEmptyImage = gfx.image.new("images/deck-empty")

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
  local x = OUTER_PADDING + ((foundationIndex + 2) * (CARD_WIDTH + CARD_GAP))
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
    local cardPosition = wasteCardPosition(List.length(waste))
    return cardPosition + CURSOR_CARD_OFFSET
  elseif cursor.on == "foundation" then
    ---@cast cursor CursorOnFoundation
    local cardPosition = foundationCardPosition(cursor.foundationIndex)
    return cardPosition + CURSOR_CARD_OFFSET
  elseif cursor.on == "column" then
    ---@cast cursor CursorOnColumn
    local column = columns[cursor.columnIndex]
    local numHiddenCards = #column.hiddenCards
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
    table.insert(column.hiddenCards, card)
  end
  Column.promoteHidden(column)
end

-- for each card on the board, position, set the image and add to drawlist
for columnIndex, column in ipairs(columns) do
  -- Position each hidden card and add to drawlist
  local hiddenCount = 1
  for index, hiddenCard in Column.iterHidden(column) do
    hiddenCount = hiddenCount + 1
    local sprite = cardSprites[hiddenCard]
    sprite:moveTo(columnCardPosition(columnIndex, index))
    sprite:add()
  end

  -- Position each revealed card, set image, and add to drawlist
  for index, card in Column.iterRevealed(column) do
    local sprite = cardSprites[card]
    sprite:setImage(Card.createImage(card))
    sprite:moveTo(columnCardPosition(columnIndex, hiddenCount, index))
    sprite:add()
  end
end

local deckSprite = gfx.sprite.new(deckImage)
deckSprite:setCenter(0, 0)
deckSprite:setZIndex(50)
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
    local revealedCards = columns[1].revealedCards
    local revealedIndex = List.length(revealedCards)
    local right = waste
        and { on = "waste" }
        or { on = "foundation", foundationIndex = 1 }
    return {
      right = right,
      down = { on = "column", columnIndex = 1, revealedIndex = revealedIndex }
    }
  elseif cursor.on == "waste" then
    local revealedCards = columns[2].revealedCards
    local revealedIndex = List.length(revealedCards)
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
    local revealedIndex = List.length(column.revealedCards) or 1

    ---@type CursorOn
    local down = { on = "column", columnIndex = columnIndex, revealedIndex = revealedIndex }

    return { left = left, right = right, down = down }
  elseif cursor.on == "column" then
    ---@cast cursor CursorOnColumn

    local columnIndex = cursor.columnIndex
    local revealedIndex = cursor.revealedIndex
    local currentColumn = columns[columnIndex]
    local currentColumnNumRevealed = List.length(currentColumn.revealedCards)

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
      local leftNumRevealed = List.length(leftColumn.revealedCards) or 1
      left = { on = "column", columnIndex = leftColumnIndex, revealedIndex = leftNumRevealed }
    end

    if columnIndex < NUM_COLUMNS then
      local rightColumnIndex = columnIndex + 1
      local rightColumn = columns[rightColumnIndex]
      -- TODO: Handle skipping empty columns
      local rightNumRevealed = List.length(rightColumn.revealedCards) or 1
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
  for _, card in List.iter(waste) do
    local sprite = cardSprites[card]
    sprite:remove()
    table.insert(discard, card)
  end

  waste = nil

  -- If the deck is empty, swap it and the discard pile and exit
  if #deck == 0 then
    deck = discard
    discard = {}

    deckSprite:setImage(deckImage)

    return
  end

  -- Move cards from deck to the waste pile
  for wasteIndex = 1, NUM_WASTE_CARDS do
    ---@type Card | nil
    local card = table.remove(deck, 1)

    -- if there's no more cards in the deck, exit early
    if not card then
      break
    end

    -- add to end of waste
    waste = List.append(waste, card)

    local sprite = cardSprites[card]
    sprite:setImage(Card.createImage(card))
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

  if #deck == 0 then
    deckSprite:setImage(deckEmptyImage)
  end
end

---@param columnIndex number
local function settleCardsInColumn(columnIndex)
  local column = columns[columnIndex]

  -- Ensure any cards are revealed if applicable
  Column.promoteHidden(column)

  -- Position each hidden card
  local hiddenCount = 1
  for index, hiddenCard in Column.iterHidden(column) do
    hiddenCount = hiddenCount + 1
    local sprite = cardSprites[hiddenCard]
    sprite:setZIndex(hiddenCount)

    local desiredPos = columnCardPosition(columnIndex, index)
    if sprite.x ~= desiredPos.x or sprite.y ~= desiredPos.y then
      sprite:moveTo(desiredPos)
    end
  end

  -- Position each revealed card and set image
  for index, card in Column.iterRevealed(column) do
    local sprite = cardSprites[card]
    sprite:setImage(Card.createImage(card))
    sprite:setZIndex(hiddenCount + index)

    local desiredPos = columnCardPosition(columnIndex, hiddenCount, index)
    if sprite.x ~= desiredPos.x or sprite.y ~= desiredPos.y then
      local currentPosition = geo.point.new(sprite:getPosition())
      local anim = gfx.animator.new(150, currentPosition, desiredPos, easeOutQuint)
      sprite:setAnimator(anim)
    end
  end
end

local function settleCardsInAllColumns()
  for columnIndex, _ in ipairs(columns) do
    settleCardsInColumn(columnIndex)
  end
end

local function settleCardsInFoundation(foundationIndex)
  local foundation = foundations[foundationIndex]

  for i, card in List.iterRev(foundation) do
    local cardSprite = cardSprites[card]

    local desiredPos = foundationCardPosition(foundationIndex)

    -- Last card should have higher z-index
    if i == 1 then
      if cardSprite.x ~= desiredPos.x or cardSprite.y ~= desiredPos.y then
        local currentPosition = geo.point.new(cardSprite:getPosition())
        local anim = gfx.animator.new(150, currentPosition, desiredPos, easeOutQuint)
        cardSprite:setAnimator(anim)
      end

      cardSprite:setZIndex(2)
      cardSprite:add()
      return
    end

    -- Second last on stack should be visible if the top
    -- has been picked up
    if i == 2 then
      cardSprite:setZIndex(1)
      cardSprite:moveTo(desiredPos)
      cardSprite:add()
      return
    end

    -- Ensure the card is in the right place and hidden
    cardSprite:moveTo(desiredPos)
    cardSprite:remove()
  end
end

local function dropHeldCard()
  if not holdingCard then return end
  if not returnTo then return end

  local cardSprite = cardSprites[holdingCard.value]

  if returnTo.to == "waste" and waste then
    local returnPosition = wasteCardPosition(List.length(waste))
    local line = geo.lineSegment.new(cardSprite.x, cardSprite.y, returnPosition.x, returnPosition.y)
    local anim = gfx.animator.new(150, line, easeOutQuint)
    cardSprite:setAnimator(anim)
  elseif returnTo.to == "foundation" then
    ---@cast returnTo ReturnToFoundation
    settleCardsInFoundation(returnTo.foundationIndex)
  elseif returnTo.to == "column" then
    ---@cast returnTo ReturnToColumn
    settleCardsInColumn(returnTo.columnIndex)
  end

  cursorSprite:setImage(cursorPointImage)
  holdingCard = nil
  returnTo = nil
end

local cursorShakeOffset = geo.vector2D.new(2, 0)
local function shakeCursor()
  local currentPosition = cursorPosition()
  local leftOfCursor = currentPosition - cursorShakeOffset
  local rightOfCursor = currentPosition + cursorShakeOffset
  local leftToRight = leftOfCursor .. rightOfCursor
  local rightToLeft = rightOfCursor .. leftOfCursor
  local anim = gfx.animator.new(150, { leftToRight, rightToLeft, leftToRight }, {})
  cursorAnimator = anim
  cursorSprite:setAnimator(anim)
end

local function placeHeldCard()
  if not holdingCard then return end
  if not returnTo then return end

  if (
      cursor.on == "waste" and returnTo.to == "waste"
      ) or (
      cursor.on == "foundation"
          and returnTo.to == "foundation"
      ) or (
      cursor.on == "column"
          and returnTo.to == "column"
          and cursor.columnIndex == returnTo.columnIndex
      ) then
    dropHeldCard()
    return
  end

  if cursor.on == "foundation" then
    ---@cast cursor CursorOnFoundation
    if List.tail(holdingCard) then return end

    local foundation = foundations[cursor.foundationIndex]

    ---@type Card | nil
    local foundationCard = List.last(foundation)

    if not Card.canBuildUp(foundationCard, holdingCard.value) then
      return
    end

    foundations[cursor.foundationIndex] = List.concat(foundation, holdingCard)

    if returnTo.to == "column" then
      ---@cast returnTo ReturnToColumn
      local column = columns[returnTo.columnIndex]
      column.revealedCards = List.remove_sublist(column.revealedCards, holdingCard)
      settleCardsInColumn(returnTo.columnIndex)
    elseif returnTo.to == "waste" then
      ---@cast returnTo ReturnToWaste
      waste = List.remove_sublist(waste, holdingCard)
    end

    cursorSprite:setImage(cursorPointImage)
    holdingCard = nil
    returnTo = nil
    settleCardsInFoundation(cursor.foundationIndex)
  elseif cursor.on == "column" then
    ---@cast cursor CursorOnColumn

    print("placing on column?")

    local destColumn = columns[cursor.columnIndex]
    ---@type Card | nil
    local destColumnCard = List.last(destColumn.revealedCards)
    print("column card")
    printTable(destColumnCard)
    if not Card.canBuildDown(destColumnCard, holdingCard.value) then return end

    destColumn.revealedCards = List.concat(destColumn.revealedCards, holdingCard)

    if returnTo.to == "column" then
      ---@cast returnTo ReturnToColumn
      local srcColumn = columns[returnTo.columnIndex]
      srcColumn.revealedCards = List.remove_sublist(srcColumn.revealedCards, holdingCard)
      settleCardsInColumn(returnTo.columnIndex)
    elseif returnTo.to == "waste" then
      ---@cast returnTo ReturnToWaste
      waste = List.remove_sublist(waste, holdingCard)
    end

    cursorSprite:setImage(cursorPointImage)
    holdingCard = nil
    returnTo = nil
    settleCardsInColumn(cursor.columnIndex)
  end
end

local function grabWasteCard()
  local wasteCard = List.lastNode(waste)
  if not wasteCard then return end

  cursorSprite:setImage(cursorGrabImage)
  cursorSprite:removeAnimator()

  holdingCard = wasteCard
  returnTo = { to = "waste" }
  ---@cast holdingCard Card

  local currentCursorPosition = cursorPosition()
  local cardSprite = cardSprites[wasteCard.value]
  local hoverPosition = currentCursorPosition + HOLDING_CARD_OFFSET
  cardSprite:setZIndex(100)
  cardSprite:moveTo(hoverPosition)
end

local function grabFoundationCard(foundationIndex)
  local foundation = foundations[foundationIndex]
  local nodeToHold = foundation and List.lastNode(foundation)
  if not nodeToHold then return end

  cursorSprite:setImage(cursorGrabImage)
  cursorSprite:removeAnimator()

  holdingCard = nodeToHold
  returnTo = { to = "foundation", foundationIndex = foundationIndex }

  local currentCursorPosition = cursorPosition()
  local cardSprite = cardSprites[nodeToHold.value]
  local hoverPosition = currentCursorPosition + HOLDING_CARD_OFFSET
  cardSprite:setZIndex(100)
  cardSprite:moveTo(hoverPosition)
end

local function grabColumnCard(columnIndex, revealedIndex)
  local column = columns[columnIndex]
  local revealedCard = List.nthNode(column.revealedCards, revealedIndex)
  if not revealedCard then return end

  cursorSprite:setImage(cursorGrabImage)
  cursorSprite:removeAnimator()

  holdingCard = revealedCard
  returnTo = { to = "column", columnIndex = columnIndex }

  local currentCursorPosition = cursorPosition()
  for i, card in List.iter(holdingCard) do
    local cardSprite = cardSprites[card]
    local hoverPosition = currentCursorPosition + HOLDING_CARD_OFFSET
    hoverPosition.y = hoverPosition.y + (i - 1) * CARD_GAP_Y
    cardSprite:setZIndex(i + 100)
    cardSprite:moveTo(hoverPosition)
  end
end

local cursorAnimOffset = geo.vector2D.new(0, 3)
local function setCursorIdleAnimation()
  local currentPosition = cursorPosition()
  local anim = gfx.animator.new(500, currentPosition, currentPosition + cursorAnimOffset)
  anim.repeatCount = -1
  anim.reverses = true
  cursorAnimator = anim
  cursorSprite:setAnimator(anim)
end

local function idleAnimation()
  if cursorAnimator and cursorAnimator:ended() and not holdingCard then
    setCursorIdleAnimation()
  end
end

--#endregion

cursorSprite:moveTo(cursorPosition())
setCursorIdleAnimation()
local nextCursors = getNextCursors()

local function handleInputs()
  for direction, nextCursor in pairs(nextCursors) do
    if playdate.buttonJustPressed(direction) then
      -- animate the cursor to the next position
      cursor = nextCursor
      local position = cursorPosition()

      local line = geo.lineSegment.new(cursorSprite.x, cursorSprite.y, position.x, position.y)
      local anim = gfx.animator.new(150, line, easeOutQuint)
      cursorAnimator = anim
      cursorSprite:setAnimator(anim)

      for i, card in List.iter(holdingCard) do
        local cardSprite = cardSprites[card]
        local hoverPosition = position + HOLDING_CARD_OFFSET
        hoverPosition.y = hoverPosition.y + (i - 1) * CARD_GAP_Y
        local line = geo.lineSegment.new(cardSprite.x, cardSprite.y, hoverPosition.x, hoverPosition.y)
        local anim = gfx.animator.new(150, line, easeOutQuint, (i - 1) * 50)
        cardSprite:setAnimator(anim)
      end

      nextCursors = getNextCursors()
      return
    end
  end

  if holdingCard then
    if playdate.buttonJustPressed("b") then
      dropHeldCard()
      return
    elseif playdate.buttonJustPressed("a") then
      placeHeldCard()
      return
    end
  elseif playdate.buttonJustPressed("a") then
    if cursor.on == "deck" then
      cycleDeck()
      nextCursors = getNextCursors()
      return
    elseif cursor.on == "waste" then
      grabWasteCard()
      return
    elseif cursor.on == "foundation" then
      ---@cast cursor CursorOnFoundation
      grabFoundationCard(cursor.foundationIndex)
      return
    elseif cursor.on == "column" then
      ---@cast cursor CursorOnColumn
      grabColumnCard(cursor.columnIndex, cursor.revealedIndex)
      return
    end
  end
end

function playdate.update()
  handleInputs()

  idleAnimation()

  playdate.graphics.sprite.update()
end
