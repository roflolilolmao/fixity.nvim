function fixity#dev()
  messages clear
lua << EOF
  require'plenary.reload'.reload_module('fixity', true)
  require'fixity'.dev_func()
EOF
endfunction
