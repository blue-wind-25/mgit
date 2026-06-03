@echo off
:: mgit.cmd — Windows launcher for mgit
:: Place this file in the same directory as the mgit Python script,
:: and add that directory to your PATH.
::
:: Requires: Python 3.6+ in PATH (python or python3)
::
:: Usage: exactly like the Unix version — mgit <command> [args...]

setlocal

:: Resolve the directory containing this .cmd file
set "MGIT_DIR=%~dp0"

:: Prefer python3 if available, fall back to python
where python3 >nul 2>&1
if %errorlevel% == 0 (
    set "PYTHON=python3"
) else (
    set "PYTHON=python"
)

"%PYTHON%" "%MGIT_DIR%mgit" %*
