local namespace = vim.api.nvim_create_namespace 'fixity'

local Position = {}

setmetatable(Position, {
  __index = function(t, k)
    local index = { row = 1, col = 2 }
    return t[index[k]]
  end,
  __call = function(t, ...)
    local pos = { ... }
    setmetatable(pos, getmetatable(t))
    return pos
  end,
  __lt = function(l, r)
    if l.row < r.row then
      return true
    end

    if l.row > r.row then
      return false
    end

    return l.col < r.col
  end,
  __le = function(l, r)
    if l.row < r.row then
      return true
    end

    if l.row > r.row then
      return false
    end

    return l.col <= r.col
  end,
})

local Mark = {}
Mark.__index = Mark

function Mark.new(buf, id, start, end_, hl_group, view)
  local opts = {
    id = id,
    end_col = end_.col,
    end_line = end_.row,
    hl_group = hl_group,
  }

  vim.api.nvim_buf_set_extmark(buf, namespace, start.row, start.col, opts)

  local mark = {
    buf = buf,
    id = id,
    start = Position(start.row, start.col),
    end_ = Position(end_.row, end_.col),
    hl_group = hl_group,
    view = view or { lnum = start.row + 1, col = start.col, topline = 1 },
  }
  setmetatable(mark, Mark)
  return mark
end

function Mark:contents()
  local lines = vim.api.nvim_buf_get_lines(
    self.buf,
    self.start.row,
    self.end_.row + 1,
    true
  )

  lines[#lines] = lines[#lines]:sub(1, self.end_.col)
  lines[1] = lines[1]:sub(self.start.col + 1)

  if #lines == 1 then
    return lines[1]
  end

  return lines
end

function Mark:jump()
  local height = self.end_.row - self.start.row

  local win = vim.fn.bufwinid(self.buf)

  if height  > 0 then
    vim.api.nvim_win_set_height(win, height + 1)
  end

  vim.api.nvim_win_call(win, function()
    vim.fn.winrestview(self.view)
  end)
end

local Marks = {}

function Marks:clear_namespace()
  vim.api.nvim_buf_clear_namespace(self.buf, namespace, 0, -1)
  self.marks = {}
end

function Marks:add_mark(...)
  local id = #self.marks + 1
  self.marks[id] = Mark.new(self.buf, id, ...)
end

function Marks:set_marks()
  local offset = #self.buffer_header
  local lines = vim.api.nvim_buf_get_lines(self.buf, offset, -1, false)

  for row, line in ipairs(lines) do
    row = row + offset - 1
    self:add_mark(Position(row, 0), Position(row, #line))
  end
end

function Marks:get_cursor()
  local row, col = unpack(
    vim.api.nvim_win_get_cursor(vim.fn.bufwinid(self.buf))
  )
  return Position(row - 1, col)
end

function Marks:get_cursor_mark()
  local cursor = self:get_cursor()

  local result = vim.api.nvim_buf_get_extmarks(
    self.buf,
    namespace,
    cursor,
    0,
    { limit = 1, details = true }
  )[1]

  if not result then
    return nil
  end

  local mark = self.marks[result[1]]

  if mark.start <= cursor and cursor < mark.end_ then
    return mark
  end

  return nil
end

function Marks:find_mark_from_cursor(end_search)
  local mark = vim.api.nvim_buf_get_extmarks(
    self.buf,
    namespace,
    self:get_cursor(),
    end_search,
    { limit = 1, details = true }
  )[1]
  if not mark then
    return nil
  end
  return self.marks[mark[1]]
end

function Marks:next()
  local mark = self:get_cursor_mark()

  if not mark then
    return self:find_mark_from_cursor(-1) or self.marks[1]
  end

  return self.marks[mark.id + 1] or self.marks[1]
end

function Marks:previous()
  local mark = self:get_cursor_mark()

  if not mark then
    return self:find_mark_from_cursor(0) or self.marks[#self.marks]
  end

  return self.marks[mark.id - 1] or self.marks[#self.marks]
end

function Marks:jump_to_next()
  local mark = self:next()
  if mark then
    mark:jump()
  end
end

function Marks:jump_to_previous()
  local mark = self:previous()
  if mark then
    mark:jump()
  end
end

function Marks:cursor_mark_contents()
  local mark = self:get_cursor_mark()
  if not mark then
    return nil
  end
  return mark:contents()
end

return Marks
