local Diff = require('fixity.display'):new {
  __module = 'diff',
  keymaps = {
    -- TODO: this command should only exist for unstaged
    ['-'] = { method = 'stage_hunk' },
  },
  syntax = [[
    syn clear

    syn match fixityAdd "^+.*$"
    syn match fixityDelete "^-.*$"

    syn match fixityHunkHeader "@@.*@@"
  ]],
}

function Diff:set_marks()
  local hunk_header = vim.regex [[^@@.\+@@]]

  local offset = #self.buffer_header
  local lines = vim.api.nvim_buf_get_lines(self.buf, offset, -1, false)

  self.header = {}

  for row, line in ipairs(lines) do
    if hunk_header:match_str(line) then
      self.header = vim.list_slice(lines, 0, row - 1)
      break
    end
  end

  if vim.tbl_isempty(self.header) then
    return
  end

  offset = #self.header + #self.buffer_header
  lines = vim.api.nvim_buf_get_lines(self.buf, offset + 1, -1, false)

  local start = offset

  for row, line in ipairs(lines) do
    if hunk_header:match_str(line) then
      self:set_mark(
        { row = start, col = 0 },
        { row = row + offset - 1, col = #lines[row - 1] }
      )
      start = row + offset
    end
  end

  self:set_mark(
    { row = start, col = 0 },
    { row = #lines + offset, col = #lines[#lines] }
  )
end

function Diff:set_view(mark)
  if mark == nil then
    mark = self.marks[1]

    if mark == nil then
      return
    end
  end

  local win = vim.fn.bufwinid(self.buf)
  vim.api.nvim_win_set_height(win, #mark:contents())

  -- + 5 offset: 1 for the hunk header, 3 for the context lines, 1 because it
  -- is 0-based.
  -- TODO: Actually use the context lines. Right now, on a diff at the top of
  -- the file, this will not put the cursor at the correct place.
  vim.fn.winrestview { lnum = mark.start.row + 5, topline = mark.start.row + 1 }
end

function Diff:should_close()
  return vim.tbl_isempty(self.marks, {})
end

function Diff:patch(mark)
  return table.concat(
    vim.tbl_flatten {
      self.header,
      mark:contents(),
      '',
    },
    '\n'
  )
end

function Diff:stage_hunk()
  local mark = self:get_cursor_mark()

  if not mark then
    return
  end

  require('fixity.commands').silent.update.stdin(self:patch(mark)).apply {
    '--cached',
    '-',
  }
end

return Diff
