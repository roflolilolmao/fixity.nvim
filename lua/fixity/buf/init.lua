local commands = require 'fixity.commands'

local Buffer = vim.tbl_deep_extend(
  'error',
  {
    options = {
      split = 'leftabove split',
    },
    keymaps = {
      ['n'] = { method = 'jump_to_next' },
      ['p'] = { method = 'jump_to_previous' },

      ['<Esc>'] = 'bwipe',

      ['f'] = { func = commands.update.fetch, args = { '--all', '--prune' } },
      ['F'] = { func = commands.update.pull },

      ['cc'] = commands.update.commit,
      ['ca'] = { func = commands.update.commit, args = { '--amend' } },
      ['ce'] = {
        func = commands.update.commit,
        args = { '--amend', '--no-edit' },
      },

      ['xp'] = commands.update.push,
      ['xPF'] = { func = commands.update.push, args = { '--force' } },

      ['ss'] = commands.update.stash,
      ['sp'] = { func = commands.update.stash, args = { 'pop' } },
    },
  },
  require 'fixity.buf.buffer',
  require 'fixity.buf.marks',
  require 'fixity.buf.maps'
)

Buffer.__index = Buffer

function Buffer:create_buf()
  self.buf = vim.api.nvim_create_buf(false, true)

  if not vim.api.nvim_buf_is_valid(self.buf) then
    print('invalid buffer', self.buf)
    return
  end

  vim.cmd(self.options.split)

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_option(win, 'scrolloff', 1)
  vim.api.nvim_win_set_buf(win, self.buf)

  vim.api.nvim_buf_set_option(self.buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(self.buf, 'filetype', 'fixity')

  vim.cmd(self.syntax)
end

function Buffer:append(contents)
  vim.api.nvim_buf_set_option(self.buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, contents)
  vim.api.nvim_buf_set_option(self.buf, 'modifiable', false)
end

function Buffer:new(table)
  local instance = table or {}
  setmetatable(instance, self)
  instance:create_buf()
  -- instance:update()

  instance:append(require'fixity.buf.log'.lines())
end

function Buffer:send_it(command, args)
  self:new { command = command, args = args }
end

function Buffer:update()
  local contents

  commands.silent.callback(function(result)
    contents = result
  end)[self.command](self.args)

  self:clear_namespace()

  self:set_contents(contents)
  self:set_marks()

  if self:should_close() then
    vim.api.nvim_buf_delete(self.buf, {})
    return
  end

  self:set_keymaps()
end

return Buffer
