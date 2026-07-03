# CSM Outreach Dashboard (Cursor edition)

A complete local job-outreach system for Customer Success Manager roles (retargetable to any title). Two Cursor agent skills scrape LinkedIn and enrich every job with contacts, personalized DMs, and a cover letter. A local web dashboard gives you a clean view of everything - search, filter, track outreach status, copy messages, and find executive emails - all from one page. Everything lives in **one CSV** on your machine; nothing is uploaded anywhere.

This is the **Cursor** edition. It uses [Playwright MCP](https://github.com/microsoft/playwright-mcp) (Microsoft's official browser-automation server) to drive a logged-in LinkedIn session, and Cursor's native skills/rules system. No Claude subscription or paid tools required - you can run the whole thing on Cursor's free tier.

---

## Quick start (with Cursor)

You don't need to do anything manually. Clone the repo, open it in Cursor, and tell the agent:

> **Set up https://github.com/Sesamsesam/csm-outreach-dashboard-cursor for me**

The agent will:
1. Check and install prerequisites (Python, Flask, Node.js for the browser tool).
2. Connect the **Playwright MCP** browser server (already wired in `.cursor/mcp.json`) and walk you through enabling it.
3. Create your empty `csm_jobs.csv` from `schema.py`.
4. Open LinkedIn in the browser so you can log in (one time - the session persists).
5. Save your name/email for cover letters.
6. Start the dashboard at **http://localhost:5001**.

The two skills auto-load from `.cursor/skills/` - no install step. After setup, just say **"run my daily job search"** and the agent scrapes LinkedIn and enriches the new rows in one flow.

> **Not a video person?** The agent guides you through every install step in chat, including the browser tool. You don't need to follow a separate tutorial. See [`BROWSER_SETUP.md`](BROWSER_SETUP.md) if you'd rather do the browser-tool install yourself.

---

## What's included

- **Two Cursor agent skills** - one scrapes LinkedIn job postings (17 fields per job, with blocklists and sponsorship detection), the other enriches them with up to 4 contacts, tier-specific DMs, and a formal cover letter.
- **Playwright MCP browser integration** - the official, Microsoft-maintained browser server, pre-wired in `.cursor/mcp.json`, with a persistent profile that keeps your LinkedIn login.
- **Local web dashboard** - a Flask app with tab navigation, full-text search, a live settings panel, outreach status tracking, DM/cover-letter copy buttons, and Hunter.io executive email lookup.
- **23+ configurable settings** - change the role, location, seniority, tone, contact types, or any other knob by asking the agent in plain language. All settings live in one file and take effect on the next run.
- **One local data file** - `csm_jobs.csv`. No cloud, no database, no accounts.

## How the pieces fit together

```
        +---------------------+        +--------------------------+
        |  Skill 1: SCRAPER   |        |  Skill 2: ENRICHMENT     |
        |  LinkedIn -> new    |        |  fills contacts, DMs,    |
        |  rows (17 fields    |        |  cover letters for any   |
        |  per job)           |        |  row not yet enriched    |
        +----------+----------+        +-------------+------------+
                   |  appends new rows               |  updates rows in place
                   |                                 |
                   |  -- auto-triggers ---------->   |
                   v                                 v
              +---------------------------------------------+
              |      csm_jobs.csv   (THE one data file)     |
              |   38 columns defined once in schema.py       |
              +-----------------------+---------------------+
                                      |  reads
                                      v
                          +----------------------+
                          |  Dashboard (Flask)   |
                          |  localhost:5001      |
                          +----------------------+

          Both skills drive the browser via:
                          +----------------------+
                          |  Playwright MCP      |
                          |  (persistent login)  |
                          +----------------------+
```

There is **exactly one data file: `csm_jobs.csv`.** The scraper appends new rows to it, the enrichment skill updates existing rows in it, and the dashboard reads from it. The column layout is defined in a single place - `schema.py` - so the two skills and the dashboard can never drift out of sync.

**Data safety:** the skills' helper scripts physically refuse to write to any file not named `csm_jobs.csv`, deduplicate by `job_id`, and preserve the existing header. An agent can't accidentally create a second tracker or reshape the schema.

## What the scraper actually does

For each posting it extracts **17 fields**: job title, company, salary, location, applicant count, Easy Apply status, company tagline, industry, HQ location, company size, company website, LinkedIn URLs (job + company), key requirements, hard requirements, years of experience, and work authorization.

It also:
- **Filters out aggregators and recruiters** using a configurable blocklist.
- **Detects sponsorship status** - scans job descriptions against configurable phrases to flag jobs that explicitly won't sponsor. Jobs silent on sponsorship are kept.
- **Parses hard requirements** - distinguishes documentation-gated requirements (degree field, license, clearance) from soft items like years of experience.
- **Deduplicates** against a seen-job-IDs cache so re-runs never produce duplicate rows.
- **Auto-triggers enrichment** when it finishes - you don't have to run two separate commands.

## What the enrichment skill actually does

Enrichment runs a **4-tier contact search** for every un-enriched job, each tier using different LinkedIn People-tab parameters:

| Tier | Who | How it searches |
|------|-----|-----------------|
| **Contact 1** | Recruiter | People tab filtered by recruiter function code |
| **Contact 2** | Hiring Manager | CS Director/Sr. Director - adapts keywords based on company size |
| **Contact 3** | Peer | Same-function IC on the same segment team (Strategic, Enterprise, Commercial, SMB) |
| **Contact 4** | Senior Business Leader | Found via hiring manager's "More profiles for you" section, with fallback to company People tab |

For each contact it drafts a **personalized DM** (under 300 characters) using tier-specific templates and a configurable tone, then generates a **formal cover letter** (~350 words) using your name and email, saved to `cover_letters/{job_id}_{company_slug}.txt`.

If enrichment finds **zero** usable contacts for a job, it treats that company as low-signal and removes the row (configurable). The job ID stays in the seen cache so the scraper won't re-add it.

## The dashboard

Navigation and filtering, job cards (grid view), a job detail page with color-coded contact tiers, copy buttons for DMs and cover letters, an outreach status dropdown with real-time save, a self-updating "Current search settings" panel, and Hunter.io executive email lookup with confidence scores and credit caching. All reading from the one CSV.

## Prerequisites

- **Cursor** installed (the skills run inside it). Free tier works.
- **Playwright MCP** (Microsoft's official browser server) - pre-wired in `.cursor/mcp.json`; the agent walks you through enabling it. See [`BROWSER_SETUP.md`](BROWSER_SETUP.md). Needs **Node.js 18+**.
- **A logged-in LinkedIn session** in the Playwright MCP browser. The agent opens LinkedIn for you; you log in once and it persists.
- **Python 3** and **Flask** (one `pip` install) for the dashboard.

## Usage

1. Say **"run my daily job search"** - the scraper finds new postings and enrichment runs automatically after.
2. Open the dashboard at **http://localhost:5001** to review what was found.
3. Use the **tab cards** to filter by outreach status (Ready to Send, Pending Agent, DMs Sent, Replies, Applied, Archived).
4. Click any job card to see the full detail page - contacts with DMs, cover letter, company info, and outreach status.
5. **Copy DMs** with one click, update the outreach status as you go.
6. Optional: paste a Hunter.io API key in the dashboard to find executive emails with confidence scores.

## Customizing for a different role

This project ships tuned for **Customer Success Manager** roles, but the skills are built to be retargeted to any title. To track a different role - say Product Manager, Account Executive, or Data Analyst - **just ask the agent**, e.g.:

> "Change these skills to track Account Executive jobs instead of CSM."

You can also change individual settings in plain language:

> "Search United Kingdom instead of US" / "Show me hybrid jobs too" / "Make the DMs more formal" / "Only show me senior roles" / "Don't delete jobs with no contacts"

The agent confirms what you mean, makes the change in `search_config.json`, and tells you what it did. All changes take effect on the next run - no reinstall needed. For the full config reference, see [`RETARGETING.md`](RETARGETING.md).

## Running it automatically (scheduling)

A daily scrape runs **on your machine** (it drives your logged-in browser and writes your local CSV):

- **On-demand (simplest).** Open the project and say **"run my daily job search"**.
- **Cursor Automation (recurring).** A Cursor Automation can fire the same prompt on a schedule; the persistent Playwright MCP profile stays logged in.

**Requirements either way:** a logged-in LinkedIn session, the machine awake, and someone available if LinkedIn shows a login wall or CAPTCHA (the skills stop and ask).

## Hunter.io (optional)

Sign up free at [hunter.io](https://hunter.io) - 25 domain searches/month on the free plan. Enter your API key in the dashboard under any job's Hunter sidebar. The key saves locally to `dashboard/.hunter_key` and is never committed. Results are cached in the CSV so you only spend one credit per company.

## Privacy / what gets pushed

Your data never goes to GitHub. The `.gitignore` excludes `csm_jobs.csv`, `seen_job_ids.txt`, `user_profile.txt`, `search_config.json`, `setup_complete.json`, your cover letters, and your API keys. Only the **framework** is shared. When someone clones the repo they get an empty, ready-to-use project.

## File structure

```
.
├── schema.py                 <- single source of truth for the 38 CSV columns
├── csm_jobs.csv              <- your ONE data file (gitignored, created from schema.py)
├── AGENTS.md                 <- guidance for the Cursor agent
├── RETARGETING.md            <- how to change/add search settings (full config reference)
├── BROWSER_SETUP.md          <- how to install Playwright MCP + log into LinkedIn
├── search_config.example.json <- shipped default settings (CSM)
├── search_config.json        <- your live settings (gitignored; skills load this)
├── seen_job_ids.txt          <- scraper de-dup cache (gitignored)
├── user_profile.txt          <- your name/email for cover letters (gitignored)
├── setup_complete.json       <- per-machine setup marker (gitignored)
├── cover_letters/            <- generated cover letters (gitignored)
├── .cursor/
│   ├── mcp.json              <- pre-wires the Playwright MCP browser server
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

## How this edition differs from the Claude edition

This Cursor edition is a clean, Cursor-native port. It drops the Claude/Cowork-specific pieces (the Cowork plugin, the shared-folder install-path logic, `CLAUDE.md`) and replaces them with Cursor's own systems: `.cursor/skills/`, `.cursor/rules/*.mdc`, `.cursor/mcp.json`, and `AGENTS.md`. The browser tool is Playwright MCP instead of Claude Code's built-in browser. Everything else - the single-CSV architecture, the schema, the dashboard, the targeting config, the retargeting flow - is identical and runs the same way.
