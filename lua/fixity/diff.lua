local commands = require'fixity.commands'

local Diff = require'fixity.display':new{
  __module = 'diff';
  keymaps = {
    ['q'] = '<Cmd>bw<CR>',
    ['-'] = {method = 'stage_hunk'},
  },
  syntax = [[
    syn clear

    syn match fxAdd "^+.*$"
    syn match fxDelete "^-.*$"

    syn match fxHunkHeader "@@.*@@"
  ]],
}

function Diff:preprocess_lines(lines)
  -- TODO: This function is hardcoded and ugly
  self.header = vim.list_slice(lines, 0, 4) -- ENQUIRE: leave the header?
  lines = vim.list_slice(lines, 5)
  self.hunks = {}
  for i, line in ipairs(lines) do
    if line:match('^@@.-@@') then
      self.hunks[#self.hunks+1] = {line}
    else
      self.hunks[#self.hunks][#self.hunks[#self.hunks]+1] = line
      self.hunks[#self.hunks+1] = self.hunks[#self.hunks]
    end
  end
  return lines
end

function Diff:set_view()
  vim.fn.search('^[-+]') --ENQUIRE: Set height
end

function Diff:find_hunk()
  -- TODO: Hardcoded and ugly again
  local lnum = vim.fn.getcurpos()[2] - 2 -- Compensating for the header
  local hunk = vim.fn.copy(self.header)
  vim.list_extend(hunk, self.hunks[lnum])
  return hunk
end

function Diff:stage_hunk()
  local job = commands.construct(
    'git',
    {'apply', '--cached', '-'}
  )

  local patch = table.concat(vim.tbl_map(
    function(l)
      return string.format('%s\n', l)
    end,
    self:find_hunk()
  ))

  job:start() -- ENQUIRE: move to commands
  job:send(patch)
  job.stdin:close()
  job:wait()

  self.update_displays()
end

function Diff:update_specific()
  if vim.tbl_isempty(self.hunks, {}) then
    vim.api.nvim_buf_delete(self.buf, {})
  end
end

return Diff
