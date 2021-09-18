_displays = _displays or {}

local M = {}

function M.close_all()
  for buf, _ in pairs(_displays) do
    vim.api.nvim_buf_delete(buf, {})
  end
end

function M.deref(buf)
  _displays[buf] = nil
end

function M.none_opened()
  return vim.tbl_isempty(_displays)
end

function M.update()
  local function update(display)
    -- DEV: only `display:update` should be called
    local module = string.format('fixity.%s', display._module)
    require('plenary.reload').reload_module(module, true)
    module = require(module)

    if display._name then
      setmetatable(display, module[display._name])
    else
      setmetatable(display, module)
    end

    display:update()
  end

  for buf, display in pairs(_displays) do
    update(display)
  end
end

return M
