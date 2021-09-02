local commands = require'fixity.commands'

local Log = require'fixity.display':new{
  __module = 'log';
  keymaps = {
    ['o'] = {method = 'compact_summary'};

    ['co'] = {func = commands.update.checkout, args = {method = 'find_commit'}};

    ['d'] = {func = commands.update.branch, args = {'-d', {method = 'find_commit'}}},
    ['D'] = {func = commands.update.branch, args = {'-D', {method = 'find_commit'}}};

    ['rr'] = {func = commands.update.rebase, args = {method = 'find_commit'}},
    ['ri'] = {func = commands.update.rebase, args = {'--interactive', {method = 'find_commit'}}};

    ['rs'] = {func = commands.update.reset, args = {method = 'find_commit'}};
  },
  split = 'topleft vsplit',
  syntax = [[
    syn clear

    syn match fxLineStart /^[ *\/|]*\s*\x*\s*/ contains=fxGraph,fxCommit
    syn match fxGraph "[\/\\|]" contained
    syn match fxCommit /\x\+/ contained
  ]],
}

function Log:preprocess_lines(lines)
  return vim.tbl_map(function(line) return line:gsub('%s*$', '') end, lines)
end

function Log:postprocess()
  local decorated_line = vim.regex[[^[ *\/|]*\s*\x*\s*(.\{-})\s]]
  local decoration = vim.regex[[(.\{-})]]

  local function set_mark(line, start, end_)
    vim.api.nvim_buf_set_extmark(
      self.buf,
      self.namespace,
      line - 1,
      start + 1,
      {
        end_col = end_ - 1,
        hl_group = 'fxBranch',
      }
    )
  end

  for i, line in ipairs(vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)) do
    local start, end_, found

    if decorated_line:match_str(line) then
      start, end_ = decoration:match_str(line)
      repeat
        found = line:find(', ', start + 1, true) or end_
        set_mark(i, start, found)
        start = found
      until found == end_
    end
  end
end

function Log:find_commit()
  return vim.api.nvim_get_current_line():match[[^[ */\|]*%s*(%x*)%s*.*$]]
end

function Log:find_decorations()
  local commit, remainder = vim.api.nvim_get_current_line():match[[^[ */\|]*%s*(%x*)%s*(.*)$]]
  local decorations = remainder:match[[^%((.-)%)]]

  if decorations == nil then
    return {}
  end

  decorations = decorations:gsub('HEAD %-> ', '')
  decorations = vim.split(decorations, ', ')
  -- TODO: prioritize local branches
  return decorations
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

function Log:next()
  -- TODO: find next decoration
end

function Log:previous()
  -- TODO: find previous decoration
end

return Log
