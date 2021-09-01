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
    ['n'] = {method = 'next'},
    ['p'] = {method = 'previous'},

    ['q'] = close;

    ['f'] = {func = commands.update.fetch, args = {'--all', '--prune'}},

    ['cc'] = commands.update.commit,
    ['ca'] = {func = commands.update.commit, args = {'--amend'}},
    ['ce'] = {func = commands.update.commit, args = {'--amend', '--no-edit'}};

    ['xp'] = commands.update.push,
    ['xPF'] = {func = commands.update.push, args = {'--force'}};
  },
  split = 'leftabove split',
  options = {},
}
Display.__index = Display

function Display.update_displays()
  local function update(display)
    -- DEV: only `display:update` should be called
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
      print('Unknown error, deleted buffer', buf)
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
  vim.api.nvim_win_set_option(win, 'scrolloff', 1)

  self:set_content(lines)
  self:set_keymaps()
  self:set_syntax()
  self:set_highlights()
  self:set_view()
end

function Display:set_content(lines)
  local command = {self.command, {self.args}}
  self.buffer_header = {table.concat(vim.tbl_flatten(command), ' '), ''}

  if self.preprocess_lines then
    lines = self:preprocess_lines(lines)
  end

  lines = vim.list_extend(
    vim.fn.deepcopy(self.buffer_header),
    lines
  )

  vim.api.nvim_buf_set_option(self.buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.buf, 'modifiable', false)
end

function Display:set_view()
  local win = vim.fn.bufwinid(self.buf)

  if win > 0 and self.options.winfixheight then
    vim.api.nvim_win_set_height(win, vim.api.nvim_buf_line_count(self.buf))
    vim.api.nvim_win_set_option(win, 'winfixheight', true)
    vim.fn.win_execute(win, [[call winrestview({'topline': 1})]])
  end

  vim.fn.winrestview{lnum = #self.buffer_header + 1}
end

function Display:update()
  commands.silent.schedule(function(result)
    self:set_content(result)

    if self.should_close then
      if self:should_close() then
        vim.api.nvim_buf_delete(self.buf, {})
        return
      end
    end

    self:set_keymaps()

    vim.api.nvim_buf_call(self.buf, function()
      -- DEV: `set_syntax` and `set_highlights` should be removed
      self:set_syntax()
      self:set_highlights()
      self:set_view()
    end)
  end)[self.command](self.args)
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

    return string.format('__displays[%s]%s(%s)', self.buf, call, args)
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
  commands.silent.schedule(
    function(result)
      self:new{command = command, args = args}:create_buf(result)
    end
  )[command](args)
end

function Display:next()
  local win = vim.fn.bufwinid(self.buf)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))

  if row < vim.fn.line('$') then
    vim.api.nvim_win_set_cursor(win, {row + 1, col})
  end
end

function Display:previous()
  local win = vim.fn.bufwinid(self.buf)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))

  if row > #self.buffer_header + 1 then
    vim.api.nvim_win_set_cursor(win, {row - 1, col})
  end
end

Display.untracked = Display:new{
  __module = 'display',
  __name = 'untracked';
  keymaps = {
    ['-'] = {func = commands.silent.update.add, args = {method = 'find_filename'}},
    ['d'] = {func = commands.silent.update.direct.rm, args = {method = 'find_filename'}},
  },
  options = {
    winfixheight = true,
  },
}

function Display.untracked:find_filename()
  return vim.api.nvim_get_current_line():match[[^(%S*)$]]
end

return Display
