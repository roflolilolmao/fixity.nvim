local commands = require'fixity.commands'

__displays = __displays or {}

local function close()
  for buf, _ in pairs(__displays) do
    vim.api.nvim_buf_delete(buf, {})
  end
end

local Display = {
  __module = 'display';
  keymaps = {
    ['q'] = close;

    ['f'] = commands.fetch,

    ['cc'] = commands.commit,
    ['ca'] = {func = commands.commit, args = {'--amend'}},
    ['ce'] = {func = commands.commit, args = {'--amend', '--no-edit'}};

    ['xp'] = commands.push,
    ['xPF'] = {func = commands.push, args = {'--force'}};
  },
  split = 'leftabove split',
  options = {},
}
Display.__index = Display

function Display.update_displays()
  local function update(display)
    -- TODO: clean up that dev thingy
    local module = string.format('fixity.%s', display.__module)
    require'plenary.reload'.reload_module(module, true)
    module = require(module)

    if display.__name then
      setmetatable(display, module[display.__name])
    else
      setmetatable(display, module)
    end

    display:update()
  end

  for buf, display in pairs(__displays) do
    if not pcall(update, display) then
      print('delete buffer', buf)
      __displays[buf] = nil
    end
  end
end

function Display:new(table)
  local instance = {}
  setmetatable(instance, self)
  instance.__index = instance

  if type(table) == 'table' then
    for k, v in pairs(table) do
      if type(v) == 'table' then
        instance[k] = vim.tbl_extend('force', instance[k] or {}, v)
      else
        instance[k] = v
      end
    end
  end

  return instance
end

function Display:create_buf(lines)
  self.buf = vim.api.nvim_create_buf(false, true)

  if not vim.api.nvim_buf_is_valid(self.buf) then
    print('invalid buffer', self.buf)
    return
  end

  table.insert(__displays, self.buf, self)
  vim.cmd(string.format(
      [[autocmd BufUnload <buffer=%s> lua __displays[%s] = nil]],
      self.buf, self.buf
  ))
  vim.api.nvim_buf_set_option(self.buf, 'bufhidden', 'wipe')

  vim.cmd(self.split)

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, self.buf)

  self:set_content(lines)
  self:set_view()

  self:set_keymaps()
  self:set_syntax()
  self:set_highlights()
end

function Display:set_content(lines)
  if self.preprocess_lines then
    lines = self:preprocess_lines(lines)
  end

  local command = {}
  vim.list_extend(command, self.command or {})
  vim.list_extend(command, self.args or {})
  lines = vim.list_extend({table.concat(command, ' '), ''}, lines)

  vim.api.nvim_buf_set_option(self.buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.buf, 'modifiable', false)

  local win = vim.fn.bufwinid(self.buf)

  if win > 0 and self.options.winfixheight then
    vim.api.nvim_win_set_height(win, vim.api.nvim_buf_line_count(self.buf))
    vim.api.nvim_win_set_option(win, 'winfixheight', true)
    vim.fn.win_execute(win, [[call winrestview({'topline': 1})]]) -- ENQUIRE
  end
end

function Display:set_view()
  vim.fn.winrestview{lnum = 3}
end

function Display:update()
  commands.send_it(self.command, self.args, function(result)
    self:set_content(result)
    self:set_keymaps()

    vim.api.nvim_buf_call(self.buf, function()
      self:set_syntax()
      self:set_highlights()
    end)

    if self.update_specific then
      self:update_specific()
    end
  end)
end

function Display:set_map(lhs, rhs)
  local function build(value)
    local function build_args(args)
      local function build_arg(arg)
        if type(arg) == 'string' then
          return string.format('"%s"', arg)
        end
        return arg
      end

      if not vim.tbl_islist(args) then
        args = {args}
      end

      args = vim.tbl_map(build_arg, args or {})
      return table.concat(vim.tbl_map(build, args), ', ')
    end

    local function func_(func)
      if not self.funcs then
        self.funcs = {}
      end
      self.funcs[#self.funcs+1] = func
      return string.format('.funcs[%s]', #self.funcs)
    end

    local function method_(method)
      return string.format(':%s', method)
    end

    if type(value) == 'string' then
      return value
    end

    local call
    local args = ''
    if type(value) == 'table' then
      if value.method then
        call = method_(value.method)
      elseif value.func then
        call = func_(value.func)
      end
      args = build_args(value.args)
    elseif type(value) == 'function' then
      call = func_(value)
    else
      error(string.format('Map error: unsupported %s[%s]', value, type(value)))
    end

    return string.format('__displays[%s]%s{%s}', self.buf, call, args)
  end

  local function build_map()
    if type(rhs) == 'string' then
      return rhs
    end
    return string.format('<Cmd>lua %s<CR>', build(rhs))
  end

  vim.api.nvim_buf_set_keymap(
    self.buf,
    'n',
    lhs,
    build_map(),
    {}
  )
end

function Display:set_keymaps()
  for lhs, rhs in pairs(self.keymaps) do
    self:set_map(lhs, rhs)
  end
end

function Display:set_syntax()
  if self.syntax ~= nil then
    vim.cmd(self.syntax)
  end
end

function Display:set_highlights()
  vim.cmd([[
    hi! def link fxAdd DiffAdd
    hi! def link fxDelete DiffDelete

    hi! def link fxHunkHeader DiffChange

    hi! def link fxCommit Label

    hi! def link fxGraph Identifier
    hi! def link fxHead Identifier
    hi! def link fxBranch String
    hi! def link fxOriginBranch Character
  ]])
end

function Display:send_it(command, args)
  commands.send_it(
    command,
    args,
    function(result)
      self:new{command = command, args = args}:create_buf(result)
    end
  )
end

return Display
