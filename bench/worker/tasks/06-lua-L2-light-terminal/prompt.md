The `terminal` variant of my Neovim theme (`dotfiles/nvim/.config/nvim/lua/Deadlock/my-theme/`)
builds its palette from kitty's colors (`terminal.lua`), but it assumes a dark
terminal: with a light kitty theme the panels and borders come out lighter
than the background. Add light-theme support:

1. In `utils.lua`, add `M.lighten(hex, amount)`: it adds `amount` to each RGB
   channel of a `#rrggbb` color (any case), clamps every channel to 0..255 and
   returns lowercase `#rrggbb`. A negative amount darkens.
2. In `terminal.lua`, use `utils.lighten` instead of the file's own helper.
   When the terminal background is light, meaning its perceived brightness
   `(299*R + 587*G + 114*B) / 1000` is 128 or more, derive the chrome
   backgrounds (sidebar, popup, floating window, menu option and the three
   borders) by darkening the background by the same amounts used today for
   lightening, and set `is_dark = false`. A dark background must give exactly
   the same palette as today.

Both modules run outside Neovim with a stub `vim` global (`vim.fn.expand`,
`vim.fn.system`, `vim.v.shell_error`, `vim.uv.fs_stat`) and
`package.path = "dotfiles/nvim/.config/nvim/lua/?.lua;" .. package.path` under
`luajit`; use that to try your change. Make sure `luajit -b FILE /dev/null`
succeeds for both files. Change only `utils.lua` and `terminal.lua`.
