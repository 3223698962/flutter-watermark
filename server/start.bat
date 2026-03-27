@echo off
chcp 65001 >nul
echo 启动数字水印平台后端服务...
echo.
cd /d "%~dp0"
call venv\Scripts\activate
python run.py
pause