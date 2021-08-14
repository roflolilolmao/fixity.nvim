local commands = require'fixity.commands'

local CompactSummary = require'fixity.display':new{
  __module = 'compact-summary';
  keymaps = {
    ['o'] =  {method = 'diff_file'};
  },
  syntax = [[
    syn clear

    syn match fxReference "\x\+\s(.*, .\{-})" contains=fxCommit
    syn match fxCommit "^\x\+" contained

    syn match fxFileChange "|\s\+\d\+\s[+-]*$" contains=fxAdd,fxDelete

    syn match fxAdd /+/ contained
    syn match fxDelete /-/ contained
  ]],
  options = {
    winfixheight = true,
  },
}

function CompactSummary:find_filename()
  local filename = vim.api.nvim_get_current_line():match[[^%s(%S*)%s]]

  if filename then
    return string.format(':/%s', filename)
  end

  return nil
end

function CompactSummary:diff_file()
  local filename = self:find_filename()

  if filename ~= nil then
    require'fixity.diff':send_it({'diff'}, {self.args, '--', filename})
  else
    print'no file on the current line'
  end
end

CompactSummary.unstaged = CompactSummary:new{
  __module = 'compact-summary';
  __name = 'unstaged';
  keymaps = {
    ['-'] = {func = commands.silent.add, args = {method = 'find_filename'}},
    ['d'] = {func = commands.silent.checkout, args = {method = 'find_filename'}},
  },
}

CompactSummary.staged = CompactSummary:new{
  __module = 'compact-summary';
  __name = 'staged';
  keymaps = {
    ['-'] = {func = commands.silent.reset, args = {'--', {method = 'find_filename'}}},
  },
}

return CompactSummary
