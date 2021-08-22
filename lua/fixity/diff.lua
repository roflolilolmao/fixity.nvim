local Diff = require'fixity.display':new{
  __module = 'diff';
  keymaps = {
    ['q'] = '<Cmd>bw<CR>',
    ['-'] = {method = 'stage_hunk'},
  },
  syntax = [[
    syn clear

    syn match fxAdd "^+.*$"
    syn match fxDelete "^-.*$"

    syn match fxHunkHeader "@@.*@@"
  ]],
}

function Diff:preprocess_lines(lines)
  local hunk_header = '^@@.-@@'

  local function split_header_and_hunks(lines)
    for i, line in ipairs(lines) do
      if line:match(hunk_header) then
        return vim.list_slice(lines, 0, i - 1), vim.list_slice(lines, i, #lines)
      end
    end

    return {}, {}
  end

  local function split_hunks(lines, offset)
    local line_to_hunk = {}
    local hunks = {}

    for i, line in ipairs(lines) do
      if line:match(hunk_header) then
        hunks[#hunks+1] = {start = i + offset, contents = {line}}
      else
        local contents = hunks[#hunks].contents
        contents[#contents+1] = line
      end

      line_to_hunk[#line_to_hunk+1] = hunks[#hunks]
    end

    vim.tbl_add_reverse_lookup(hunks)
    return hunks, line_to_hunk
  end

  local hunks
  self.header, hunks = split_header_and_hunks(lines)
  self.hunks, self.line_to_hunk = split_hunks(
    hunks,
    #self.header + #self.buffer_header
  )

  return lines
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

  vim.api.nvim_win_set_height(
    win,
    vim.fn.max{
      vim.api.nvim_win_get_height(win),
      hunk_size,
    }
  )

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
