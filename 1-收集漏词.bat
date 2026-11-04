@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

rem Prefer the py launcher, fall back to python on PATH.
set PYEXE=python
set PYARGS=
where py >nul 2>nul && (set PYEXE=py & set PYARGS=-3)

set MISS=%~1
if "%MISS%"=="" (
  for %%D in (
    "miss.log"
    "..\out\miss.log"
    "..\..\PIGFACE-zh\BepInEx\PigfaceCN\miss.log"
  ) do (
    if exist %%D set MISS=%%~fD
  )
)

if "%MISS%"=="" (
  echo.
  echo   miss.log not found. Pass the path, or drag miss.log onto this file:
  echo     "1-collect.bat" "C:\path\to\miss.log"
  echo   It lives in:  ^<game^>\BepInEx\PigfaceCN\miss.log
  echo.
  pause
  exit /b 1
)

echo Using log: %MISS%
echo.
"%PYEXE%" %PYARGS% tools\collect_missing.py --miss "%MISS%"
echo.
echo Open 待翻译.tsv, fill the 4th column, then run 2-应用译文.bat
pause
