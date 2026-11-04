@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set PYEXE=python
set PYARGS=
where py >nul 2>nul && (set PYEXE=py & set PYARGS=-3)

"%PYEXE%" %PYARGS% tools\apply_translations.py
if errorlevel 1 goto fail

echo.
echo ---- dictionary check ----
"%PYEXE%" %PYARGS% tools\check.py

echo.
echo ---- font coverage check ----
set FONT=out\font.ttf
if exist "%FONT%" (
  "%PYEXE%" %PYARGS% tools\check_font.py --font "%FONT%"
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
