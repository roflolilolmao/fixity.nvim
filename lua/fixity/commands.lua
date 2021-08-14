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

local commands = {}

-- Some black magic to enable calling any git command without explicitly
-- declaring a function that will just call `jobstart` or `termopen`.
local _index = {}

setmetatable(commands, {
  __index = function(t, k)
    if _index[k] ~= nil then
      return _index[k]
    end

    return function(args)
      t.pop(k, args)
    end
  end,

  __newindex = function(t, k, v)
    _index[k] = v
  end;
})

commands.silent = {}

setmetatable(commands.silent, {
  __index = function(_, command)
    return function(args)
      local job = vim.fn.jobstart(
        build_args('git', {command, args}),
        {
          on_stderr = function(...)
            print(vim.inspect{'stderr', ...})
          end,
          on_exit = function()
            require'fixity.display'.update_displays()
          end,
        }
      )
      vim.fn.jobwait({job}, 1000)
    end
  end;
})

function commands.construct(command, args, callback)
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

function commands.send_it(command, args, callback)
  commands.construct(
    'git',
    build_args(command, args),
    callback
  ):sync()
end

function commands.pop(command, args)
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
        require'fixity.display'.update_displays()
      end,
    }
  )
end

return commands
