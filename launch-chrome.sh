#!/usr/bin/env bash
# Launch YOUR real Chrome/Chromium with a CDP debug port so Playwright MCP can
# drive it. See launch-chrome.command for the macOS version (same logic).
#
# Why: the agent uses your genuine Chrome fingerprint + existing logged-in
# sessions (e.g. LinkedIn) instead of a separate detectable Playwright browser.
set -e

PORT=9222
CHROME=$(command -v google-chrome || command -v google-chrome-stable || command -v chromium || command -v chromium-browser || true)

if [ -z "$CHROME" ]; then
  echo "Could not find google-chrome or chromium on your PATH."
  echo "Install Chrome, or edit this script to point CHROME at your chrome binary."
  exit 1
fi

echo "==> Quitting Chrome..."
pkill -f "google-chrome|chromium" 2>/dev/null || true
sleep 2

echo "==> Relaunching $CHROME with remote debugging on port $PORT..."
"$CHROME" --remote-debugging-port="$PORT" >/dev/null 2>&1 &

echo ""
echo "Done. Chrome is starting. Playwright MCP will connect to http://localhost:$PORT."
echo "Log into LinkedIn (once) in this Chrome if you haven't already."
echo "Keep Chrome running while you scrape."
