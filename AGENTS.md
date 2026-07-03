# CSM Outreach Dashboard - Guide for Cursor

## Read me first - house rules

**Any agent working in this project must follow the six rules in `.cursor/rules/project-setup.mdc` (always applied).** They exist because inconsistency (re-running setup, making a second data file, hard-coding role values into skills) is the main thing that breaks this project. Read that file first; the rules there win when in doubt.

Quick summary: setup is once; one data file (`csm_jobs.csv`); targeting lives in `search_config.json`; retargeting is forward-only; recognize casual settings changes; the browser tool is Playwright MCP connected to a dedicated real-Chrome instance over CDP (127.0.0.1:9222) for low detection risk.

> **FORMATTING RULE - NO EM DASHES:** Never use em dashes (--) anywhere - not in DMs, cover letters, reports, summaries, or any other output. Always use a regular hyphen (-) instead. This rule applies across all skills and all generated text, without exception.

This is a LinkedIn job-outreach tracker with a local web dashboard, two Cursor agent skills (scrape + enrich), and optional Hunter.io email lookup. It ships tuned for **Customer Success Manager** roles but is built to be retargeted to any job title.

## The browser tool: Playwright MCP (CDP-to-real-Chrome hybrid)

The skills drive a real, logged-in browser through **Playwright MCP** - Microsoft's official browser-automation MCP server. To keep LinkedIn from flagging the session as automation, this project wires Playwright MCP to **a separate instance of your real Chrome over CDP** (`--cdp-endpoint http://127.0.0.1:9222`) instead of letting it launch its own detectable Chromium. The agent then drives your genuine Chrome binary - real plugins, real WebGL, real TLS, no `navigator.webdriver` - instead of a Playwright fingerprint. This is the single biggest detection-risk reduction available without leaving the official tool.

> **Why a dedicated profile (not your daily Chrome):** Chrome refuses remote debugging on your default profile (a security measure), so the helper launches a **separate Chrome instance with its own profile** (`~/.csm-outreach/chrome-profile`), running alongside your normal Chrome - your normal Chrome is not quit or touched. The user logs into LinkedIn once in that dedicated profile; it persists.

`.cursor/mcp.json` is pre-wired for it (note `127.0.0.1`, not `localhost` - Chrome listens on IPv4 and Playwright resolves `localhost` to IPv6, which would refuse):

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

For this to connect, **a dedicated Chrome instance must be running with `--remote-debugging-port=9222 --user-data-dir=~/.csm-outreach/chrome-profile`**. Ship helper scripts for that: `launch-chrome.command` (macOS, double-click it), `launch-chrome.bat` (Windows), `launch-chrome.sh` (Linux). They open a separate Chrome window with the debug port - your normal Chrome is left alone. The user logs into LinkedIn once in that dedicated Chrome; the session persists in that profile.

When the server connects, the agent gets `browser_*` tools (`browser_navigate`, `browser_evaluate`, `browser_snapshot`, `browser_take_screenshot`, `browser_click`, `browser_type`, `browser_wait_for`, etc.). The skills use these. Full install/login instructions are in `BROWSER_SETUP.md`.

> **Fallback (simple Playwright Chromium).** If the user can't or won't run the debug-Chrome helper, remove `--cdp-endpoint`, `http://127.0.0.1:9222` from `.cursor/mcp.json`. Playwright MCP then launches its own Chromium with a persistent profile (macOS: `~/Library/Caches/ms-playwright/mcp-chromium-{workspace-hash}`). This still works but exposes Playwright's automation fingerprint (`navigator.webdriver = true`, SwiftShader, empty plugins) - higher detection risk on LinkedIn. Use only if the CDP hybrid isn't possible.

If the `browser_*` tools are not available during a run, the skills will detect it and tell the user to run the browser-tool setup (Step 2 below / `BROWSER_SETUP.md`) before continuing.

---

## "Set this up" trigger

If the user says anything like "set this up", "get me started", "initialize this", or "install this" - run the setup steps below in order. This is the intended onboarding phrase for new users. The user may be non-technical - do not tell them to open a terminal or run commands themselves. Run everything you can yourself; only ask them to take a physical action when a step requires it (clicking a button in a dialog, logging into LinkedIn, approving an MCP server).

Many users will reach this trigger by **pasting the repo URL into a fresh Cursor Agent chat before they've created any folder or workspace** - e.g. "set up https://github.com/Sesamsesam/csm-outreach-dashboard-cursor for me". That's the expected first-time entry point. Step 0 below handles getting the project onto their machine and open as the workspace; the rest of setup then runs inside it.

