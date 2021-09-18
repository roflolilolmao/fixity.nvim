local function build_args(args)
  local function to_string(arg)
    if arg == nil then
      return {}
    end

    if type(arg) == 'string' then
      return { arg }
    end

    if type(arg) == 'table' then
      return arg
    end

    error(string.format('unimplemented for %s of type %s', arg, type(arg)))
  end

  return vim.tbl_filter(
    function(a)
      return #a > 0
    end,
    vim.tbl_flatten {
      to_string(args),
    }
  )
end

local function pop(opts, command, args)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'win',
    width = 80,
    height = 24,
    row = 1,
    col = 3,
    border = 'rounded',
    style = 'minimal',
  })
  vim.cmd(string.format([[autocmd TermOpen <buffer=%s> startinsert]], buf))

  vim.fn.termopen(build_args { command, args }, {
    cwd = opts.cwd,
    on_stderr = function(...)
      print(vim.inspect { 'stderr', ... })
    end,
    on_exit = function()
      if opts.update then
        require('fixity.displays').update()
      end
    end,
  })
end

local function construct(opts, command, args)
  return require('plenary.job'):new {
    command = command,
    args = args,
    cwd = opts.cwd,
    on_stderr = function(...)
      print(vim.inspect { 'stderr', ... })
    end,
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        print(vim.inspect { command, args }, 'returned', return_val)
        print(vim.inspect(j:stderr_result()))
        return
      end

      local result = j:result()

      if opts.callback then
        opts.callback(result)
      end
    end,
  }
end

local function send_it(opts, command, ...)
  if not opts.cwd then
    opts.cwd = require('fixity.repo').root
  end

  local args = ...
  if not opts.direct then
    args = { command, ... }
    command = 'git'
  end

  if not opts.silent then
    return pop(opts, command, args)
  end

  local job = construct(opts, command, build_args(args))
  job:start()

  if opts.stdin then
    job:send(opts.stdin)
    job.stdin:close()
  end

  job:wait()

  if opts.update then
    require('fixity.displays').update()
  end
end

-- Some black magic
local function bool(name)
  return function(t)
    t.__options[name] = true
    return t
  end
end

local function setter(name)
  return function(t)
    return function(value)
      t.__options[name] = value
      return t
    end
  end
end

local __options = {
  direct = bool 'direct',
  silent = bool 'silent',
  update = bool 'update',

  callback = setter 'callback',
  cwd = setter 'cwd',
  stdin = setter 'stdin',
}

local OptionsMaker = {
  __index = function(t, k)
    if __options[k] ~= nil then
      return __options[k](t)
    end

    return function(...)
      send_it(t.__options, k, ...)
    end
  end,
}

local commands = {}

setmetatable(commands, {
  __index = function(_, k)
    local t = { __options = {} }
    setmetatable(t, OptionsMaker)
    return t[k]
  end,
  __call = function(t, k, ...)
      return t[k](...)
  end,
})

vim.cmd "command! -nargs=+ F lua require'fixity.commands'(<f-args>)"

return commands
