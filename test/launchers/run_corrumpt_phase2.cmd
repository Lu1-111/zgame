@echo off
setlocal
cd /d "%~dp0..\..\"
set "APPDATA=%~dp0..\..\work\corrumpt\playtest\AppData"
set "LOCALAPPDATA=%~dp0..\..\work\corrumpt\playtest\LocalAppData"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not defined GODOT_BIN set "GODOT_BIN=D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_BIN%" goto run
for %%G in (godot.exe godot4.exe) do for %%P in (%%~$PATH:G) do set "GODOT_BIN=%%P"
if exist "%GODOT_BIN%" goto run
echo Godot 4.x was not found. Set GODOT_BIN to your Godot executable.
pause
exit /b 1
:run
"%GODOT_BIN%" --path "%~dp0..\..\." --rendering-method gl_compatibility --windowed --resolution 1280x720 --max-fps 60 res://test/scenes/previews/corrumpt_arena.tscn -- --phase2
