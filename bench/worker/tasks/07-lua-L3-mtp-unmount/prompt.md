Bug report for my yazi plugin `simple-mtp` (`dotfiles/yazi/.config/yazi/plugins/simple-mtp.yazi/main.lua`):

On a machine where no MTP device has been mounted yet since boot, running
`plugin simple-mtp -- unmount` does not show the "No hay dispositivos MTP
montados" warning. Instead it immediately tries to unmount a "device" whose
name looks like `ls: cannot access '/run/user/1000/mtp': No such file or
directory`, and then reports `Error desmontando: ls: cannot access ...`.

Expected: when nothing is mounted, the plugin shows the warning and runs no
unmount command. Unmounting a device that really is mounted, and mounting,
must keep working as they do now.

Find the cause and fix it. The plugin runs inside yazi, so to try it outside
yazi you need small stubs for the yazi globals it uses (`ya`, `Command`, `Url`;
`fs` if you use it); `lua` and `luac -p` are available. Make sure
`luac -p dotfiles/yazi/.config/yazi/plugins/simple-mtp.yazi/main.lua` succeeds.
Change only that file.
