local Buffer = {
  options = {
    split = 'leftabove split',
  },
  syntax = '',
}

function Buffer:create_buf()
  self.buf = vim.api.nvim_create_buf(false, true)

  if not vim.api.nvim_buf_is_valid(self.buf) then
    print('invalid buffer', self.buf)
    return
  end

  table.insert(_displays, self.buf, self)
  vim.cmd(
    string.format(
      [[autocmd BufUnload <buffer=%s> lua require'fixity.displays'.deref(%s)]],
      self.buf,
      self.buf
    )
  )

  vim.cmd(self.options.split)

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_option(win, 'scrolloff', 1)
  vim.api.nvim_win_set_buf(win, self.buf)

  vim.api.nvim_buf_set_option(self.buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(self.buf, 'filetype', 'fixity')

  vim.cmd(self.syntax)
end

function Buffer:preprocess_lines(contents)
  return contents
end

function Buffer:set_contents(contents)
  self.buffer_header = {
    table.concat(vim.tbl_flatten { self.command, { self.args } }, ' '),
    '',
  }

  contents = self:preprocess_lines(contents)

  vim.api.nvim_buf_set_option(self.buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, self.buffer_header)
  vim.api.nvim_buf_set_lines(self.buf, -1, -1, false, contents)
  vim.api.nvim_buf_set_option(self.buf, 'modifiable', false)

  local win = vim.fn.bufwinid(self.buf)

  if win > 0 and self.options.winfixheight then
    vim.api.nvim_win_set_height(win, vim.api.nvim_buf_line_count(self.buf))
    vim.api.nvim_win_set_option(win, 'winfixheight', true)
  end
end

return Buffer
