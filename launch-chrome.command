#!/usr/bin/env bash
# Start a SEPARATE Chrome instance (dedicated profile + CDP debug port) that
# Playwright MCP connects to. This does NOT quit or touch your normal Chrome -
# a second Chrome window opens with its own profile.
#
# Why a dedicated profile: Chrome refuses remote debugging on your default
# profile (security measure), so we use a separate profile dir. You log into
# LinkedIn once in this profile and it persists across runs.
#
# Why this still beats Playwright's bundled Chromium: this is your real Chrome
# binary - genuine plugins, WebGL, TLS, and NO navigator.webdriver flag - so
# LinkedIn's automation detection sees a normal Chrome, not an automation tool.
#
# Keep this Chrome running while you scrape. Close it when done to turn the
# debug port off.
set -e

PORT=9222
PROFILE="$HOME/.csm-outreach/chrome-profile"
mkdir -p "$PROFILE"

echo "==> Starting a separate Chrome (dedicated profile: $PROFILE) on port $PORT..."
echo "    Your normal Chrome is left alone."
open -na "Google Chrome" --args --remote-debugging-port="$PORT" --user-data-dir="$PROFILE"

echo ""
echo "Done. A new Chrome window opened. Playwright MCP connects to http://127.0.0.1:$PORT."
echo "Log into LinkedIn (once) in THIS Chrome window - the session persists."
echo "Keep this Chrome running while you scrape. Close it when done."
echo ""
read -n 1 -s -r -p "Press any key to close this window."
