if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

hi def link fixityAdd DiffAdd
hi def link fixityDelete DiffDelete

hi def link fixityHunkHeader DiffChange

hi def link fixityCommit Label

hi def link fixityGraph Identifier
hi def link fixityHead Identifier
hi def link fixityBranch String
hi def link fixityRemoteBranch Character

hi fixityMatch gui=reverse
