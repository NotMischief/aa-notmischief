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

rem [11-05] pick a Python the reading packages exist for (3.13 / 3.12 / 3.14) - the newest one
rem (3.15 on a friend's PC) had no numpy, so the vision helper never started
set "PY="
where py >nul 2>nul && for %%V in (3.13 3.12 3.14) do if not defined PY py -%%V -c "import sys" <nul >nul 2>nul && set "PY=py -%%V"
where py >nul 2>nul || (where python >nul 2>nul && set "PY=python")
if not defined PY (
  echo Installing Python 3.13...
  winget install -e --id Python.Python.3.13 --accept-package-agreements --accept-source-agreements
  echo.
  echo Python was just installed. Close this window and run this file once more to finish.
  pause
  exit /b
)
echo Using Python: %PY%
%PY% -m pip install --upgrade pip
%PY% -m pip install numpy opencv-python mss
%PY% -m pip install rapidocr onnxruntime || %PY% -m pip install rapidocr_onnxruntime
%PY% -c "import numpy, cv2, mss" || (echo. & echo The reading packages did not install for %PY%. The macro still works, just slower. & pause & exit /b)
rem remember this Python for the macro (Settings\Python.txt) so it doesn't pick another one
if not exist "%~dp0Settings" mkdir "%~dp0Settings"
%PY% -c "import sys, os; print(os.path.join(os.path.dirname(sys.executable), 'pythonw.exe'))" > "%~dp0Settings\Python.txt"
echo.
echo All done. Start Main.ahk. Windows display scale should be 100%%, and press F1 once Roblox is open.
pause
