#!/usr/bin/env bash
# Start a SEPARATE Chrome/Chromium instance (dedicated profile + CDP debug port)
# that Playwright MCP connects to. Does NOT quit your normal Chrome.
# See launch-chrome.command for the macOS version (same logic + rationale).
set -e

PORT=9222
PROFILE="$HOME/.csm-outreach/chrome-profile"
mkdir -p "$PROFILE"
CHROME=$(command -v google-chrome || command -v google-chrome-stable || command -v chromium || command -v chromium-browser || true)

if [ -z "$CHROME" ]; then
  echo "Could not find google-chrome or chromium on your PATH."
  echo "Install Chrome, or edit this script to point CHROME at your chrome binary."
  exit 1
fi

echo "==> Starting a separate Chrome (dedicated profile: $PROFILE) on port $PORT..."
"$CHROME" --remote-debugging-port="$PORT" --user-data-dir="$PROFILE" >/dev/null 2>&1 &

echo ""
echo "Done. A new Chrome window opened. Playwright MCP connects to http://127.0.0.1:$PORT."
echo "Log into LinkedIn (once) in THIS Chrome window - the session persists."
echo "Keep this Chrome running while you scrape. Close it when done."
