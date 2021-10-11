local commands = require 'fixity.commands'

local CompactSummary = require('fixity.display'):extend {
  _module = 'compact-summary',
  keymaps = {
    ['o'] = { method = 'diff_file' },
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
  -- TODO: use set_marks instead
  return vim.api.nvim_get_current_line():match [[^%s(%S*)%s]]
end

function CompactSummary:diff_file()
  local filename = self:find_filename()

  if filename ~= nil then
    -- A bit too hardcoded but works for now
    local commit
    if type(self.args) == 'table' then
      commit = vim.tbl_filter(function(a)
        return not a:match '%-%-'
      end, self.args)
    else
      commit = ''
    end

    require('fixity').diff(commit, filename)
  end
end

CompactSummary.unstaged = CompactSummary:extend {
  _module = 'compact-summary',
  _name = 'unstaged',
  keymaps = {
    ['-'] = {
      func = commands.silent.update.add,
      args = { method = 'find_filename' },
    },
    ['d'] = {
      func = commands.silent.update.checkout,
      args = { '--', { method = 'find_filename' } },
    },
  },
}

CompactSummary.staged = CompactSummary:extend {
  _module = 'compact-summary',
  _name = 'staged',
  keymaps = {
    ['-'] = {
      func = commands.silent.update.reset,
      args = { '--', { method = 'find_filename' } },
    },
    ['d'] = {
      func = commands.silent.update.restore,
      args = { '--staged', '--worktree', { method = 'find_filename' } },
    },
  },
}

function CompactSummary.staged:diff_file()
  local filename = self:find_filename()
  if filename ~= nil then
    require('fixity').diff('--cached', filename)
  end
end

return CompactSummary
