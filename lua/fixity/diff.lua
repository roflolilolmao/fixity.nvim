local Diff = require'fixity.display':new{
  __module = 'diff';
  keymaps = {
    -- TODO: this command should only exist for unstaged
    ['-'] = {method = 'stage_hunk'},
  },
  syntax = [[
    syn clear

    syn match fixityAdd "^+.*$"
    syn match fixityDelete "^-.*$"

    syn match fixityHunkHeader "@@.*@@"
  ]],
}

function Diff:postprocess()
  local hunk_header = '^@@.-@@'
  local hunks

  local offset = #self.buffer_header
  local lines = vim.api.nvim_buf_get_lines(self.buf, offset, -1, false)

  for i, line in ipairs(lines) do
    if line:match(hunk_header) then
      self.header = vim.list_slice(lines, 0, i - 1)
      break
    end
  end

  offset = #self.header + #self.buffer_header
  lines = vim.api.nvim_buf_get_lines(self.buf, offset, -1, false)

  self.line_to_hunk = {}
  self.hunks = {}

  for i, line in ipairs(lines) do
    if line:match(hunk_header) then
      self.hunks[#self.hunks+1] = {start = i + offset, contents = {line}}
    else
      local contents = self.hunks[#self.hunks].contents
      contents[#contents+1] = line
    end

    self.line_to_hunk[#self.line_to_hunk+1] = self.hunks[#self.hunks]
  end

  vim.tbl_add_reverse_lookup(self.hunks)
end

function Diff:set_view()
  local win = vim.fn.bufwinid(self.buf)
  local hunk = self:find_hunk()

  if hunk == nil then
    hunk = self.hunks[1]

    if hunk == nil then
      return
    end
  end

  vim.api.nvim_win_set_height(win, #hunk.contents)
  vim.fn.winrestview{lnum = hunk.start, topline = hunk.start}
  vim.fn.search('^[-+]')
end

function Diff:should_close()
  return vim.tbl_isempty(self.hunks, {})
end

function Diff:next()
  local index = self.hunks[self:find_hunk()]

  if index == nil or index >= #self.hunks then
    index = 0
  end

  self:jump_to_hunk(index + 1)
end

function Diff:previous()
  local index = self.hunks[self:find_hunk()]

  if index == nil or index <= 1 then
    index = #self.hunks + 1
  end

  self:jump_to_hunk(index - 1)
end

function Diff:jump_to_hunk(index)
  local win = vim.fn.bufwinid(self.buf)
  local col = vim.api.nvim_win_get_cursor(win)[2]

  vim.api.nvim_win_set_cursor(win, {self.hunks[index].start, col})

  self:set_view()
end

function Diff:find_hunk()
  local row = vim.api.nvim_win_get_cursor(vim.fn.bufwinid(self.buf))[1]
  local lnum = row - #self.header - #self.buffer_header
  return self.line_to_hunk[lnum]
end

function Diff:patch(hunk)
  return table.concat(vim.tbl_flatten{self.header, hunk.contents, ''}, '\n')
end

function Diff:stage_hunk()
  require'fixity.commands'
    .silent
    .update
    .stdin(self:patch(self:find_hunk()))
    .apply{'--cached', '-'};
end

return Diff
