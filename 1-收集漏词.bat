@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set PY=D:\AI-Workspace\.venv\Scripts\python.exe
if not exist "%PY%" set PY=python

set MISS=%~1
if "%MISS%"=="" (
  for %%D in (
    "D:\AI-Workspace\PIGFACE-zh\BepInEx\PigfaceCN\miss.log"
    "E:\SteamLibrary\steamapps\common\PIGFACE\BepInEx\PigfaceCN\miss.log"
  ) do (
    if exist %%D set MISS=%%~D
  )
)

if "%MISS%"=="" (
  echo.
  echo   miss.log not found. Drag miss.log onto this file, or pass its path:
  echo     "1-collect.bat" "C:\path\to\miss.log"
  echo.
  pause
  exit /b 1
)

echo Using log: %MISS%
echo.
"%PY%" tools\collect_missing.py --miss "%MISS%"
echo.
echo Open 待翻译.tsv, fill the 4th column, then run 2-应用译文.bat
pause
