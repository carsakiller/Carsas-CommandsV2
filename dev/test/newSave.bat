@echo off
TITLE CC Save Generation Tool

SETLOCAL
SET MY_DIR=%~dp0
SET SRC_DIR="%MY_DIR%..\..\dev\test\freshSave"

SET SAVE_NAME="autosave"
SET TARGET_DIR="%AppData%\Stormworks\saves"

CALL :NORMALIZEPATH %SRC_DIR%
SET SOURCE="%ABSPATH%"

SET TARGET="%TARGET_DIR:"=%\%SAVE_NAME:"=%"

XCOPY /s/v/i/e %SOURCE% %TARGET% && (
  ECHO [7m[92m SUCCESS [0m
) || (
  ECHO [7m[91m FAILED [0m
)

ENDLOCAL
TIMEOUT 3


:NORMALIZEPATH
  SET ABSPATH=%~f1
  EXIT /B