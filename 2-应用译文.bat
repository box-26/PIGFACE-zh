@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set PY=D:\AI-Workspace\.venv\Scripts\python.exe
if not exist "%PY%" set PY=python

"%PY%" tools\apply_translations.py
if errorlevel 1 goto fail

echo.
echo ---- dictionary check ----
"%PY%" tools\check.py

echo.
echo ---- font coverage check ----
set FONT=D:\AI-Workspace\release\PIGFACE-汉化\BepInEx\plugins\PigfaceCN\font.ttf
if exist "%FONT%" (
  "%PY%" tools\check_font.py --font "%FONT%"
) else (
  echo font.ttf not found at %FONT% - skip this check
)

echo.
echo Done. If new characters were reported as missing, rebuild the font:
echo   python tools\make_font.py --font ^<full CJK otf^> --out out\font.ttf
echo Then rebuild the dll and repackage - see docs\release.md
pause
exit /b 0

:fail
echo.
echo Merge failed - nothing was written. Read the message above.
pause
exit /b 1
