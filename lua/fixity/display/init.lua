local commands = require 'fixity.commands'

local Display = vim.tbl_deep_extend(
  'error',
  {
    _module = 'display',
    keymaps = {
      ['n'] = { method = 'jump_to_next' },
      ['p'] = { method = 'jump_to_previous' },

      ['q'] = 'bwipe',
      ['<Esc>'] = require('fixity.displays').close_all,

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
  require 'fixity.display.buffer',
  require 'fixity.display.marks',
  require 'fixity.display.maps'
)

Display.__index = Display

function Display:extend(table)
  local new = vim.tbl_deep_extend('force', self, table)
  new.__index = new
  return new
end

function Display:new(table)
  local instance = table or {}
  setmetatable(instance, self)

  instance:create_buf()
  instance:update()
end

function Display:send_it(command, args)
  self:new { command = command, args = args }
end

function Display:update()
  local contents

  if not vim.api.nvim_buf_is_valid(self.buf) then
    require'fixity.displays'.deref(self.buf)
    return
  end

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

  self:jump_to_next()
end

function Display:should_close()
  return false
end

return Display
