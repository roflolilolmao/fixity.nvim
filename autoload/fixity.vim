function fixity#dev()
  messages clear
lua << EOF
  require'plenary.reload'.reload_module('fixity', true)
  require'fixity'.dev_func()
EOF
endfunction

function fixity#d()
  messages clear
lua << EOF
  require'plenary.reload'.reload_module('fixity', true)
  require'fixity'.df()
EOF
endfunction
