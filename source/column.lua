import "list"

---@alias Column { hiddenCards: Card[], revealedCards: List<Card> }

Column = {}

---@return Column
function Column.new()
  return { hiddenCards = {}, revealedCards = nil }
end

---@param column Column
function Column.promoteHidden(column)
  if column.revealedCards then return end

  ---@type Card | nil
  local card = table.remove(column.hiddenCards)
  if not card then return end

  column.revealedCards = List.node(card)
end

---@param column Column
---@return fun(): number, Card | nil
function Column.iterHidden(column)
  return ipairs(column.hiddenCards)
end

---@param column Column
---@return fun(): number, Card | nil
function Column.iterRevealed(column)
  return List.iter(column.revealedCards)
end

---@param column Column
---@return fun(): number, Card | nil
function Column.iterRevealedRev(column)
  return List.iterRev(column.revealedCards)
end