## Step 0 - Get the project onto the machine (run first, before checking setup state)

Decide whether the project is already open on disk:

1. **Are we already inside the project?** Check for `schema.py` in the current workspace root. If it's there, the project is already cloned and open - skip to **FIRST: check if setup is already complete** below.
2. **If not, and the user gave a GitHub URL** (e.g. `https://github.com/Sesamsesam/csm-outreach-dashboard-cursor`), clone it for them:
   - **Check `git` is installed:** `git --version 2>/dev/null`. If missing, install it (macOS: it'll prompt to install Command Line Tools; Windows: `winget install Git.Git` or tell them to install from https://git-scm.com/download/win).
   - **Pick a generic default location** - never a user-specific path. Use `~/Documents/csm-outreach-dashboard-cursor` (that's `$HOME/Documents/...` on macOS/Linux, `%USERPROFILE%\Documents\...` on Windows). Tell the user: "I'll put the project in your Documents folder. Say the word if you'd prefer somewhere else." If they name a different folder, use it. Create the parent directory if it doesn't exist (`mkdir -p`).
   - **Clone:** `git clone https://github.com/Sesamsesam/csm-outreach-dashboard-cursor "<chosen path>"`. If the target folder already exists and isn't empty, stop and ask the user how to proceed rather than overwriting.
   - **Open it as the workspace.** Use the `move_agent_to_root` tool to move this conversation's root to the cloned folder, so all subsequent steps run in-project. (If that tool isn't available, tell the user: "Open the folder I just cloned in Cursor - File -> Open Folder -> `<chosen path>` - then say 'continue'.") 
3. **After the project is open as the workspace root, the Playwright MCP server (`.cursor/mcp.json`) needs to register.** Cursor loads MCP servers at startup from the workspace root, so tell the user: **"Restart Cursor once so the playwright browser server loads, then come back and say 'continue'."** This only matters on the very first setup - after the restart, the `browser_*` tools will be available for Step 2.

Once the project is on disk and open as the workspace root, continue to **FIRST: check if setup is already complete**.

## FIRST: check if setup is already complete

**Before running ANY setup step, check for a `setup_complete.json` file in the project root.**

- **If it exists** -> setup has already been completed on this machine. **Do NOT re-run the setup steps.** Read the file, then tell the user something like: "This project was already set up on `{timestamp}`, so I'll skip setup." Then go straight to next actions: offer to run a scrape, enrich, or open the dashboard (http://localhost:5001). The one thing to still verify is that the Playwright MCP browser tool is connected (Step 2) - if `browser_*` tools are available, you're good; if not, walk the user through Step 2 only.
- **If it does NOT exist** -> this is a fresh setup. Run the setup steps below in order. The file is gitignored, so a fresh clone from GitHub will never have it - which is correct: a new user's machine genuinely needs setup. Every individual step is idempotent (check-then-act), so even a re-run is safe.
- **Write the marker only at the very END of a fully successful setup.** Create `setup_complete.json` with: `timestamp` (ISO 8601), `install_path`, and a `steps_completed` array. Writing it only on full success means "file exists = setup fully done"; a setup that dies partway leaves no marker, so the next run correctly resumes.

## When a new user opens this project

Run these steps **in order** to get them going. The user may be non-technical - run everything yourself and only involve them when a step needs a physical action.

### Step 1 - Check prerequisites (run silently, install what's missing)

Detect the OS:
```bash
uname -s 2>/dev/null || echo "Windows"
```
- `Darwin` -> macOS. Follow the **macOS** path below.
- `Windows` or `uname` fails -> Windows. Follow the **Windows** path below.
- `Linux` -> Follow the macOS path (skip Xcode/Homebrew; use `apt`/`dnf`).

Run each check yourself. If something is missing, install it. Only involve the user if a step needs their physical action.

#### macOS prerequisites
- **Python 3**: `python3 --version 2>/dev/null && echo OK || echo MISSING` -> if missing, install from python.org (tell the user to click through the installer) or via Homebrew if present.
- **pip3**: `pip3 --version 2>/dev/null && echo OK || echo MISSING` -> if missing after Python 3: `python3 -m ensurepip --upgrade`.
- **Flask**: `pip3 show flask >/dev/null 2>&1 && echo OK || echo MISSING` -> if missing: `pip3 install flask`.
- **Node.js 18+** (needed for Playwright MCP - `npx` uses it to run `@playwright/mcp`): check both presence AND version with `node --version 2>/dev/null`. It must print `v18` or higher (e.g. `v20`, `v22`). If missing OR below v18, tell the user to install the **LTS** version from https://nodejs.org (the LTS installer). This is a one-time manual step - do not try to auto-install Node for them. (npx ships with Node, so no separate install.)

#### Windows prerequisites
- **Python 3**: `python --version 2>&1 && echo OK || echo MISSING` (command is `python` on Windows) -> if missing, tell the user to install from https://www.python.org/downloads/ and check "Add Python to PATH".
- **pip**: `pip --version 2>&1 && echo OK || echo MISSING` -> if missing: `python -m ensurepip --upgrade`.
- **Flask**: `pip show flask >NUL 2>&1 && echo OK || echo MISSING` -> if missing: `pip install flask`.
- **Node.js 18+**: check `node --version 2>&1` - must print `v18` or higher. If missing OR below v18, tell the user to install Node 18+ LTS from https://nodejs.org.

Only after ALL prerequisites pass, continue to Step 2. If Node is the only missing piece and the user just wants the dashboard (not scraping), you can proceed with the dashboard and defer the browser-tool step - but flag that scraping/enrichment need Node 18+ before they'll work.

### Step 2 - Connect the browser tool (Playwright MCP over CDP to a dedicated Chrome)

This is the one genuinely new prerequisite vs. a plain Python project, and it's what makes the LinkedIn scrape work. The project uses the **CDP-to-real-Chrome hybrid**: Playwright MCP (Microsoft official) connects to a separate instance of the user's real Chrome over a debug port, so the agent drives a genuine Chrome fingerprint instead of a detectable separate Chromium. This is the biggest LinkedIn-detection-risk reduction available without leaving the official tool.

> **Important: Playwright MCP is NOT in Cursor's MCP marketplace.** If the user says they searched the marketplace (Customize -> MCP market) for "Playwright" or "browser" and found nothing, that is expected - it isn't a marketplace listing. It comes in through the project's `.cursor/mcp.json` (below), the one-click install button at https://github.com/microsoft/playwright-mcp (Cursor section), or Settings -> Tools & MCP -> Add new MCP Server. Tell them not to bother searching the market.

Walk the user through it in this order:

1. **Start the dedicated Chrome with the debug port.** Run the helper for their OS (double-click on macOS, or run from terminal):
   - macOS: `./launch-chrome.command`
   - Windows: `launch-chrome.bat`
   - Linux: `./launch-chrome.sh`
   It opens a **separate Chrome window** with its own profile (`~/.csm-outreach/chrome-profile`) and `--remote-debugging-port=9222`. The user's normal Chrome is untouched. Tell them: **keep this dedicated Chrome running while scraping; close it when done to turn the debug port off.**
   > **First-run OS warning (one-time):** macOS may show "unidentified developer" - bypass via right-click -> Open -> Open (or run from terminal). Windows may show SmartScreen "Windows protected your PC" - click More info -> Run anyway (and unblock the file in Properties if needed). See `BROWSER_SETUP.md` for full details.
2. Tell the user: open **Cursor Settings -> Tools & MCP** (or run the **MCP: List Servers** command). They should see a **playwright** server listed (from `.cursor/mcp.json`, configured with `--cdp-endpoint http://127.0.0.1:9222`).
3. If it's not enabled, have them click **Enable** / toggle it on. Cursor runs `npx -y @playwright/mcp@latest --cdp-endpoint http://127.0.0.1:9222`; the first launch downloads the package (needs Node 18+, checked in Step 1) and connects to the dedicated Chrome.
4. **Restart Cursor** if the server was just added or its args changed - MCP servers load at startup, not on file save.
5. Confirm the server turns **green/connected**. Common failures:
   - **Red / "command not found"** = Cursor can't find `npx` (GUI-launched Cursor doesn't inherit shell PATH; common with Homebrew `/opt/homebrew/bin`, nvm, fnm, asdf). Fix: run `which npx`, put that absolute path as `command` in the user's **global** `~/.cursor/mcp.json` - keep the repo's `.cursor/mcp.json` generic. See `BROWSER_SETUP.md` troubleshooting.
   - **Red / `ECONNREFUSED ::1:9222` or connection timeout** = the dedicated Chrome isn't running on port 9222. Re-run the helper from step 1, then toggle the server off/on or restart Cursor. (If the error mentions `::1`, the config is using `localhost` instead of `127.0.0.1` - use `127.0.0.1`.)
6. Verify from the agent side: call `browser_navigate` to `https://example.com`. It should drive a tab in the **dedicated Chrome window** and report the title. If that works, the CDP hybrid is live.
7. **Log into LinkedIn** (Step 6 below) in that dedicated Chrome - once, since the profile persists.

> **Fallback (simple Playwright Chromium).** If the user can't run the debug-Chrome helper, edit `.cursor/mcp.json` and remove `--cdp-endpoint`, `http://127.0.0.1:9222` from the args. Playwright MCP then launches its own Chromium with a persistent profile. This works but exposes Playwright's automation fingerprint - higher LinkedIn-detection risk. Only use if the CDP hybrid isn't possible.

> Note: Cursor used to ship a built-in browser tool but removed it for security reasons; Cursor staff recommend Microsoft's official Playwright MCP as the replacement, which is what this project uses. Do not suggest the built-in Browser Tab for scraping.

If the user is not going to scrape right now (they only want the dashboard), you can defer this step - but flag that scraping/enrichment need it before they'll work.

### Step 3 - Create the one data file
```bash
python3 schema.py        # macOS/Linux
python schema.py         # Windows
```
This creates an empty `csm_jobs.csv` with the correct columns (from `schema.py`). It will not overwrite an existing file.

### Step 4 - Skills (no install needed)

The two skills live in `.cursor/skills/` and **auto-load** when the project is open in Cursor - nothing to install. The user already has:
- `/linkedin-csm-scraper` - scrapes new LinkedIn postings into `csm_jobs.csv`
- `/linkedin-csm-enrichment` - enriches any row that hasn't been enriched yet

Both are invocable via `/skill-name` in chat, or the agent picks them automatically based on the request.

### Step 5 - Start the dashboard
```bash
bash dashboard/run.sh       # macOS/Linux
dashboard\run.bat            # Windows
# or cross-platform:
python3 dashboard/app.py
```
Then tell the user to open **http://localhost:5001** in their browser.

### Step 6 - Log into LinkedIn (required before scraping/enriching)

The skills can't read LinkedIn without a logged-in session. Because the CDP hybrid uses a **dedicated Chrome profile** (`~/.csm-outreach/chrome-profile`, separate from the user's daily Chrome), the user logs into LinkedIn once in that dedicated profile:
1. Make sure the dedicated debug Chrome is running (run `launch-chrome.command` / `.bat` / `.sh` from Step 2).
2. Ask you to open LinkedIn in that Chrome (you call `browser_navigate` to `https://www.linkedin.com`) - or they just open it themselves in that dedicated Chrome window.
3. The user logs into LinkedIn manually (username, password, 2FA).
4. Once they confirm they're signed in, you're done - the session persists in the dedicated profile across future runs.

