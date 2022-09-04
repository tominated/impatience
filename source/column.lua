---@class CardListNode
---@field card Card
---@field tail CardListNode | nil
CardListNode = {}

---@param card Card
---@param tail CardListNode | nil
---@return CardListNode
function CardListNode:new(card, tail)
  local node = { card = card, tail = tail }
  self.__index = self
  return setmetatable(node, self)
end

---@return integer
function CardListNode:length()
  if not self.tail then
    return 1
  end

  return self.tail:length() + 1
end

---Creates an iterator over each of the nodes
---@return fun(): number, CardListNode | nil
function CardListNode:iter_nodes()
  local next = self
  local i = 1
  return function()
    local current = next
    local currentI = i
    if current ~= nil then
      next = current.tail
      i = i + 1
      return currentI, current
    end
  end
end

---@class Column
---@field faceDownCards Card[]
---@field revealedCards CardListNode | nil
Column = {}

---@return Column
function Column:new()
  local column = { faceDownCards = {}, revealedCards = nil }
  self.__index = self
  return setmetatable(column, self)
end

---@param n number # The index of the card starting at 1
---@return CardListNode | nil
function Column:nthRevealedCardNode(n)
  if self.revealedCards == nil then return nil end
  for i, node in self.revealedCards:iter_nodes() do
    if i == n then return node end
  end
end

---@param cardNode CardListNode The card to move from the current column
---@param destination Column The destination column to add on the end
function Column:moveToColumn(cardNode, destination)
  -- Search thru revealedCards to find cardNode
  local prevNode = nil
  local currentNode = self.revealedCards
  while true do
    if not currentNode then return end
    if currentNode == cardNode then break end
    prevNode = currentNode
    currentNode = currentNode.tail
  end

  -- current node can never be nil by now
  ---@cast currentNode CardListNode

  -- find the last node of the destination
  local lastNode
  for node in destination.revealedCards:iter_nodes() do
    lastNode = node
  end

  -- add the card(s) to the end of the destination
  if lastNode then
    lastNode.tail = currentNode
  else
    destination.revealedCards = currentNode
  end

  if prevNode then
    -- remove the cards from the current column
    prevNode.tail = nil
  else
    -- no more revealed cards, so reveal one if possible
    ---@type Card | nil
    local hiddenCard = table.remove(self.faceDownCards)
    if hiddenCard then
      self.revealedCards = CardListNode:new(hiddenCard)
    end
  end
end
