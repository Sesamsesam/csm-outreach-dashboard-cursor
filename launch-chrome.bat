@echo off
REM Start a SEPARATE Chrome instance (dedicated profile + CDP debug port) that
REM Playwright MCP connects to. This does NOT quit or touch your normal Chrome -
REM a second Chrome window opens with its own profile.
REM
REM Why a dedicated profile: Chrome refuses remote debugging on your default
REM profile (security measure), so we use a separate profile dir. You log into
REM LinkedIn once in this profile and it persists across runs.
REM
REM Keep this Chrome running while you scrape. Close it when done to turn the
REM debug port off.

set PORT=9222
set PROFILE=%USERPROFILE%\.csm-outreach\chrome-profile
if not exist "%PROFILE%" mkdir "%PROFILE%"

echo ==> Starting a separate Chrome (dedicated profile) on port %PORT%...
echo    Your normal Chrome is left alone.
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=%PORT% --user-data-dir="%PROFILE%"

echo.
echo Done. A new Chrome window opened. Playwright MCP connects to http://127.0.0.1:%PORT%.
echo Log into LinkedIn (once) in THIS Chrome window - the session persists.
echo Keep this Chrome running while you scrape. Close it when done.
echo.
pause
