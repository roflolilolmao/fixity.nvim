local M = {}

function M.log()
  require('fixity.log'):send_it('log', {
    '--decorate',
    '--oneline',
    '--graph',
    '--branches',
    '--remotes',
    'HEAD',
  })
end

function M.staged()
  require('fixity.compact-summary').staged:send_it('diff', {
    '--compact-summary',
    '--stat=256',
    '--cached',
  })
end

function M.unstaged()
  require('fixity.compact-summary').unstaged:send_it('diff', {
    '--compact-summary',
    '--stat=256',
  })
end

function M.untracked()
  require('fixity.untracked'):send_it(
    'ls-files',
    { '--others', '--exclude-standard' }
  )
end

function M.compact_summary(commit)
  require('fixity.compact-summary'):send_it('diff', {
    '--compact-summary',
    '--stat=256',
    string.format('%s^!', commit),
  })
end

function M.diff(commit, filename)
  require('fixity.diff'):send_it('diff', { commit, '--', filename })
end

function M.df()
  require'fixity.buf':new()
end

function M.dev_func()
  local displays = require 'fixity.displays'

  if displays.none_opened() then
    M.log()
    M.staged()
    M.unstaged()
    M.untracked()
  else
    displays.update()
  end
end

return M
