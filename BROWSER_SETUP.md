# Browser tool setup (Playwright MCP) + LinkedIn login

The scraper and enrichment skills drive a real, logged-in browser via **Playwright MCP** - Microsoft's official browser-automation MCP server, connected to Cursor. This guide installs it and gets you logged into LinkedIn once. After that, the login persists across runs.

> Why this and not Cursor's built-in browser: Cursor used to ship a built-in browser tool but removed it for security reasons. Cursor's staff recommend Microsoft's official Playwright MCP as the replacement, and it keeps a **persistent profile** so your LinkedIn login sticks between sessions. Cursor's built-in "Browser Tab" doesn't keep a persistent logged-in profile and isn't suitable for this scraping flow.

---

## 1. Install Node.js 18+ (one time)

Playwright MCP runs through `npx`, which needs Node.js 18 or newer.

- Check: `node --version` (or `node -v`). If it prints `v18` or higher, skip to step 2.
- If missing, install the **LTS** version from https://nodejs.org (the LTS installer is fine on macOS and Windows).

## 2. Enable the Playwright MCP server in Cursor

This repo ships `.cursor/mcp.json` already configured:

```json
{
  "mcpServers": {
    "playwright": { "command": "npx", "args": ["-y", "@playwright/mcp@latest"] }
  }
}
```

So in most cases you don't need to type any config:

1. Open the project folder in Cursor. Cursor detects `.cursor/mcp.json`.
2. Open **Cursor Settings -> Tools & MCP** (or run the **MCP: List Servers** command from the command palette).
3. You should see a **playwright** server. Click **Enable** / toggle it on.
4. The first time it starts, `npx` downloads `@playwright/mcp` (a one-time download; needs Node 18+). Wait for it to finish.
5. The server should show as **green / connected**.

### Manual install (if `.cursor/mcp.json` isn't picked up)

In **Cursor Settings -> MCP -> Add new MCP Server**:
- Name: `playwright`
- Type: `command`
- Command: `npx -y @playwright/mcp@latest`

Or install via the one-click button on the Playwright MCP README: https://github.com/microsoft/playwright-mcp (the "Cursor" section).

### Verify it works

In Cursor's Agent chat, ask: *"Open https://example.com and tell me the page title."* The agent should call `browser_navigate` and `browser_evaluate`, a Chrome window opens, and it reports the title. If that works, the browser tool is live.

---

## 3. Log into LinkedIn (one time)

The skills can't read LinkedIn without a logged-in session. You only do this once - Playwright MCP's persistent profile remembers it.

1. In Cursor's Agent chat, say: **"Open LinkedIn in the browser so I can log in."**
2. The agent calls `browser_navigate` to `https://www.linkedin.com`, and a Chrome window opens.
3. In that Chrome window, **log into LinkedIn manually** - your email, password, 2FA, any "verify it's you" prompt.
4. Once you're signed in (you see your feed / home page), tell the agent: **"I'm logged in."**
5. Done. The session is saved to the persistent profile and reused on every future scrape.

### Where the login is stored

Playwright MCP keeps a persistent profile per project:
- **macOS:** `~/Library/Caches/ms-playwright/mcp-chromium-{workspace-hash}`
- **Windows:** `%USERPROFILE%\AppData\Local\ms-playwright\mcp-chromium-{workspace-hash}`
- **Linux:** `~/.cache/ms-playwright/mcp-chromium-{workspace-hash}`

`{workspace-hash}` is derived from the project folder, so each project gets its own profile. You can delete that directory to clear the login if you ever want to.

> **One profile at a time:** a persistent profile can only be used by one browser instance at a time. Don't run two scrape/enrichment sessions against the same project simultaneously - the second will fail to connect. Run one at a time.

---

## 4. Troubleshooting

- **No `browser_*` tools show up.** Make sure you're in Cursor's **Agent** mode (not Chat). Confirm the playwright server is green in Settings -> Tools & MCP. Restart Cursor if it was just added. Verify `node --version` is 18+.
- **`npx` fails / can't download.** Check Node is installed and on PATH. If you're behind a corporate proxy, set `HTTPS_PROXY` before launching Cursor. Alternatively run the server via Docker: in `.cursor/mcp.json` use `"command": "docker", "args": ["run", "-i", "--rm", "--init", "--pull=always", "mcr.microsoft.com/playwright/mcp"]` (note: Docker image is headless chromium only).
- **Login doesn't persist.** Confirm you're not passing `--isolated` in the args (the shipped config doesn't). The persistent profile is the default. If you have multiple Cursor windows open on the same project, only one can hold the profile - close the others.
- **LinkedIn shows a login wall mid-scrape.** The skill stops and asks you to log in again. Re-open LinkedIn in the Playwright MCP browser (step 3 above), log in, then tell the agent to continue.
- **CAPTCHA appears.** The skill saves what it has so far and stops. Solve the CAPTCHA in the browser window, then continue.

---

## Optional: use your real Chrome instead

If you'd rather the agent drive the Chrome you're already logged into (with all your existing cookies), instead of a separate Playwright profile, two community options exist:

- **Playwright MCP Chrome Extension** (Microsoft) - connects Playwright MCP to your existing Chrome tabs. See https://github.com/microsoft/playwright/tree/main/packages/extension.
- **AgentLimb** - a Chrome extension + local daemon that lets Cursor drive your real Chrome. See https://github.com/hooosberg/AgentLimb.

These are optional. The default Playwright MCP setup above (a separate persistent profile) is the recommended, officially-supported path and is all most users need.
