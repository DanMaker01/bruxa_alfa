@echo off
cd /d "%~dp0"
python -c "import PySide6" 2>nul || (
  echo Instalando PySide6...
  python -m pip install PySide6
)
python editor_eventos.py
if errorlevel 1 pause
