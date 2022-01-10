# Info For Developers
Hello👋 this directory contains tools for "building" the `script.lua` and `playlist.xml` for Stormworks as well as for generating a fresh save that can be quickly loaded for faster testing.

The `.vscode` directory can be moved out to the root directory for those using VS Code. It is placed in this dev directory to keep things neat but has to be moved out to be recognized by VS Code.

## Building C² For Stormworks
Running `\dev\build\build.bat` will copy all files from `\src` to the addon saves folder for Stormworks (`C:\Users\USER\AppData\Roaming\Stormworks\data\missions`) under the directory `Carsa's Commands`

This can be done in VS Code by running the build task [^1]

## Testing In Stormworks
To make testing easier and to allow skipping the brutal menus for creating a new save, `\dev\test\newSave.bat` can be run to generate a new save that **overwrites the autosave save file**.

This then allows you to select the continue button on the main menu of Stormworks to get right into a fresh save for testing C²

[^1]: Default `CTRL + SHIFT + B`