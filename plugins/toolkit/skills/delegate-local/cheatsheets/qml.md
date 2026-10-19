QML (Quickshell, Qt 6):
- A JS library file starts with the line `.pragma library` (with the dot). Never put `pragma Singleton` or `pragma library` in a .js file.
- Use it from QML with `import "path/file.js" as Name` and call `Name.fn()`, always qualified.
- Check every QML or JS file you touch with `/usr/lib/qt6/bin/qmllint FILE`; fix every error and warning it reports.
