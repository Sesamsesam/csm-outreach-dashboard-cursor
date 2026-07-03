#!/usr/bin/env bash
# Launch YOUR real Chrome with a CDP debug port so Playwright MCP can drive it.
#
# Why: this lets the agent use your genuine Chrome fingerprint AND your existing
# logged-in sessions (e.g. LinkedIn) instead of a separate, detectable
# Playwright-controlled browser. Big reduction in automation-detection risk.
#
# What it does: quits Chrome (your tabs restore on relaunch), then reopens Chrome
# with --remote-debugging-port=9222. Playwright MCP connects to that port.
# Keep Chrome running while you scrape. Close Chrome when you're done to turn
# off the debug port.
set -e

PORT=9222

echo "==> Quitting Chrome (your tabs will restore on relaunch)..."
osascript -e 'tell application "Google Chrome" to quit' 2>/dev/null || true
sleep 2

echo "==> Relaunching Chrome with remote debugging on port $PORT..."
open -a "Google Chrome" --args --remote-debugging-port="$PORT"

echo ""
echo "Done. Chrome is starting. Playwright MCP will connect to http://localhost:$PORT."
echo "Log into LinkedIn (once) in this Chrome if you haven't already."
echo "Keep Chrome running while you scrape. You can close this window."
echo ""
read -n 1 -s -r -p "Press any key to close this window."
