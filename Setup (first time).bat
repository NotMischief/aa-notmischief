@echo off
title AA NotMischef - first-time setup
echo This installs what the macro needs: AutoHotkey v2, Python, and the Python vision packages.
echo (Uses winget, Windows' own installer. Already-installed parts are skipped.)
echo.
where winget >nul 2>nul || (echo winget was not found - install "App Installer" from the Microsoft Store, or install AutoHotkey v2 from autohotkey.com and Python from python.org by hand. & pause & exit /b)

if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" (echo AutoHotkey v2: already installed) else (
  echo Installing AutoHotkey v2...
  winget install -e --id AutoHotkey.AutoHotkey --accept-package-agreements --accept-source-agreements
)

set PY=
where py >nul 2>nul && set PY=py -3
if not defined PY where python >nul 2>nul && set PY=python
if not defined PY (
  echo Installing Python 3.12...
  winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
  echo.
  echo Python was just installed. Close this window and run this file once more to finish.
  pause
  exit /b
)
echo Using Python: %PY%
%PY% -m pip install --upgrade pip
%PY% -m pip install numpy opencv-python mss rapidocr_onnxruntime
echo.
echo All done. Start Main.ahk. Windows display scale should be 100%%, and press F1 once Roblox is open.
pause