If a login wall appears mid-scrape later, the skill stops and asks them to log in (then resumes).

### Step 7 - Save personal details for cover letters

Ask for the user's full name and email, then write `user_profile.txt` in the project root:
```
Name: [their full name]
Email: [their email]
```
This file is gitignored. The enrichment skill reads it for cover-letter signatures so it never has to ask mid-session. If skipped, the enrichment skill will ask the first time it writes a cover letter.

### Step 8 - (Optional) Hunter.io for executive email lookup
- Sign up free at https://hunter.io (25 domain searches/month on the free plan).
- In the dashboard, open any job -> the **Hunter.io** sidebar -> paste the API key.
- The key saves to `dashboard/.hunter_key` (gitignored).

### Step 9 - Write the setup-complete marker (do this LAST, only after every step above succeeded)

Create `setup_complete.json` in the project root so a later session skips setup. Only write it on full success. Example:
```json
{
  "setup_complete": true,
  "set_up_by": "Cursor",
  "timestamp": "2026-07-03T00:00:00Z",
  "install_path": "/absolute/path/to/csm-outreach-dashboard-cursor",
  "steps_completed": ["prerequisites_verified", "playwright_mcp_connected", "csv_created", "linkedin_logged_in", "profile_saved", "dashboard_tested"]
}
```
This file is gitignored, so it never ships in the repo - a fresh clone correctly has no marker and runs setup.

