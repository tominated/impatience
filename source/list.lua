---@alias ListNode<T> { value: T, next: List<T> }
---@alias List<T> ListNode<T> | nil

List = {}

---@generic T
---@param value T
---@param next List<T>
function List.node(value, next)
  return { value = value, next = next }
end

---@generic T
---@param list List<T>
---@return T | nil
function List.head(list)
  return list and list.value
end

---@generic T
---@param list List<T>
---@return List<T>
function List.tail(list)
  return list and list.next
end

---@generic T
---@param list List<T>
---@return number
function List.length(list)
  if list then
    return List.length(list.next) + 1
  end
  return 0
end

---@generic T
---@param list List<T>
---@param n number
---@return List<T>
function List.nthNode(list, n)
  if not list then return nil end
  if n == 1 then return list end
  return List.nth(list.next, n - 1)
end

---@generic T
---@param list List<T>
---@param n number
---@return T | nil
function List.nth(list, n)
  if not list then return nil end
  if n == 1 then return list.value end
  return List.nth(list.next, n - 1)
end

---@generic T
---@param list List<T>
---@return List<T>
function List.lastNode(list)
  if list and list.next then
    return List.lastNode(list.next)
  end
  return list
end

---@generic T
---@param list List<T>
---@return T | nil
function List.last(list)
  local node = List.lastNode(list)
  return node and node.value
end

---@generic T
---@param a List<T>
---@param b List<T>
---@return List<T>
function List.concat(a, b)
  local node = a
  while node do
    -- if this is the last one, set the next node to b
    if not node.next then
      node.next = b
      return a
    end
    node = node.next
  end
  return b
end

---@generic T
---@param list List<T>
---@param value T
---@return List<T>
function List.append(list, value)
  local node = List.node(value)
  return List.concat(list, node)
end

---@generic T
---@param list List<T>
---@param sublist List<T>
---@return List<T> | nil
function List.remove_sublist(list, sublist)
  local pred = nil
  local currentNode = list
  while currentNode do
    if currentNode == sublist then
      if pred then
        pred.next = nil
        return list
      end
      return nil
    end

    pred = currentNode
    currentNode = currentNode.next
  end
  return list
end

---@generic T
---@param inList List<T>
---@param toFind List<T>
---@return List<T>
function List.findPred(inList, toFind)
  local pred = nil
  local current = inList
  while current do
    if current == toFind then
      return pred
    end

    pred = current
    current = current.next
  end
end

---@generic T
---@param list List<T>
---@return List<T>
function List.rev(list)
  local reversed = nil

  for _, value in List.iter(list) do
    reversed = List.node(value, reversed)
  end

  return reversed
end

---@generic T
---@param list List<T>
---@return fun(): number, T | nil
function List.iter(list)
  local next = list
  local nextIndex = 1

  return function()
    if next then
      local current = next
      next = current.next

      local index = nextIndex
      nextIndex = index + 1

      return index, current.value
    end
  end
end

---@generic T
---@param list List<T>
---@return fun(): number, T | nil
function List.iterRev(list)
  return List.iter(List.rev(list))
end
