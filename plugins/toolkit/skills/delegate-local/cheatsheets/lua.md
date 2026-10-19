Lua:
- Before calling a function, read its definition and pass the argument types it expects (numbers vs tables vs strings).
- Every `function`, `if`, `for` and `while` needs its `end`. After each edit run `luajit -b FILE /dev/null`; it must print nothing.
- Lua indexes from 1, and `#t` only counts the array part of a table.
