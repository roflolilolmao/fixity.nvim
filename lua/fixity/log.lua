local commands = require'fixity.commands'

local Log = require'fixity.display':new{
  __module = 'log';
  keymaps = {
    ['o'] = {method = 'compact_summary'};

    ['co'] = {func = commands.checkout, args = {method = 'find_commit'}};

    ['d'] = {func = commands.branch, args = {'-d', {method = 'find_commit'}}};
    ['D'] = {func = commands.branch, args = {'-D', {method = 'find_commit'}}};

    ['rr'] = {func = commands.rebase, args = {method = 'find_commit'}},
    ['ri'] = {func = commands.rebase, args = {'--interactive', {method = 'find_commit'}}};
  },
  split = 'topleft vsplit',
  syntax = [[
    syn clear

    syn match fxLineStart /^[ *\/|]*\s*\x*\s*\((.\{-})\s\)\?/ contains=fxGraph,fxCommit,fxDecoration

    syn match fxGraph "[\/\\|]" contained
    syn match fxCommit /\x\+/ contained

    syn match fxDecoration /(.\{-})/ contained contains=fxHead,fxBranch,fxOriginBranch
    syn match fxBranch "[-_/a-zA-Z]\+" contained
    syn match fxOriginBranch "origin\/[-_/a-zA-Z]\+" contained
    syn match fxHead /HEAD ->/ contained
  ]],
}

function Log:preprocess_lines(lines)
  return vim.tbl_map(function(line) return line:gsub('%s*$', '') end, lines)
end

function Log:find_commit()
  local line = vim.api.nvim_get_current_line()
  local commit, remainder = line:match[[^[ */\|]*%s*(%x*)%s*(.*)$]]
  local decoration = remainder:match[[^%((.-)%)]]

  local target

  if decoration ~= nil then
    decoration = decoration:gsub('HEAD %-> ', '')
    target = decoration:gsub([[,.*]], '')
  else
    target = commit
  end

  return target
end

function Log:compact_summary()
  local commit = self:find_commit() -- ENQUIRE
  require'fixity.compact-summary':send_it(
    {'diff', '--compact-summary'},
    {string.format('%s^..%s', commit, commit)}
  )
end

return Log
