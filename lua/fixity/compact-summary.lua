local commands = require'fixity.commands'

local CompactSummary = require'fixity.display':new{
  __module = 'compact-summary';
  keymaps = {
    ['o'] =  {method = 'diff_file'};
  },
  syntax = [[
    syn clear

    syn match fixityReference "\x\+\s(.*, .\{-})" contains=fixityCommit
    syn match fixityCommit "^\x\+" contained

    syn match fixityFileChange "|\s\+\d\+\s[+-]*$" contains=fixityAdd,fixityDelete

    syn match fixityAdd /+/ contained
    syn match fixityDelete /-/ contained
  ]],
  options = {
    winfixheight = true,
  },
}

function CompactSummary:find_filename()
  return vim.api.nvim_get_current_line():match[[^%s(%S*)%s]]
end

function CompactSummary:diff_file()
  local filename = self:find_filename()

  if filename ~= nil then
    -- A bit too hardcoded but works for now
    local commit
    if type(self.args) == 'table' then
      commit = vim.tbl_filter(
        function(a)
          return a ~= '--compact-summary'
        end,
        self.args
      )
    else
      commit = ''
    end
    require'fixity.diff':send_it('diff', {commit, '--', filename})
  else
    print'no file on the current line'
  end
end

CompactSummary.unstaged = CompactSummary:new{
  __module = 'compact-summary';
  __name = 'unstaged';
  keymaps = {
    ['-'] = {func = commands.silent.update.add, args = {method = 'find_filename'}},
    ['d'] = {func = commands.silent.update.checkout, args = {method = 'find_filename'}},
  },
}

CompactSummary.staged = CompactSummary:new{
  __module = 'compact-summary';
  __name = 'staged';
  keymaps = {
    ['-'] = {func = commands.silent.update.reset, args = {'--', {method = 'find_filename'}}},
  },
}

return CompactSummary