---

## How the two skills work together

1. **Scraper** finds new job postings on LinkedIn and **appends** them as new rows to `csm_jobs.csv` (scraper columns filled, enrichment columns blank). It de-dups by `job_id` using `seen_job_ids.txt`.
2. **Enrichment** scans `csm_jobs.csv` for **any row where all four contact slots are blank** — regardless of `outreach_status` or how long ago it was scraped — and fills in contacts, DMs, and a cover letter. "Enrich anything not yet enriched" is keyed on the data, not the date.
3. If enrichment finds **zero** usable contacts for a job, it **deletes** that row (low-signal company) but keeps the `job_id` in `seen_job_ids.txt` so the scraper won't re-add it.
4. The **dashboard** reads `csm_jobs.csv` and renders everything visually.

The scraper **auto-triggers enrichment** when it finishes (Step 7 of the scraper skill) - you don't run two separate commands. Treat scrape + enrich as one atomic flow.

## Scheduling (the daily automated scrape)

A scheduled scrape needs to drive a **logged-in LinkedIn browser** and write to the **local** `csm_jobs.csv`. That means it runs **on the user's machine**, not in the cloud.

- **On-demand (simplest).** The user opens the project and says *"run my daily job search"* - the agent runs scrape -> enrich in one session (the scraper auto-triggers enrichment). Then *"open the dashboard"* to review.
- **Cursor Automation (recurring).** A Cursor Automation can fire the same "run my daily job search" prompt on a schedule. Because the project lives locally and the Playwright MCP profile stays logged in, the automation can scrape and write the same `csm_jobs.csv`.

