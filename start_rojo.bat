@echo off
rem Starts the Rojo live-sync server for this project (Studio: Rojo panel -> Connect).
cd /d "%~dp0"
rojo serve
pause
