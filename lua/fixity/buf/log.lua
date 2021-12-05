local commands = require 'fixity.commands'
local repo = require 'fixity.repo'

local find_target = {
  func = function(decoration, commit)
    return decoration or commit
  end,
  args = {
    { method = 'cursor_mark_contents' },
    { method = 'find_commit' },
  },
}

local Log = {
  _module = 'log',
  keymaps = {
    ['o'] = {
      func = require('fixity').compact_summary,
      args = { method = 'find_commit' },
    },

    ['co'] = {
      func = commands.update.checkout,
      args = find_target,
    },

    ['cf'] = {
      func = commands.update.silent.commit,
      args = { '--fixup', { method = 'find_commit' } },
    },

    ['cp'] = {
      func = commands.update['cherry-pick'],
      args = { method = 'find_commit' },
    },

    ['d'] = {
      func = commands.update.branch,
      args = { '-d', { method = 'cursor_mark_contents' } },
    },
    ['D'] = {
      func = commands.update.branch,
      args = { '-D', { method = 'cursor_mark_contents' } },
    },

    ['rr'] = {
      func = commands.update.rebase,
      args = { method = 'find_commit' },
    },
    ['ri'] = {
      func = commands.update.rebase,
      args = { '--interactive', { method = 'find_commit' } },
    },
    ['rf'] = {
      func = commands.update.rebase,
      args = { '--interactive', '--autosquash', { method = 'find_commit' } },
    },

    ['xm'] = {
      func = commands.update.merge,
      args = find_target,
    },

    ['rs'] = {
      func = commands.update.reset,
      args = { method = 'find_commit' },
    },
    ['xRH'] = {
      func = commands.update.reset,
      args = { '--hard', { method = 'find_commit' } },
    },
  },
  syntax = [[
    syn clear

    syn match fixityLineStart /^[ *\/|]*\s*\x*\s*\((.\{-})\s\)\?/ contains=fixityGraph,fixityCommit,fixityDecoration

    syn match fixityGraph "[\/\\|]" contained
    syn match fixityCommit /\x\+/ contained

    syn match fixityDecoration /(.\{-})/ contained contains=fixityHeadStart
    syn match fixityHeadStart /(HEAD\( -> \)\?/ contained contains=fixityHead
    syn match fixityHead /HEAD\( -> \)\?/ contained
  ]],
}

function Log.lines()
  local lines
  commands.silent.callback(function(result)
    lines = vim.tbl_map(function(line)
      return line:gsub('%s*$', '')
    end, result)
  end).log {
    '--decorate',
    '--oneline',
    '--graph',
    '--branches',
    '--remotes',
    'HEAD',
  }
  return lines
end

function Log:set_marks()
  local function process_mark(row, line, start, end_)
    line = line:sub(start, end_)

    local found = line:find ' %-> '
    if found then
      start = start + found + 3
      line = line:gsub('.* -> ', '')
    end

    row, start = row - 1, start - 1

    local hl_group
    if vim.tbl_contains(repo.branches, line) then
      hl_group = 'fixityBranch'
    elseif vim.tbl_contains(repo.remote_branches, line) then
      hl_group = 'fixityRemoteBranch'
    else
      hl_group = 'luaError'
    end

    self:add_mark(
      { row = row, col = start },
      { row = row, col = end_ },
      hl_group
    )

  end

  local decorated_line = vim.regex [[^[ *\/|]*\s*\x*\s*(.\{-})\s]]
  local decoration = vim.regex [[(.\{-})]]

  local offset = 0
  local lines = vim.api.nvim_buf_get_lines(self.buf, offset, -1, false)

  for row, line in ipairs(lines) do
    local start, end_, found

    if decorated_line:match_str(line) then
      start, end_ = decoration:match_str(line)
      line = line:sub(1, end_) -- avoids matching commas after the decoration
      repeat
        found = line:find(', ', start + 1, true) or end_
        process_mark(row + offset, line, start + 2, found - 1)
        start = found
      until found == end_
    end
  end

  self.buffer_header = {
    {
      table.concat(vim.tbl_flatten { self.command, { self.args } }, ' '),
      'Constant',
    },
  }

  vim.api.nvim_buf_set_extmark(
    self.buf,
    require'fixity.buf.marks'.namespace,
    0,
    2,
    {
      virt_text = { { 'bonjour', 'comment' } },
      virt_text_pos = 'overlay',
      virt_lines = {{{'salut', 'constant'}}},
      virt_lines_above = true,
      virt_lines_leftcol = true
    }
  )

end

function Log:find_commit()
  return vim.api.nvim_get_current_line():match [[^[ */\|]*%s*(%x*)%s*.*$]]
end

return Log