**Always required for a scheduled run:** a logged-in LinkedIn session in the Playwright MCP browser, the machine **awake**, and someone available if LinkedIn throws a login wall or CAPTCHA (the skills stop and ask in that case).

## Recognizing a settings change (read this - users speak casually)

**The people using this project did not build it and do not know the config structure.** They will never say "change a knob" or "retarget the scraper." They will say things like the examples below. **Your job is to recognize these as settings changes, confirm what they mean, and then follow `RETARGETING.md`.** Do not run a scrape or enrichment when the user is asking for a settings change.

### How to tell: is this a settings change or a "run" request?

- **Settings change** = the user wants to change *what* gets searched, *where*, *how*, or *what the outreach sounds like*. **Action:** confirm intent in plain language, then follow `RETARGETING.md`.
- **Run request** = the user wants to execute a search or enrichment *with the current settings* ("find new jobs", "run my daily search", "enrich the new rows"). **Action:** run the relevant skill.

If you're unsure, **ask a short clarifying question**: "Just to make sure - do you want me to change your search settings to [X], or run a search with your current settings?"

### Example phrases and what they map to

**Scraper settings** (where/what/when to search - `scraper` block in `search_config.json`):
| User says something like... | Config key to change |
|---|---|
| "Search United Kingdom" / "Look for jobs in London" / "I moved to Germany" | `scraper.location` |
| "Search for Product Manager instead" / "I want Account Executive roles" | `scraper.search_keywords` + `scraper.title_match_phrase` + `role_label` (and enrichment keys too - see "full role change" below) |
| "Only remote" / "Show me hybrid too" / "I don't care about remote" | `scraper.work_type` + `scraper.work_type_label` |
| "Only senior roles" / "Entry level only" / "I have 10 years experience" | `scraper.seniority` + `scraper.seniority_label` |
| "Show me jobs from the last week" / "Not just today's posts" | `scraper.recency` + `scraper.recency_label` |
| "More results" / "Search more pages" | `scraper.pages_to_scrape` |
| "Skip jobs from [company]" / "Block this recruiter" | `scraper.blocklist_companies` |
| "Don't filter out sponsorship jobs" / "I don't need a visa" | `scraper.exclude_work_permit_required` |

**Enrichment settings** (who to contact / how to write - `enrichment` block in `search_config.json`):
| User says something like... | Config key to change |
|---|---|
| "Make the DMs more formal" / "Be less salesy" / "Shorter messages" | `enrichment.dm_tone` |
| "Focus the cover letter on sales" / "Emphasize leadership" | `enrichment.cover_letter_emphasis` |
| "I don't want to reach out to recruiters" / "Add a VP of Sales contact" | `enrichment.contact_tiers` |
| "Don't delete jobs with no contacts" / "Keep everything" | `enrichment.zero_contact_behavior` |

**Full role change** (both blocks need updating together):
If the user changes the *role itself* (e.g. "search for Product Manager instead of CSM"), this touches both the scraper block AND the enrichment block. Update all of these together: `role_label`, `scraper.search_keywords`, `scraper.title_match_phrase`, `enrichment.role_function`, `enrichment.manager_title_keywords`, `enrichment.contact_tiers`, and `enrichment.function_code`. See `RETARGETING.md` Config Reference for details.

