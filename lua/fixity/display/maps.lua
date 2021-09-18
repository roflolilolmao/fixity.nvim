local Maps = { keymaps = {} }

function Maps:build_arg(arg)
  if type(arg) == 'string' then
    return string.format('"%s"', arg)
  end

  return self:build(arg)
end

function Maps:build_args(args)
  if not vim.tbl_islist(args) then
    args = { args }
  end

  return table.concat(
    vim.tbl_map(function(arg)
      return self:build_arg(arg)
    end, args),
    ', '
  )
end

function Maps:method_(method)
  return string.format(':%s', method)
end

function Maps:func_(func)
  self.funcs[#self.funcs + 1] = func
  return string.format('.funcs[%s]', #self.funcs)
end

function Maps:build(value)
  if type(value) == 'string' then
    return value
  end

  local call
  local args = ''
  if type(value) == 'table' then
    args = self:build_args(value.args)

    if value.method then
      call = self:method_(value.method)
    elseif value.func then
      call = self:func_(value.func)
    else
      error(string.format('Map error: missing func or method in %s', value))
    end
  elseif type(value) == 'function' then
    call = self:func_(value)
  else
    error(string.format('Map error: unsupported %s[%s]', value, type(value)))
  end

  return string.format('_displays[%s]%s(%s)', self.buf, call, args)
end

function Maps:build_command(rhs)
  if type(rhs) ~= 'string' then
    rhs = string.format('lua %s', self:build(rhs))
  end

  return rhs
end

function Maps:set_keymaps()
  self.funcs = {}

  for lhs, rhs in pairs(self.keymaps) do
    rhs = string.format('<Cmd>%s<CR>', self:build_command(rhs))
    vim.api.nvim_buf_set_keymap(self.buf, 'n', lhs, rhs, {})
  end
end

return Maps
