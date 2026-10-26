@echo off
setlocal
cd /d "%~dp0"
if defined GODOT_BIN if exist "%GODOT_BIN%" goto run
set "GODOT_BIN=D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_BIN%" goto run
for %%G in (godot.exe godot4.exe) do for %%P in (%%~$PATH:G) do set "GODOT_BIN=%%P"
if exist "%GODOT_BIN%" goto run
echo Godot 4.x was not found. Set GODOT_BIN to your Godot executable.
pause
exit /b 1
:run
"%GODOT_BIN%" --path "%~dp0." res://scenes/rooms/forest_01.tscn