---

## Retargeting / changing the job search (procedure)

When you've recognized a settings change (above), **follow [`RETARGETING.md`](RETARGETING.md).** That file is the single entry point.

> **Adding or changing a knob is never a one-off edit you improvise.** A knob can be wired in up to four places (the example config, the skill's Step 0a load table + the step that uses it, this guide's knob reference, and the dashboard panel) - skip one and the config drifts out of sync with what actually runs. `RETARGETING.md` has the exact, ordered checklist plus the drift traps. Use it - do not guess the file list from memory.

**How it works:** all the knobs live in one config file, **`search_config.json`** (project root). Both skills load it at the start of every run and use only its values. The role-specific strings inline in the skills are just defaults; the config always wins. So retargeting = **edit that one file**, and every future run follows the new targeting. The dashboard's "Current search settings" panel reads the same file, so the user always sees what the next run will do.

Files: `search_config.json` is the live, gitignored settings (personal targeting never ships); `search_config.example.json` is the committed Customer Success Manager default and the fallback a fresh clone uses.

Two things that never change when retargeting:
- **Forward-only.** Existing rows in `csm_jobs.csv` are never touched, re-filtered, or deleted to match new targeting - old jobs stay in the dashboard. The change affects future runs only.
- **Still one data file**, and `csm_jobs.csv` is never renamed.

## Notes for the agent

- **"Start the dashboard" / "open localhost":** run `bash dashboard/run.sh` (macOS/Linux) or `python dashboard/app.py` (Windows), then tell the user to open http://localhost:5001.
- **OS detection:** check `sys.platform` / `os.name`. macOS/Linux -> `bash` + `pip3` + `python3`. Windows -> `python` + `pip`.
- **Port:** the dashboard runs on **5001** (macOS reserves 5000 for AirPlay). To change it, set the `PORT` env var or edit the default in `dashboard/app.py`.
- All data stays local - no cloud, no database. Everything is in `csm_jobs.csv`.
- The Hunter.io key lives in `dashboard/.hunter_key` after the user enters it in the UI; no environment variable needed.
- The skills always write to `csm_jobs.csv` in the project root (one level above `dashboard/`).

## File structure

```
.
├── schema.py                 <- single source of truth for CSV columns
├── csm_jobs.csv              <- the ONE data file (gitignored; created via schema.py)
├── AGENTS.md                 <- this file (agent guidance)
├── RETARGETING.md            <- how to change/add search knobs (the retargeting flow)
├── BROWSER_SETUP.md          <- how to install Playwright MCP + log into LinkedIn
├── launch-chrome.command     <- macOS: starts a separate Chrome (dedicated profile + CDP debug port) - double-click
├── launch-chrome.bat         <- Windows: same
├── launch-chrome.sh          <- Linux: same
├── search_config.example.json <- shipped CSM default knobs (committed; the fallback)
├── search_config.json        <- live user knob settings (gitignored; skills load this)
├── seen_job_ids.txt          <- scraper de-dup cache (gitignored)
├── user_profile.txt          <- name/email for cover letters (gitignored)
├── setup_complete.json       <- per-machine setup marker (gitignored)
├── cover_letters/            <- generated cover letters (gitignored)
├── .cursor/
│   ├── mcp.json              <- pre-wires Playwright MCP over CDP to a dedicated Chrome (127.0.0.1:9222)
│   ├── rules/
│   │   └── project-setup.mdc <- always-on house rules
│   └── skills/               <- AUTHORITATIVE skills (auto-load in Cursor)
│       ├── linkedin-csm-scraper/     (SKILL.md + scripts/append_jobs.py)
│       └── linkedin-csm-enrichment/  (SKILL.md + scripts/update_contacts.py)
└── dashboard/
    ├── app.py                <- Flask dashboard (port 5001)
    ├── run.sh / run.bat      <- launchers
    └── .hunter_key           <- Hunter.io API key (gitignored)
```

## CSV columns (defined in schema.py)

| Group | Columns |
|---|---|
| Scraper | job_id, date_scraped, job_title, company, company_tagline, industry, hq_location, company_size, job_location, salary, work_authorization, applicant_count, easy_apply, linkedin_job_url, company_linkedin_url, company_website, key_requirements, hard_requirements, years_experience, outreach_status |
| Enrichment | contact1-4 (name/title/linkedin/dm), cover_letter_path |
| Dashboard | discovered_execs (JSON array of execs found via Hunter.io) |
