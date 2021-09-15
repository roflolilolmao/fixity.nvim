local file_dir = vim.fn.expand('%:h')

if file_dir == '' then
  file_dir = '.'
end

local probe = require('fixity.commands').silent.cwd(file_dir)

local M = {}

probe.callback(function(result)
  M.root = result[1]
end)['rev-parse'] '--show-toplevel'

probe.callback(function(result)
  M.remotes = result
end)['remote']()

probe.callback(function(result)
  local refs = vim.tbl_map(function(line)
    return line:sub(3)
  end, result)

  M.branches = {}
  M.remote_branches = {}

  for _, ref in ipairs(refs) do
    local match = ref:match '^remotes/(.*)$'
    if match then
      match = match:gsub(' %-> .*', '')
      table.insert(M.remote_branches, match)
    else
      table.insert(M.branches, ref)
    end
  end
end).branch '-a'

return M
