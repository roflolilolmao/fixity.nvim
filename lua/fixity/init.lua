local Display = require 'fixity.display'

local M = {}

M.dev_func = function()
  if vim.tbl_isempty(__displays) then
    require('fixity.log'):send_it('log', {
      '--decorate',
      '--oneline',
      '--graph',
      '--branches',
      '--remotes',
      'HEAD',
    })
    require('fixity.compact-summary').staged:send_it(
      'diff',
      { '--compact-summary', '--cached' }
    )
    require('fixity.compact-summary').unstaged:send_it(
      'diff',
      '--compact-summary'
    )
    require('fixity.display').untracked:send_it(
      'ls-files',
      { '--others', '--exclude-standard' }
    )
  else
    Display.update_displays()
  end
end

return M
