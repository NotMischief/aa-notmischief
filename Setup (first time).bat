@echo off
setlocal
title AA NotMischef - first-time setup
cd /d "%~dp0"
if not exist "%~dp0Logs" mkdir "%~dp0Logs"
if not exist "%~dp0Settings" mkdir "%~dp0Settings"
set "LOG=%~dp0Logs\setup_log.txt"
>"%LOG%" echo ==== AA NotMischef setup %date% %time% ====
echo This installs what the macro needs: AutoHotkey v2, Python, and the Python vision packages.
echo (Uses winget, Windows' own installer. Already-installed parts are skipped.)
echo Everything it does is also written to Logs\setup_log.txt - send that file if something fails.
echo.
where winget >nul 2>nul || (echo winget was not found - install "App Installer" from the Microsoft Store, or install AutoHotkey v2 from autohotkey.com and Python 3.13 from python.org by hand. & >>"%LOG%" echo no winget & pause & exit /b)

if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" (echo AutoHotkey v2: already installed) else if exist "%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe" (echo AutoHotkey v2: already installed) else (
  echo Installing AutoHotkey v2...
  winget install -e --id AutoHotkey.AutoHotkey --accept-package-agreements --accept-source-agreements >>"%LOG%" 2>&1
)

rem [11-07] Find a Python the reading packages exist for (3.13 / 3.12 / 3.14) BY ITS FOLDER. Asking "py" for a
rem version failed on a PC with Python 3.15 and the new Python install manager: "py" never saw the 3.13 that
rem was just installed, so the setup asked to be run again and again and the packages never got installed.
call :findpy
if not defined PYEXE (
  echo Installing Python 3.13 - this can take a minute...
  >>"%LOG%" echo installing Python 3.13 with winget
  winget install -e --id Python.Python.3.13 --scope user --accept-package-agreements --accept-source-agreements >>"%LOG%" 2>&1
  call :findpy
)
if not defined PYEXE (
  rem the new Python install manager has its own installer command
  where py >nul 2>nul && (>>"%LOG%" echo trying: py install 3.13 & py install 3.13 <nul >>"%LOG%" 2>&1)
  call :findpy
)
if not defined PYEXE (
  echo.
  echo Couldn't find or install Python 3.13. Install it by hand from python.org ^(Windows installer, 64-bit,
  echo version 3.13^), then run this file again. Details are in Logs\setup_log.txt.
  >>"%LOG%" echo FAILED: no Python 3.13/3.12/3.14 found after installing
  pause
  exit /b
)
echo Using Python: "%PYEXE%"
>>"%LOG%" echo using "%PYEXE%"
echo Installing the vision packages (numpy, OpenCV, mss, RapidOCR) - this can take a few minutes...
"%PYEXE%" -m ensurepip --upgrade >>"%LOG%" 2>&1
"%PYEXE%" -m pip install --upgrade pip >>"%LOG%" 2>&1
"%PYEXE%" -m pip install numpy opencv-python mss >>"%LOG%" 2>&1
"%PYEXE%" -m pip install rapidocr onnxruntime >>"%LOG%" 2>&1 || "%PYEXE%" -m pip install rapidocr_onnxruntime >>"%LOG%" 2>&1
"%PYEXE%" -c "import numpy, cv2, mss; print('packages OK')" >>"%LOG%" 2>&1
if errorlevel 1 (
  echo.
  echo The vision packages did not install. The macro still works, just slower.
  echo Please send Logs\setup_log.txt.
  >>"%LOG%" echo FAILED: packages
  pause
  exit /b
)
"%PYEXE%" -c "import onnxruntime; print('onnxruntime OK')" >>"%LOG%" 2>&1 || echo Text reading package missing - the macro uses Windows' own text reading instead.
rem remember this Python for the macro (Settings\Python.txt) - otherwise it starts the newest one (e.g. 3.15)
set "PYW=%PYEXE:python.exe=pythonw.exe%"
>"%~dp0Settings\Python.txt" echo %PYW%
>>"%LOG%" echo wrote Settings\Python.txt: %PYW%
>>"%LOG%" echo DONE
echo.
echo All done. Start Main.ahk. Windows display scale should be 100%%, and press F1 once Roblox is open.
pause
exit /b

:findpy
set "PYEXE="
for %%P in ("%LOCALAPPDATA%\Programs\Python\Python313\python.exe" "%LOCALAPPDATA%\Python\pythoncore-3.13-64\python.exe" "%ProgramFiles%\Python313\python.exe" "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" "%LOCALAPPDATA%\Python\pythoncore-3.12-64\python.exe" "%ProgramFiles%\Python312\python.exe" "%LOCALAPPDATA%\Programs\Python\Python314\python.exe" "%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe" "%ProgramFiles%\Python314\python.exe") do if not defined PYEXE if exist "%%~P" set "PYEXE=%%~P"
if defined PYEXE goto :eof
where py >nul 2>nul || goto :eof
for %%V in (3.13 3.12 3.14) do if not defined PYEXE for /f "usebackq delims=" %%E in (`py -%%V -c "import sys; print(sys.executable)" 2^>nul ^<nul`) do if exist "%%E" set "PYEXE=%%E"
goto :eof
