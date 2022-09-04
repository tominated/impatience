import "CoreLibs/graphics"
local gfx <const> = playdate.graphics

---@alias suit '"diamonds"' | '"clubs"' | '"hearts"' | '"spades"'
---@alias rank 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13
---@alias suitColor '"red"' | '"black"'

---@class Card
---@field suit suit
---@field rank rank
Card = {}

---@param suit suit
---@param rank rank
---@return Card
function Card:new(suit, rank)
  local card = { suit = suit, rank = rank }
  self.__index = self
  return setmetatable(card, self)
end

---@return Card[]
function Card.getDeck()
  ---@type Card[]
  local deck = {}

  for _, suit in ipairs({ "diamonds", "clubs", "hearts", "spades" }) do
    for rank = 1, 13 do
      local card = Card:new(suit, rank)
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

function Card:createImage()
  local cached = cardImageCache[self]
  if cached then return cached end

  local img = gfx.image.new(CARD_WIDTH, CARD_HEIGHT)
  gfx.pushContext(img)

  gfx.setColor(gfx.kColorWhite)
  gfx.fillRoundRect(0, 0, CARD_WIDTH, CARD_HEIGHT, 2)
  gfx.setColor(gfx.kColorBlack)
  gfx.drawRoundRect(0, 0, CARD_WIDTH, CARD_HEIGHT, 2)

  local suitImage = suitToImage[self.suit]
  local rankImage = rankImageTable[self.rank]
  suitImage:draw(3, 3)
  rankImage:draw(13, 3)

  gfx.popContext()
  cardImageCache[self] = img
  return img
end

---@return boolean
function Card:is_black()
  return self.suit == 'clubs' or self.suit == 'spades'
end

---@return boolean
function Card:is_red()
  return self.suit == 'clubs' or self.suit == 'diamonds'
end

---@param card Card
---@return boolean
function Card:alternates(card)
  return self:is_black() ~= card:is_black()
end

---@param card Card
---@return boolean
function Card:succeeds(card)
  return self.rank == (card.rank + 1)
end

---@param card Card
---@return boolean
function Card:hasSameSuitAs(card)
  return self.suit == card.suit
end

---@param card Card
---@return boolean
function Card:canPlayOnFoundation(card)
  return self:hasSameSuitAs(card) and self:succeeds(card)
end

---@param card Card
---@return boolean
function Card:canPlayOnPile(card)
  return self:alternates(card) and card:succeeds(self)
end
