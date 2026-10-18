@echo off
REM SimpleClock - launch script wrapper (double-click this file to run)
REM The .ps1 is executed with ExecutionPolicy Bypass so it works on any machine.
REM If plugin symlink build fails, right-click this file -> Run as administrator.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_windows.ps1"
