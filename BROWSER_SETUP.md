# Browser tool setup (Playwright MCP) + LinkedIn login

The scraper and enrichment skills drive a real, logged-in browser via **Playwright MCP** - Microsoft's official browser-automation MCP server, connected to Cursor. This guide installs it and gets you logged into LinkedIn once. After that, the login persists across runs.

> Why this and not Cursor's built-in browser: Cursor used to ship a built-in browser tool but removed it for security reasons. Cursor's staff recommend Microsoft's official Playwright MCP as the replacement, and it keeps a **persistent profile** so your LinkedIn login sticks between sessions. Cursor's built-in "Browser Tab" doesn't keep a persistent logged-in profile and isn't suitable for this scraping flow.

---

## 1. Install Node.js 18+ (one time)

Playwright MCP runs through `npx`, which needs Node.js 18 or newer.

- Check: `node --version` (or `node -v`). If it prints `v18` or higher, skip to step 2.
- If missing, install the **LTS** version from https://nodejs.org (the LTS installer is fine on macOS and Windows).

## 2. Enable the Playwright MCP server in Cursor (CDP-to-real-Chrome hybrid)

> **It is NOT in Cursor's MCP marketplace.** Searching "Playwright" or "browser" in Customize -> MCP market will find nothing - that's expected. Playwright MCP is added through the project config file, the one-click install button, or the manual "Add new MCP Server" flow below - not the marketplace. Don't waste time looking for it in the market.

**How this project uses it (important):** instead of letting Playwright MCP launch its own detectable Chromium, this repo wires it to **a separate instance of your real Chrome over a CDP debug port**. The agent then drives your genuine Chrome binary - real plugins, real WebGL, real TLS, no `navigator.webdriver` - instead of a detectable automation browser. This is the single biggest LinkedIn-detection-risk reduction available without leaving Microsoft's official tool.

> **Why a dedicated profile (not your daily Chrome):** Chrome refuses to enable remote debugging on your default profile (a security measure). So the helper launches a **separate Chrome instance with its own profile** (`~/.csm-outreach/chrome-profile`). This runs *alongside* your normal Chrome - your normal Chrome is not quit or touched. You log into LinkedIn once in this dedicated profile and it persists across runs.

`.cursor/mcp.json` ships pre-configured for it (note `127.0.0.1`, not `localhost` - Chrome listens on IPv4 and Playwright resolves `localhost` to IPv6, which would refuse):

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest", "--cdp-endpoint", "http://127.0.0.1:9222"]
    }
  }
}
```

Set it up in this order:

1. **Start the dedicated Chrome with the debug port.** Run the helper for your OS (double-click it on macOS, or run from a terminal):
   - macOS: `./launch-chrome.command`
   - Windows: `launch-chrome.bat`
   - Linux: `./launch-chrome.sh`

   It opens a **separate Chrome window** with its own profile and `--remote-debugging-port=9222`. Your normal Chrome is untouched. **Keep this dedicated Chrome running while scraping; close it when done to turn the debug port off.**
2. Open the project folder in Cursor. Cursor detects `.cursor/mcp.json`.
3. Open **Cursor Settings -> Tools & MCP** (or run the **MCP: List Servers** command from the command palette).
4. You should see a **playwright** server. Click **Enable** / toggle it on.
5. The first time it starts, `npx` downloads `@playwright/mcp` (a one-time download; needs Node 18+), then connects to the dedicated Chrome on 127.0.0.1:9222. Wait for it to finish.
6. **Restart Cursor** if the server was just added or its args changed - MCP servers load at startup, not on file save.
7. The server should show as **green / connected**. If it's red, see Troubleshooting below.

### Manual install (if `.cursor/mcp.json` isn't picked up)

In **Cursor Settings -> Tools & MCP -> Add new MCP Server**:
- Name: `playwright`
- Type: `command`
- Command: `npx -y @playwright/mcp@latest --cdp-endpoint http://127.0.0.1:9222`

Or install via the one-click button on the Playwright MCP README: https://github.com/microsoft/playwright-mcp (the "Cursor" section), then edit the server's args to add `--cdp-endpoint http://127.0.0.1:9222`.

### Verify it works

Make sure your dedicated debug Chrome is running, then in Cursor's Agent chat ask: *"Open https://example.com and tell me the page title."* The agent should call `browser_navigate`, a tab opens **in the dedicated Chrome window**, and it reports the title. If that works, the CDP hybrid is live.

### Fallback: simple Playwright Chromium (higher detection risk)

If you can't run the debug-Chrome helper, edit `.cursor/mcp.json` and remove `--cdp-endpoint`, `http://127.0.0.1:9222` from the args so it reads just `["-y", "@playwright/mcp@latest"]`. Playwright MCP then launches its own Chromium with a persistent profile. This works but exposes Playwright's automation fingerprint (`navigator.webdriver = true`, SwiftShader, empty plugins) - higher LinkedIn-detection risk. Use only if the CDP hybrid isn't possible.

---

## 3. Log into LinkedIn (one time)

The skills can't read LinkedIn without a logged-in session. Because the CDP hybrid uses a **dedicated Chrome profile** (separate from your daily Chrome), you log into LinkedIn once in that dedicated profile.

