local Diff = require('fixity.display'):extend {
  _module = 'diff',
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

  local offset = 0
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

  offset = #self.header
  lines = vim.api.nvim_buf_get_lines(self.buf, offset + 1, -1, false)

  local start = offset

  for row, line in ipairs(lines) do
    if hunk_header:match_str(line) then
      self:add_mark(
        { row = start, col = 0 },
        { row = row + offset - 1, col = #lines[row - 1] },
        nil,
        { lnum = start + 5, col = 1, topline = start + 1 }
      )
      start = row + offset
    end
  end

  self:add_mark(
    { row = start, col = 0 },
    { row = #lines + offset, col = #lines[#lines] },
    nil,
    { lnum = start + 5, col = 1, topline = start + 1 }
  )
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
