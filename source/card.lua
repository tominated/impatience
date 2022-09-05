import "CoreLibs/graphics"
local gfx <const> = playdate.graphics

---@alias suit '"diamonds"' | '"clubs"' | '"hearts"' | '"spades"'
---@alias rank 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13
---@alias suitColor '"red"' | '"black"'

---@alias Card { suit: suit, rank: rank }

Card = {}

---@param suit suit
---@param rank rank
---@return Card
function Card.new(suit, rank)
  return { suit = suit, rank = rank }
end

---@return Card[]
function Card.getDeck()
  ---@type Card[]
  local deck = {}

  for _, suit in ipairs({ "diamonds", "clubs", "hearts", "spades" }) do
    for rank = 1, 13 do
      local card = Card.new(suit, rank)
      table.insert(deck, card)
    end
  end

  return deck
end

function Card.getShuffledDeck()
  local deck = Card.getDeck()

  for i = #deck, 2, -1 do
    local j = math.random(i)
    deck[i], deck[j] = deck[j], deck[i]
  end

  return deck
end

local suitImageTable = gfx.imagetable.new("images/suits")
local suitToImage = {
  diamonds = suitImageTable[1],
  clubs = suitImageTable[2],
  hearts = suitImageTable[3],
  spades = suitImageTable[4],
}

local rankImageTable = gfx.imagetable.new("images/ranks")

local CARD_WIDTH = 44
local CARD_HEIGHT = 50
local hiddenImage = nil

---@type table<Card, unknown>
local cardImageCache = {}

function Card.createHiddenImage()
  if hiddenImage ~= nil then
    return hiddenImage
  end

  local img = gfx.image.new(CARD_WIDTH, CARD_HEIGHT)
  gfx.pushContext(img)

  gfx.setColor(gfx.kColorWhite)
  gfx.fillRoundRect(0, 0, CARD_WIDTH, CARD_HEIGHT, 2)
  gfx.setColor(gfx.kColorBlack)
  gfx.drawRoundRect(0, 0, CARD_WIDTH, CARD_HEIGHT, 2)

  gfx.popContext()
  hiddenImage = img
  return img
end

function Card.createImage(card)
  local cached = cardImageCache[card]
  if cached then return cached end

  local img = gfx.image.new(CARD_WIDTH, CARD_HEIGHT)
  gfx.pushContext(img)

  gfx.setColor(gfx.kColorWhite)
  gfx.fillRoundRect(0, 0, CARD_WIDTH, CARD_HEIGHT, 2)
  gfx.setColor(gfx.kColorBlack)
  gfx.drawRoundRect(0, 0, CARD_WIDTH, CARD_HEIGHT, 2)

  local suitImage = suitToImage[card.suit]
  local rankImage = rankImageTable[card.rank]
  suitImage:draw(3, 3)
  rankImage:draw(13, 3)

  gfx.popContext()
  cardImageCache[card] = img
  return img
end

---@return boolean
function Card.is_black(card)
  return card.suit == 'clubs' or card.suit == 'spades'
end

---@return boolean
function Card.is_red(card)
  return card.suit == 'clubs' or card.suit == 'diamonds'
end

---@param a Card
---@param b Card
---@return boolean
function Card.alternates(a, b)
  return Card.is_black(a) ~= Card.is_black(b)
end

---@param a Card
---@param b Card
---@return boolean
function Card.inSequence(a, b)
  return (a.rank + 1) == b.rank
end

---@param a Card
---@param b Card
---@return boolean
function Card.hasSameSuit(a, b)
  return a.suit == b.suit
end

---@param foundationCard Card | nil
---@param card Card
---@return boolean
function Card.canBuildUp(foundationCard, card)
  if not foundationCard then
    return card.rank == 1
  end

  return Card.hasSameSuit(foundationCard, card)
      and Card.inSequence(foundationCard, card)
end

---@param columnCard Card | nil
---@param card Card
---@return boolean
function Card.canBuildDown(columnCard, card)
  if not columnCard then
    return card.rank == 13
  end

  return Card.alternates(columnCard, card)
      and Card.inSequence(card, columnCard)
end