1. Make sure the dedicated debug Chrome is running (run `launch-chrome.command` / `.bat` / `.sh` from step 2).
2. In Cursor's Agent chat, say: **"Open LinkedIn in the browser so I can log in."** (Or just open LinkedIn yourself in that dedicated Chrome window.)
3. The agent calls `browser_navigate` to `https://www.linkedin.com`, and the page opens in the dedicated Chrome.
4. **Log into LinkedIn manually** - your email, password, 2FA, any "verify it's you" prompt.
5. Once you're signed in (you see your feed / home page), tell the agent: **"I'm logged in."**
6. Done. The session is saved to the dedicated profile and reused on every future scrape (as long as that profile exists and you're logged in).

### Where the login is stored

The dedicated Chrome profile lives at `~/.csm-outreach/chrome-profile` (macOS/Linux) or `%USERPROFILE%\.csm-outreach\chrome-profile` (Windows). It's separate from your daily Chrome profile. It persists across runs. Delete that directory to clear the login if you ever want to.

> **One browser at a time:** the CDP hybrid connects to a single Chrome on port 9222, and the dedicated profile can only be used by one Chrome instance at a time. Don't run two scrape/enrichment sessions simultaneously - the second will fail to connect. Run one at a time. (If you switch to the simple-Chromium fallback, Playwright MCP keeps a persistent profile per project instead: macOS `~/Library/Caches/ms-playwright/mcp-chromium-{workspace-hash}`, Windows `%USERPROFILE%\AppData\Local\ms-playwright\mcp-chromium-{workspace-hash}`, Linux `~/.cache/ms-playwright/mcp-chromium-{workspace-hash}`.)

---

## 4. Troubleshooting

- **The playwright server isn't in the MCP marketplace.** Correct - it isn't a marketplace listing. Use the project's `.cursor/mcp.json` (open the project folder and it appears in Settings -> Tools & MCP), or the **one-click install button** at https://github.com/microsoft/playwright-mcp (Cursor section), or add it manually (Settings -> Tools & MCP -> Add new MCP Server -> Name `playwright`, Type `command`, Command `npx -y @playwright/mcp@latest`).
- **No `browser_*` tools show up.** Make sure you're in Cursor's **Agent** mode (not Chat). Confirm the playwright server is green in Settings -> Tools & MCP. **Restart Cursor** if it was just added - MCP servers load at startup, not on file save. Verify `node --version` is 18+.
- **Server shows red / "command not found" / won't connect (the #1 cause).** Cursor launched from the Dock/Applications does **not** inherit your shell PATH, so it can't find `npx` - even though your terminal can. This is especially common when Node was installed via Homebrew (`/opt/homebrew/bin`), nvm, fnm, or asdf. Fix: use the **absolute path** to npx. Run `which npx` in a terminal, then set that full path as `command` in the MCP config. For example, on Apple-silicon Homebrew: `"command": "/opt/homebrew/bin/npx"`. Put this in your **global** `~/.cursor/mcp.json` (user-specific, not committed) so it applies everywhere without touching the repo's generic config. Alternatively, launch Cursor from the terminal so it inherits your PATH.
- **`-y` flag missing -> server hangs forever.** Cursor launches `npx` non-interactively; without `-y`, npx waits for an install confirmation that never arrives. The shipped config already includes `-y` (`["-y", "@playwright/mcp@latest"]`) - keep it.
- **Server shows red / connection timeout (CDP hybrid).** Playwright MCP can't reach the dedicated Chrome on 127.0.0.1:9222. Make sure you ran `launch-chrome.command` / `.bat` / `.sh` and that a separate Chrome window opened. Then toggle the server off/on in Settings -> Tools & MCP, or restart Cursor. Confirm nothing else is using port 9222. (If you see `ECONNREFUSED ::1:9222`, the config is using `localhost` instead of `127.0.0.1` - use `127.0.0.1`, since Chrome listens on IPv4 only.)
- **`npx` fails / can't download.** Check Node is installed and on PATH. If you're behind a corporate proxy, set `HTTPS_PROXY` before launching Cursor. Alternatively run the server via Docker: in `.cursor/mcp.json` use `"command": "docker", "args": ["run", "-i", "--rm", "--init", "--pull=always", "mcr.microsoft.com/playwright/mcp"]` (note: Docker image is headless chromium only - not the CDP hybrid).
- **Login doesn't persist.** With the CDP hybrid the login lives in the dedicated profile at `~/.csm-outreach/chrome-profile`. It persists as long as that profile exists and you stay logged into LinkedIn in that dedicated Chrome. Don't delete that directory between runs. (If you switched to the simple-Chromium fallback, confirm you're not passing `--isolated` in the args - the shipped config doesn't.)
- **LinkedIn shows a login wall mid-scrape.** The skill stops and asks you to log in again. Re-open LinkedIn in the dedicated debug Chrome, log in, then tell the agent to continue.
- **CAPTCHA appears.** The skill saves what it has so far and stops. Solve the CAPTCHA in the dedicated Chrome window, then continue.

---

## Optional: other real-Chrome options

The CDP-to-real-Chrome hybrid above is this project's default and recommended path. If it doesn't work for you, two community alternatives also drive your real logged-in Chrome:

- **Playwright MCP Chrome Extension** (Microsoft) - connects Playwright MCP to your existing Chrome tabs. See https://github.com/microsoft/playwright/tree/main/packages/extension.
- **AgentLimb** - a Chrome extension + local daemon that lets Cursor drive your real Chrome. See https://github.com/hooosberg/AgentLimb.

These are optional. If you use one, the skills' `browser_*` calls may need remapping to that tool's API. The CDP hybrid gives you the same real-Chrome benefit using the official Playwright MCP, with no skill changes.
