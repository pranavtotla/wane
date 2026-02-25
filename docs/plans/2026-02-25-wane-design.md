# Wane — Design Document

**Date:** 2026-02-25
**Status:** Approved
**Summary:** A macOS menu bar app that shows AI coding tool usage as a waning moon.

---

## 1. Overview

Wane is a lightweight macOS status bar app that tracks token usage and quota across AI coding providers. The status bar icon is a moon that wanes as quota depletes. Click to see a popover with provider switching, a star field usage heat map, and summary stats.

### Design Principles

- **Zero config to start** — detects installed CLIs automatically, pre-enables found providers
- **No authentication flows** — piggyback on existing tool credentials (CLI configs, local session files)
- **No dock icon** — `LSUIElement = true`, status bar only
- **Popover, not a window** — click the icon, see details, click away to dismiss
- **Smart refresh** — polls when active, backs off when idle
- **Graceful degradation** — if a provider token expires, that provider dims; everything else keeps working

---

## 2. Status Bar Icon — The Moon

A single 14x14pt moon icon. It displays the phase of the **currently selected provider**.

### Moon Phases

| Phase    | Fill  | Meaning                          |
|----------|-------|----------------------------------|
| Full     | >85%  | Plenty of quota remaining        |
| Gibbous  | 60-85%| Normal usage                     |
| Quarter  | 35-60%| Moderate — worth noticing        |
| Crescent | 10-35%| Getting low                      |
| New      | <10%  | Critical                         |

### Color Progression

The illuminated portion shifts color as quota depletes:

| Remaining | Moon Color                      |
|-----------|---------------------------------|
| >60%      | Soft white (`#E8E4DF`)          |
| 35-60%    | Warm amber (`#D4A054`)          |
| 10-35%    | Muted orange (`#C46B3A`)        |
| <10%      | Soft red (`#B54444`) + faint glow behind the moon |

### Provider Tint

Each provider has a subtle tint on the illuminated portion:

| Provider | Tint Color | Hex       |
|----------|------------|-----------|
| Claude   | Warm cream | `#D97757` |
| Cursor   | Cool blue  | `#7B61FF` |
| Codex    | Soft green | `#10A37F` |

Not saturated — just enough warmth/coolness to differentiate. They still read as moons.

### Animation

- **Phase transitions:** Shadow edge animates smoothly (0.8s ease-in-out) when quota changes
- **Critical state (<10%):** Subtle breathing glow behind the moon (opacity 0.05–0.15, 3s cycle)
- **Refresh indicator:** Tiny sparkle travels along the illuminated edge (0.5s) during data fetch

### Status Bar Interactions

| Action                  | Result                               |
|-------------------------|--------------------------------------|
| Click                   | Toggle popover open/close            |
| Right-click             | Context menu: Refresh / Settings / Quit |

---

## 3. Popover Design

Dark themed, 280pt fixed width, no window chrome. Uses `NSVisualEffectView` with `.dark` appearance. Corner radius 12pt. Typography: SF Pro (SF Pro Rounded for hero percentage).

### Layout

```
+-----------------------------------+
|                                   |
|             [Moon 48pt]           |
|              Claude               |
|           67% remaining           |
|          resets in 2d 14h         |
|                                   |
+-----------------------------------+
|                                   |
|  > Claude                 O  67%  |
|    Cursor                 O  78%  |
|    Codex                  O  23%  |
|                                   |
+-----------------------------------+
|                                   |
|    .   .   *   @   .   .         |
|    *   .   .   .   @   *         |
|    .   .   @   *   .   .         |
|    *   @   .   .   *   @         |
|    .   *   @   *   @   o         |
|                                   |
|  Today 1.2K  7d 8.4K  30d 31.5K  |
|                                   |
+-----------------------------------+
|  ~ 45s ago                   [G]  |
+-----------------------------------+
```

### Section 1: Hero Moon

- 48pt moon matching the status bar icon's current phase, provider tint, and color
- Provider name: bold, white, centered
- Percentage remaining: large text, inherits the moon's phase color (white/amber/red)
- Reset countdown: muted gray, e.g. "resets in 2d 14h"
- Updates instantly when switching providers in the list below

### Section 2: Provider Switcher

A list of enabled providers. Each row:

```
[indicator] Provider Name     [mini moon 12pt]  XX%
```

- The currently selected provider has a `>` indicator and a subtle highlight background
- Click a row to switch — hero moon morphs (0.4s animation), status bar icon updates
- Mini moons show each provider's independent phase at a glance

### Section 3: Star Field Usage Heat Map

A 30-day usage visualization. Each day is a dot/star, brightness encodes usage intensity.

#### Grid Layout

6 columns x 5 rows = 30 dots. Day 1 (top-left) = 30 days ago. Day 30 (bottom-right) = today. Read left-to-right, top-to-bottom.

#### Brightness Levels

Usage is bucketed into 5 levels, relative to the user's own average daily usage:

| Level | Opacity | Meaning       | Dot Size |
|-------|---------|---------------|----------|
| 0     | 15%     | No/minimal    | 3pt      |
| 1     | 35%     | Light day     | 3pt      |
| 2     | 60%     | Average day   | 4pt      |
| 3     | 85%     | Heavy day     | 5pt      |
| 4     | 100%    | Peak day      | 5pt + 2pt soft bloom |

Base color: the selected provider's tint color. Brightness is opacity variation.

#### Today's Dot

- Rendered as a ring with filled center (distinct from other dots)
- Gently pulses if tokens were used in the last hour (opacity 70%-100%, 2s cycle)
- Grows in real-time as usage accumulates through the day

