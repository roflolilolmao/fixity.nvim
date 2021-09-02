local commands = require'fixity.commands'
local repo = require'fixity.repo'

local Log = require'fixity.display':new{
  __module = 'log';
  keymaps = {
    ['o'] = {method = 'compact_summary'};

    ['co'] = {func = commands.update.checkout, args = {method = 'find_decoration'}};

    ['d'] = {func = commands.update.branch, args = {'-d', {method = 'find_decoration'}}},
    ['D'] = {func = commands.update.branch, args = {'-D', {method = 'find_decoration'}}};

    ['rr'] = {func = commands.update.rebase, args = {method = 'find_commit'}},
    ['ri'] = {func = commands.update.rebase, args = {'--interactive', {method = 'find_commit'}}};

    ['rs'] = {func = commands.update.reset, args = {method = 'find_commit'}};
  },
  split = 'topleft vsplit',
  syntax = [[
    syn clear

    syn match fxLineStart /^[ *\/|]*\s*\x*\s*\((.\{-})\s\)\?/ contains=fxGraph,fxCommit,fxDecoration

    syn match fxGraph "[\/\\|]" contained
    syn match fxCommit /\x\+/ contained

    syn match fxDecoration /(.\{-})/ contained contains=fxHeadStart
    syn match fxHeadStart /(HEAD\( -> \)\?/ contained contains=fxHead
    syn match fxHead /HEAD\( -> \)\?/ contained
  ]],
}

function Log:preprocess_lines(lines)
  return vim.tbl_map(function(line) return line:gsub('%s*$', '') end, lines)
end

function Log:postprocess()
  self:set_highlight_mark()
  vim.cmd(string.format(
      [[autocmd CursorMoved <buffer=%s> %s]],
      self.buf, self:build_command({method = 'highlight_current_decoration'})
  ))

  local decorated_line = vim.regex[[^[ *\/|]*\s*\x*\s*(.\{-})\s]]
  local decoration = vim.regex[[(.\{-})]]

  local function process_mark(row, line, start, end_)
    line = line:sub(start, end_)

    local found = line:find(' %-> ')
    if found then
      start = start + found + 3
      line = line:gsub('.* -> ', '')
    end

    row, start = row - 1, start - 1

    if vim.tbl_contains(repo.branches, line) then
      self:set_mark(row, start, end_, 'fxBranch')
    elseif vim.tbl_contains(repo.remote_branches, line) then
      self:set_mark(row, start, end_, 'fxRemoteBranch')
    else
      self:set_mark(row, start, end_, 'luaError')
    end
  end

  for row, line in ipairs(vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)) do
    local start, end_, found

    if decorated_line:match_str(line) then
      start, end_ = decoration:match_str(line)
      repeat
        found = line:find(', ', start + 1, true) or end_
        process_mark(row, line, start + 2, found - 1)
        start = found
      until found == end_
    end
  end
end

function Log:next()
  self:jump(0, -1, 1)
end

function Log:previous()
  self:jump(-1, 0, -1)
end

function Log:jump(start_search, end_search, col_offset)
  local row, col = unpack(vim.api.nvim_win_get_cursor(vim.fn.bufwinid(self.buf)))
  row, col = row - 1, col + col_offset

  local result = vim.api.nvim_buf_get_extmarks(
    self.buf,
    self.namespace,
    {row, col},
    end_search,
    {limit = 1, details = true}
  )[1]

  if not result then
    result = vim.api.nvim_buf_get_extmarks(
      self.buf,
      self.namespace,
      start_search,
      end_search,
      {limit = 1, details = true}
    )[1]
  end

  row, col = result[2], result[3]
  vim.api.nvim_win_set_cursor(win, {row + 1, col})
end

function Log:set_mark(row, start, end_, hl_group, opts)
  local opts = opts or {}
  opts.end_col = end_
  opts.hl_group = hl_group
  vim.api.nvim_buf_set_extmark(self.buf, self.namespace, row, start, opts)
end

function Log:set_highlight_mark(row, start, end_)
  local hl_group = 'fixityMatch'

  if not row then
    hl_group = nil
    row = 0
    start = 0
    end_ = 0
  end

  self:set_mark(row, start, end_, hl_group, {id = 1})
end

function Log:find_commit()
  return vim.api.nvim_get_current_line():match[[^[ */\|]*%s*(%x*)%s*.*$]]
end

function Log:get_cursor_decoration()
  local row, col = unpack(vim.api.nvim_win_get_cursor(vim.fn.bufwinid(self.buf)))
  row, col = row - 1, col + 1

  local results = vim.api.nvim_buf_get_extmarks(
    self.buf,
    self.namespace,
    {row, 0},
    {row, -1},
    {details = true}
  )

  for _, result in ipairs(results) do
    local start, end_ = result[3], result[4].end_col
    if start < col and col <= end_ then
      return row, start, end_
    end
  end

  return nil
end

function Log:highlight_current_decoration()
  self:set_highlight_mark(self:get_cursor_decoration())
end

function Log:find_decoration()
  local row, start, end_ = self:get_cursor_decoration()

  if not row then
    return nil
  end

  local line = vim.api.nvim_buf_get_lines(self.buf, row, row + 1, true)[1]
  return line:sub(start + 1, end_)
end


function Log:compact_summary()
  local commit = self:find_commit()
  require'fixity.compact-summary':send_it(
    'diff',
    {
      '--compact-summary',
      string.format('%s^..%s', commit, commit)
    }
  )
end

return Log
