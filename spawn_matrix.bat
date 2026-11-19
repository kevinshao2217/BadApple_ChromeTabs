@echo off
rem ============================================================
rem  Tab Matrix launcher
rem    spawn_matrix.bat [rows] [cols]     (optional: pre-fill the control page)
rem  1. starts the local server (node server.js 8760)
rem  2. opens the control page (master.html) in a dedicated Chrome instance
rem     (own profile in .\chrome-profile, background throttling off)
rem  Then use the control page to choose rows / tabs / position and press "Generate".
rem  Close every window of that Chrome instance before running this again, or the flags will not apply.
rem ============================================================
setlocal
cd /d "%~dp0"
set PORT=8760
set Q=
if not "%~1"=="" set Q=?rows=%~1
if not "%~2"=="" set Q=%Q%^&cols=%~2

where node >nul 2>nul || (echo Node.js not found. Install it from https://nodejs.org & pause & exit /b 1)
rem stop an older server still holding the port, so the newest server.js is used
for /f "tokens=5" %%p in ('netstat -ano ^| findstr /r /c:":%PORT% .*LISTENING"') do taskkill /PID %%p /F >nul 2>nul
start "tab-matrix server" /min node server.js %PORT%
timeout /t 1 /nobreak >nul

set PROFILE=%~dp0chrome-profile
start "" chrome --user-data-dir="%PROFILE%" --no-first-run --no-default-browser-check --disable-extensions ^
 --renderer-process-limit=12 --disable-renderer-backgrounding --disable-background-timer-throttling ^
 --disable-backgrounding-occluded-windows --disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling,Translate ^
 --new-window "http://localhost:%PORT%/master.html%Q%"
endlocal
