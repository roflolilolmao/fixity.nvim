local commands = require 'fixity.commands'

local Untracked = {
  _module = 'untracked',
  keymaps = {
    ['-'] = {
      func = commands.silent.update.add,
      args = { method = 'find_filename' },
    },
    ['d'] = {
      func = commands.silent.update.direct.rm,
      args = { method = 'find_filename' },
    },
  },
}

function Untracked.lines()
  local lines
  commands.silent.callback(function(result)
    lines = result
  end)['ls-files'] { '--others', '--exclude-standard' }
  return lines
end

function Untracked:find_filename()
  return vim.api.nvim_get_current_line():match [[^(%S*)$]]
end

return Untracked