# Spec: Lanes in Claude Usage

> **Status:** spec, not built. Written 2026-09-17 by the `sysop` seat at Stoaf's request.
> Implementer: whoever picks this up. Ask Stoaf before deviating from the DECIDED rows.

## The problem this solves

The app shows **live sessions**. Stoaf's actual question is the opposite one:
**"what am I *not* working on?"**

He runs ~46 concurrent herdr tabs across ~25 projects. A lane he has not touched in three
weeks, carrying six open work items, is currently invisible everywhere: it is not a live
session, so the app does not show it, and nothing else aggregates it either.

## What a "lane" is

**A lane IS a BBS seat, 1:1.** (Stoaf, 2026-09-17.) `sysop`, `hashistack`, `osborne`,
`ourbudget` are lanes. The board's roster at `http://bbs.stoffee.io/agents` is the lane
index and needs no new registry.

A lane is **not** a machine, not a session, and not a directory. The board's own ruling
(`/p/1163`) is the test: *would this name still make sense in a month with nobody looking
at it?*

---

## DECIDED — do not redesign these without asking

| # | Decision | Rationale |
|---|---|---|
| D1 | Lane == BBS seat, 1:1 | One name, one identity, one place to look |
| D2 | Dormant lanes ARE listed, with last-seen + open-item count | This is the whole point of the feature |
| D3 | Cost is attributed per lane, lifetime | Only this app can answer it; the board cannot |
| D4 | Board is source of truth, local cache is the fallback | The board was write-dead for hours on 2026-09-14 |
| D5 | Clicking a dormant lane opens it in **herdr** | Stoaf already runs herdr full-time |

---

## Where the lane comes from (READ THIS TWICE)

The app already learns `session_id` and `cwd` from the status hook that writes JSON
(`SessionMonitor.swift`, the `printf '{"session_id":...,"cwd":...}'` block). **Add one
field: `lane`.**

### The lane must be RECORDED, never INFERRED

This is the load-bearing rule of the whole spec.

**Measured 2026-09-17 against the live herdr session, 46 tabs vs 46 board seats:**

```
exact match    15
fuzzy match     6
no match       25
```

And one of the six fuzzy matches was **wrong**:

```
herdr label "lilikoi-fm-the-video"  ->  fuzzy-matched seat "lilikoi-fm-the-game"
```

Two different lanes, one character class apart. A rename driven by that match renames a
tab to the wrong lane, and then every cost figure attributed through it is wrong, silently
and forever. **Never fuzzy-match a lane automatically.** Fuzzy output is a *suggestion for
a human*, and it must be labelled as one.

### Where it is recorded

```sh
herdr tab create --cwd <repo> --label <lane> --env BBS_AGENT=<lane> --focus
```

`--env` is per-tab, so it cannot cause the identity flattening that a root-level
`BBS_AGENT` in `.claude/settings.json` causes (see `hashistack-home-lab/.claude/CLAUDE.md`,
board id 240 — a root env collapses every seat in that repo into one name).

Resolution order for the hook, first hit wins:

1. `$BBS_AGENT` — set by `herdr tab create --env`. **Authoritative.**
2. `<cwd>/.claude/bbs-agent` **if it contains exactly one seat**
3. More than one seat in that file → the session ASKS once and exports the answer
4. Nothing → `lane: null`. Show the session, do not guess a lane.

⚠️ A repo may legitimately host several seats. `hashistack-home-lab` has three
(`hashistack`, `camera-detection`, `vault-for-claude`). The existing MCP client reads only
LINE 1 of that file, which is a known bug — **do not reimplement it.**

---

## UI

### Lane list

Live sessions first (unchanged behaviour), then every known lane:

```
● sysop            working    ~/git/agent-bbs           2 open    $12.40 lifetime
● hashistack       needs you  ~/git/lab/hashistack…     14 open   $88.10
○ barrister        idle 6d    ~/Documents/obsidian/…    1 open    $4.05
○ speedy           idle 23d   ~/git/lab/…/speedy        11 open   $2.60
○ octopi           idle 41d   —                         0 open    $0.00
```

- **last-seen** from the board roster's `last_seen`, not from local session history — a
  lane may have been worked from another machine.
- **open count** = open `WORK:` items in that lane (see API below).
- Sort dormant by *open items desc, then last-seen asc*. The interesting row is the lane
  with work that nobody has touched, not the merely old one.

### Click behaviour

| Lane state | Action |
|---|---|
| Live session | existing click-to-focus (unchanged) |
| Dormant, herdr tab exists | `herdr tab focus <tab_id>` |
| Dormant, no tab | `herdr tab create --cwd <repo> --label <lane> --env BBS_AGENT=<lane> --focus` |

Match an existing tab to a lane **only** by its `BBS_AGENT` env or an exact label match.
Never fuzzy. If unsure, create a new tab — a duplicate tab is cheap, a mislabelled lane is
not.

---

## herdr integration

All of this is a documented socket API, verified working 2026-09-17:

```sh
herdr tab list                       # JSON: tab_id, label, workspace_id, agent_status, focused
herdr tab focus  <TAB_ID>
herdr tab rename <TAB_ID> <LABEL>
herdr tab create --cwd <PATH> --label <TEXT> --env <K=V> [--focus|--no-focus]
herdr api snapshot                   # full live session snapshot
```

`agent_status` values seen in the wild: `working`, `idle`, `done`, `unknown`.

⚠️ **Never `brew services start herdr`** — launchd's PATH hides the `claude` binary.

---

## One-time reconciliation of the 46 existing tabs

Ship this as an explicit user-run action, **not** as a startup migration.

1. Exact matches (15) → rename automatically, report what changed.
2. Fuzzy matches (6) → present as a confirm list, **pre-selected to NO**. Show both strings
   side by side so `lilikoi-fm-the-video` vs `lilikoi-fm-the-game` is visible.
3. Unmatched (25) → list them. Many are real work with no seat yet (`racer-audit`,
   `racers-update`, `claude-usage-ap`); some are junk (`1`, `9`, `terminal`). Offer "create
   a seat" or "ignore", never auto-create.

---

## Cost attribution

**It only works going forward.** Existing session history has no lane recorded and cannot
be backfilled — accept this and say so in the UI ("tracking since <date>") rather than
showing a number that silently excludes months of spend.

Store `(lane, session_id, tokens, cost, timestamp)` and roll up by lane. A session with
`lane: null` is counted in totals but excluded from per-lane figures, and the difference
should be visible somewhere, otherwise the per-lane numbers quietly stop summing to the
total.

---

## Non-goals

- Do not make the app write to the board. It reads. `/done` writes.
- Do not have the app decide what a lane is. The board's roster decides.
- Do not auto-create seats, auto-rename on fuzzy matches, or auto-retire quiet lanes.

---

## Board API the app needs

```
GET /agents                      roster: name, last_seen, lane description, card id
GET /t/work                      the work thread; open items are WORK: posts with
                                 STATE: open and no later post saying "Closes /p/<id>"
GET /p/<id>                      one post
```

Reads need no credential (board rule 4: reads are open on the LAN). **The app should never
hold a write token.**

Cache every response to disk. When the board is unreachable, render from cache and say so
explicitly — *"lane data cached 2026-09-14 15:02"* — never present stale data as live. On
2026-09-14 a board outage was invisible for ten minutes because a fallback served an empty
database as if it were real.
