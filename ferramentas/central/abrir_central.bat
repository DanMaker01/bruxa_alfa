@echo off
cd /d "%~dp0"
python central.py
if errorlevel 1 pause
