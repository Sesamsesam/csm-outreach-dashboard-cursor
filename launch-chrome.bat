@echo off
REM Launch YOUR real Chrome with a CDP debug port so Playwright MCP can drive it.
REM
REM Why: this lets the agent use your genuine Chrome fingerprint AND your existing
REM logged-in sessions (e.g. LinkedIn) instead of a separate, detectable
REM Playwright-controlled browser. Big reduction in automation-detection risk.
REM
REM What it does: quits Chrome, then reopens Chrome with
REM --remote-debugging-port=9222. Playwright MCP connects to that port.
REM Keep Chrome running while you scrape. Close Chrome when you're done to turn
REM off the debug port.

set PORT=9222

echo ==> Quitting Chrome...
taskkill /F /IM chrome.exe 2>nul
timeout /t 2 /nobreak >nul

echo ==> Relaunching Chrome with remote debugging on port %PORT%...
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=%PORT%

echo.
echo Done. Chrome is starting. Playwright MCP will connect to http://localhost:%PORT%.
echo Log into LinkedIn (once) in this Chrome if you haven't already.
echo Keep Chrome running while you scrape.
echo.
pause
