local function build_args(args)
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
    vim.tbl_flatten({to_string(args)})
  )
end

local function construct(opts, command, args)
  return require'plenary.job':new{
    command = command,
    args = args,
    cwd = opts.cwd,
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

      if opts.callback then
        opts.callback(result)
      end

      if opts.schedule then
        vim.schedule(function()
          opts.schedule(result)
        end)
      end
    end,
  }
end

local function git_root()
  local root
  construct(
    {
      callback = function(result)
        root = result[1]
      end,
    },
    'git',
    {'rev-parse', '--show-toplevel'}
  ):sync()
  return root
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
    build_args({command, args}),
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
  args = args or {}

  if not opts.cwd then
    opts.cwd = git_root()
  end

  if not opts.direct then
    args = {command, args}
    command = 'git'
  end

  if not opts.silent then
    return pop(opts, command, args)
  end

  local job = construct(
    opts,
    command,
    build_args(args)
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
  direct = function(t)
    t.__options.direct = true
    return t
  end,
  schedule = function(t)
    return function(callback)
      t.__options.schedule = callback
      return t
    end
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
