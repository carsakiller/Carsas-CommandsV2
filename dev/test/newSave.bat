@echo off
TITLE CC Save Generation Tool

SETLOCAL
SET SRC_DIR=.\freshSave

SET SAVE_NAME="autosave"
SET TARGET_DIR=%AppData%\Stormworks\saves

CALL :NORMALIZEPATH %SRC_DIR%
SET SOURCE="%ABSPATH%"

ECHO %SOURCE%

SET TARGET="%TARGET_DIR:"=%\%SAVE_NAME:"=%"

XCOPY /s/v/i/e %SOURCE% %TARGET%

ECHO [7m[92mSUCCESS[0m

ENDLOCAL
TIMEOUT 3


:NORMALIZEPATH
  SET ABSPATH=%~f1
  EXIT /B