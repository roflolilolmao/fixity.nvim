local function build_args(command, args)
  local function to_string(arg)
    if arg == nil then
      return {}
    end

    if type(arg) == 'string' then
      return {arg}
    end

    if type(arg) == 'table' then
      return arg
    end

    error(string.format(
      'unimplemented for %s of type %s',
      arg,
      type(arg)
    ))
  end

  return vim.tbl_filter(
    function(a)
      return #a > 0
    end,
    vim.tbl_flatten({to_string(command), to_string(args)})
  )
end

local function construct(command, args, callback)
  return require'plenary.job':new{
    command = command,
    args = args,
    on_stderr = function(...)
      print(vim.inspect{'stderr', ...})
    end,
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        print(vim.inspect{command, args}, 'returned', return_val)
        print(vim.inspect(j:stderr_result()))
        return
      end

      local result = j:result()

      if callback == nil then
        callback = function(result)
          print(vim.inspect{command, args}, 'returned', vim.inspect(result))
        end
      end

      vim.schedule(function()
        callback(result)
      end)
    end,
  }
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
  vim.cmd(string.format(
      [[autocmd TermOpen <buffer=%s> startinsert!]],
      buf
  ))

  -- For some reason, setting the Normal highlight to itself will fix the
  -- background (this might be because my background is set to nil)
  vim.api.nvim_win_set_option(
    win,
    'winhighlight',
    'Normal:Normal,FloatBorder:Title'
  )

  vim.fn.termopen(
    build_args({'git', command}, args or {}),
    {
      on_stderr = function(...)
        print(vim.inspect{'stderr', ...})
      end,
      on_exit = function()
        if opts.update then
          require'fixity.display'.update_displays()
        end
      end,
    }
  )
end

local function send_it(opts, command, args)
  if not opts.silent then
    return pop(opts, command, args)
  end

  local job = construct(
    'git',
    build_args(command, args),
    opts.callback
  )

  job:start()

  if opts.stdin then
    job:send(opts.stdin)
    job.stdin:close()
  end

  job:wait()

  if opts.update then
    require'fixity.display'.update_displays()
  end
end

-- Some black magic
local __options = {
  update = function(t)
    t.__options.update = true
    return t
  end,
  silent = function(t)
    t.__options.silent = true
    return t
  end,
  callback = function(t)
    return function(callback)
      t.__options.callback = callback
      return t
    end
  end,
  stdin = function(t)
    return function(data)
      t.__options.stdin = data
      return t
    end
  end,
}

local OptionsMaker = {
  __index = function(t, k)
    if __options[k] ~= nil then
      return __options[k](t)
    end

    return function(args)
      send_it(t.__options, k, args)
    end
  end
}

local commands = {}

setmetatable(commands, {
  __index = function(_, k)
    local t = {__options = {}}
    setmetatable(t, OptionsMaker)
    return t[k]
  end,
})

return commands