#### Hover Interaction

- Hover a dot: tooltip appears directly above showing `Feb 14 · 2,347`
- Hovered dot scales up 1.3x (0.15s ease)
- Adjacent dots dim slightly to draw focus
- Tooltip follows the cursor as you scan across dots

#### Provider Switch

- Stars fade out (0.2s) and fade back in (0.3s) with the new provider's data and tint color
- Different providers produce different constellation patterns

#### Empty / Error States

- No history yet: all dots at level 0, centered muted label: "tracking starts today"
- Provider errored / stale: stars dim uniformly, subtle warning icon next to provider name in switcher

### Section 3b: Summary Row

Below the star field, one line:

```
Today  1.2K    7d  8.4K    30d  31.5K
```

- Labels in muted gray, numbers in white
- Numbers formatted with compact notation:
  - < 1,000: exact (`847`)
  - 1,000 – 999,999: `1.2K`, `84.3K`, `312K`
  - 1,000,000 – 999,999,999: `1.2M`, `84.3M`
  - 1,000,000,000+: `1.2B`
  - One decimal place unless round (`8K` not `8.0K`)
- Hover any number: crossfades (0.2s) to exact count (`31,506`), reverts on mouse leave
- If provider tracks cost: `1.2K · $0.84` (cost always exact, hover expands only the token number)

### Section 4: Footer

Single thin row:

- **Left:** `~ 45s ago` — last refresh timestamp. Click to force refresh all providers.
- **Right:** Gear icon — opens settings panel.

---

## 4. Settings Panel

Replaces popover content with a slide-in from the right (0.25s).

```
+-----------------------------------+
|  < Settings                       |
|                                   |
|  Providers                        |
|  +-----------------------------+  |
|  | [x] Claude     detected     |  |
|  | [x] Cursor     detected     |  |
|  | [x] Codex      detected     |  |
|  | [ ] Gemini     not found    |  |
|  | [ ] Copilot    not found    |  |
|  +-----------------------------+  |
|                                   |
|  Refresh every     [2 min v]      |
|  Launch at login   [  toggle  ]   |
|                                   |
|  v0.1.0             Check for ^   |
+-----------------------------------+
```

- **Auto-detection:** On first launch, Wane scans for installed CLIs and credentials. Found providers are pre-enabled with a "detected" badge.
- **Refresh interval:** Dropdown with presets: 1m, 2m, 5m, manual
- **Launch at login:** Toggle
- **Version + update check:** Bottom row
- **Back arrow** returns to the main popover

---

## 5. Tech Stack & Architecture

### Platform

- **Language:** Swift
- **UI:** SwiftUI (popover) + Core Graphics / CAShapeLayer (status bar icon)
- **Target:** macOS 14+ (Sonoma)
- **Build system:** Swift Package Manager
- **No dock icon:** `LSUIElement = true`

### Data Fetching Per Provider

| Provider | Method                                    | Auth Source                        |
|----------|-------------------------------------------|------------------------------------|
| Claude   | Read `~/.claude/` config + `claude` CLI   | Existing CLI credentials           |
| Cursor   | Local config/SQLite + Settings API        | Existing Cursor session            |
| Codex    | `codex` CLI RPC / local session files     | Existing CLI credentials           |

### Key Architecture Decisions

- **CLI-first auth:** Never ask the user to authenticate. If they have the CLI installed, read existing credentials/session. Zero setup.
- **Keychain: read-only, once.** Cache a token, refresh silently. No repeated permission prompts. If a token expires, show a gentle "re-auth needed" state — no crashes, no broken UI.
- **Polling with backoff:** Configurable refresh (default 2min). Backs off when idle (screen locked, no coding activity detected).
- **Provider isolation:** Each provider fetches independently. One failing doesn't affect others.

### Update Mechanism

- Sparkle framework for auto-updates

### Project Structure (planned)

```
Wane/
  Package.swift
  Sources/
    Wane/
      App/
        WaneApp.swift             # Entry point, NSStatusItem setup
        AppDelegate.swift         # Menu bar lifecycle
      UI/
        StatusBarIcon.swift       # Moon icon rendering (Core Graphics)
        PopoverView.swift         # Main popover (SwiftUI)
        HeroMoonView.swift        # Large moon in popover
        ProviderSwitcher.swift    # Provider list
        StarFieldView.swift       # 30-day usage heat map
        UsageSummaryView.swift    # Compact stats row
        SettingsView.swift        # Settings panel
      Providers/
        Provider.swift            # Protocol
        ClaudeProvider.swift
        CursorProvider.swift
        CodexProvider.swift
      Services/
        ProviderManager.swift     # Orchestrates fetching, caching, scheduling
        TokenFormatter.swift      # 1.2K / 8.4M formatting
      Models/
        UsageData.swift           # Token counts, dates, quota info
        ProviderConfig.swift      # Provider metadata, tint colors
  Tests/
    WaneTests/
```

---

## 6. MVP Scope

### In Scope

- Single moon icon in status bar, switchable between providers
- Popover with hero moon, provider switcher, star field, usage summary, footer
- Settings panel with provider toggles, refresh interval, launch at login
- Three providers: Claude, Cursor, Codex
- Auto-detection of installed CLIs
- Compact number formatting with hover-to-expand
- Sparkle auto-updates

### Out of Scope (future)

- Additional providers (Gemini, Copilot, etc.)
- WidgetKit integration
- CLI companion tool
- Cost tracking (tokens only for MVP)
- Notification alerts when approaching limits
- Usage export / history beyond 30 days
