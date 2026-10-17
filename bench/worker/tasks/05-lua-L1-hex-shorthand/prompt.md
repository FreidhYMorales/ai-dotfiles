In `dotfiles/nvim/.config/nvim/lua/Deadlock/my-theme/utils.lua`, make the color
helpers `mix` and `shade` also accept 3-digit shorthand hex colors such as
`#fa0` (meaning `#ffaa00`), in upper or lower case, as either argument. The
6-digit form keeps working exactly as before, and any other string (wrong
length, no `#`, non-hex digits) must still raise an error.

The module runs outside Neovim if you stub `vim`, for example:

    luajit -e 'vim = { o = { background = "dark" } }
      package.path = "dotfiles/nvim/.config/nvim/lua/?.lua;" .. package.path
      print(require("Deadlock.my-theme.utils").mix("#fff", "#000", 0.5))'

Use it to try your change, including the error cases. Make sure
`luajit -b dotfiles/nvim/.config/nvim/lua/Deadlock/my-theme/utils.lua /dev/null`
succeeds. Change only that file.
