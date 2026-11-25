# ClearDeck Solitaire — Product Requirements Document (PRD v1.0)

**Product Name:** ClearDeck Solitaire  
**Package / Bundle ID:** `com.cleardeck.solitaire`  
**Target Market (v1.0):** United States (English-only; UI strings centralized for future localization)  
**Platforms:** Android & iOS (Phone Portrait + Tablet Landscape/Portrait via single Flutter codebase)  
**Document Status:** Locked for MVP v1.0 Free Beta & v1.1 Commercial Architecture  

---

## 1. Executive Summary & Positioning

ClearDeck Solitaire is a dignified, ultra-clear, zero-clutter classic Klondike Solitaire built for **55–74 Active Seniors (core volume)** and **75+ / low-vision players (supported seamlessly through clean, respectful customization)**.

### Positioning Principle: Respectful Universal Craft (No "Elderspeak" UI)
Older adults who enjoy Klondike daily are experienced, independent smartphone and tablet users—not children or helpless patients. ClearDeck deliberately avoids patronizing "senior mode" tropes:
- **No forced onboarding quizzes or 3-step wizards** (launches straight into Deal #1 in under 1 second).
- **No childish icons, patronizing copy, PIN/long-press locks, or locked-down feature walls.**
- **No forced leagues, fake AI competitor popups, or meaningless coin economies.**
- **Instead:** Effortless visual clarity, generous 1-tap accuracy, calm aesthetics, deterministic guaranteed-winnable deals, rock-solid offline persistence, and honest monetization.

---

## 2. Competitor Weakness Analysis (`Vita Solitaire for Seniors`)

Direct inspection of Google Play Store (`com.vitastudio.solitaire`, **4.9★ across 346K reviews, 5M+ downloads**, v1.49.0) 1–3★ US English critical reviews revealed six structural weaknesses that drive churn and 1-star backlash:

| # | Competitor Failure Mode | Real User Evidence (Google Play US Reviews) | ClearDeck Solitaire Solution |
|---|---|---|---|
| **1** | **Honeymoon-to-Ad-Trap Switch & Unclosable Ads** | Zero ads for hour 1 / day 1 during the "Rate Us" window, then 30–60s ads after every game & loss requiring 3–5 tiny `X`/`>>` clicks, plus Temu/Amazon/Play Store redirects and fake "obsolete upgrade" popups. | **v1.0:** Zero ads.<br>**v1.1:** Honest expectations, max 1 clean closable interstitial every 2–3 completed wins (≥4 min cooldown), never on loss/restart, zero bottom banner, hostile ad categories blocked. |
| **2** | **Paid "Ad-Free" Still Shows Ads** | Users who paid `$10.99`/`£9.99` permanent ad-removal or VIP subscriptions still get "optional" reward/bonus ads and cross-promos—especially frustrating for elderly family members. | Single `$6.99` one-time `True Ad-Free Forever` IAP in v1.1 removes **100%** of interstitials, rewarded ad gates, cross-promos, and store nags. |
| **3** | **Sluggish Multi-Tap Input While Timer Runs** | Cards often ignore taps (requiring 3–6 taps or interrupted drags) while the clock starts ticking on the very first tap; auto-move is broken or missing; left-handed play feels hidden. | **12–14dp jitter-tolerant 1-Tap smart move** + magnetic drag + One-Tap Auto-Complete. Timer is **OFF by default** and starts only on the first *valid* move when enabled. Left-handed mode is a 1-tap switch. |
| **4** | **Useless Looping Hints & Unwinnable Frustration** | Hint repeatedly cycles Queen↔King without uncovering hidden cards; players suspect rigged deals meant to trigger defeat ads. | **Guaranteed Winnable Deals** (verified by fast solver) as default + **Loop-Free Smart Hint** + **Dead-End Detector & Smart Rewind** to the last proven solvable state. |
| **5** | **Clutter, Forced Leagues & Useless Coins** | Unclosable "You beat 97% of players" popups, forced league enrollment, and coins earned with no store to spend them on. | Zero leagues, zero fake rankings, zero coins. Calm Daily Challenge Calendar stamps unlock curated table/card themes directly. |
| **6** | **State Loss, Audio Leaks & Bloat (229 MB)** | Switching apps for 5–10s deletes the active hand; background music overlaps and persists after exit; volume is full-blast or mute; streak counters miscount; drains battery. | **~25–35 MB Flutter build**, instant move-by-move local persistence (zero state loss), independent BGM/SFX volume sliders, strict audio teardown on backgrounding, accurate stats. |

---

## 3. Validated US ASO Strategy

Live Google Play US (`hl=en&gl=us`) autocomplete and top-8 search inspection established real user search phrasing:

- **Validated Real Search Phrases:**
  - `solitaire for seniors` (#1 suggestion under `solitaire for `)
  - `solitaire large cards` (#1 suggestion under `solitaire large`)
  - `solitaire large cards for seniors` (#2 suggestion under `solitaire large`)
  - `solitaire big cards` (#1 suggestion under `solitaire big `)
  - `large print solitaire` (#5 under `solitaire large`, standalone autocomplete)
  - `offline solitaire` (high-intent utility modifier)
- **Strategic Keyword Rules:**
  1. **Use `Large Cards` / `for Seniors` / `Offline` in Title & Short Description** rather than wasting prime character limits on `"4-Color Deck"` (which has minimal direct search volume).
  2. **Use `4-Color Deck`, `Smart Rewind`, and `Zero Clutter` in Store Screenshots #1–#3** as high-converting visual hooks once the user lands on the listing.
  3. **Strict Policy Honesty:** Metadata may highlight `"No Ads"` **only** during v1.0 Free Beta when the app truly has zero ads. Before shipping v1.1 monetization, update store text to honest calm positioning (`Large Cards`, `Offline Classic`, `One-Time Ad-Free Option`) to comply with Google Play / App Store rules and prevent 1-star backlash.

---

## 4. MVP v1.0 (Free Beta) Feature Specification

### 4.1 Launch & Core Gameplay
- **Zero-Friction Boot:** App opens directly onto an active, playable **Draw-1 Guaranteed Winnable Klondike** hand (or resumes the saved hand in progress).
- **Rules & Modes:**
  - Klondike **Draw-1** (default) and **Draw-3**.
  - Deal Mode: **Guaranteed Winnable** (default, verified by bounded solver) or **Classic Random**.
  - **Offline Daily Challenge:** Deterministic `YYYYMMDD` seeded winnable deal playable 100% offline.
- **Tactile Input & Accessibility:**
  - **Jitter-Tolerant 1-Tap Smart Move (`12–14dp` touch slop tolerance):** Minor finger tremor during a tap resolves cleanly as a tap rather than a cancelled drag.
  - **Magnetic Smooth Drag:** Direct drag-and-drop for single cards and valid alternating-color runs without requiring long-press delays.
  - **One-Tap Auto-Complete:** Appears as a calm floating pill when stock/waste are empty and all tableau cards are face-up.
  - **Timer OFF by Default:** Optional timer toggle in Settings; starts only upon the **first valid move**.
- **Intelligent Assist:**
  - **Loop-Free Smart Hint:** Prioritizes safe foundation moves, hidden-card reveals, and constructive column clears. Never suggests pointless empty-King-to-empty-King or already-exposed sub-stack shuffles.
  - **Dead-End Detector & Smart Rewind:** Scans stock/waste reachability; when no constructive moves remain, calmly offers **Rewind to Last Solvable Move** (jumping directly back to the latest solvable checkpoint in move history), **Replay Same Deal**, or **New Deal**.
- **Zero-Loss Persistence & Offline Guarantees:**
  - Every move, undo stack, move count, elapsed seconds, and deal metadata persists locally on disk immediately and on app backgrounding (`paused`/`inactive`).
  - 100% functional in Airplane Mode.

### 4.2 Visual System, Responsive Layouts & Audio
- **Cascade-Safe Large-Print Card Face:** Bold rank + suit header strip designed so stacked columns (8–13+ cards) never clip index symbols; large center suit watermark; dynamic vertical compression keeps 13+ card cascades on screen without scroll overflow.
- **Instant 1-Tap Customization (inside Settings sheet):**
  - **Card Size:** `Large` (default) / `Jumbo`
  - **Deck Colors:** `Classic 2-Color` (default) / `4-Color Deck` (`♠ Black, ♥ Red, ♦ Blue, ♣ Green`)
  - **Handedness:** `Right-Handed` (default) / `Left-Handed` (cleanly mirrors Stock/Waste and Foundations)
  - **3 Curated WCAG AAA Themes:**
    1. *Classic Matte Green* (`#1B4D3E` table / `#FAF8F3` card)
    2. *Warm Ivory Paper* (`#EAE2D2` table / `#FFFFFF` card)
    3. *Warm OLED Night* (`#141210` table / `#EBE3D5` low-glare warm cream card)
- **Responsive Phone & Tablet Support:**
  - **Phone Portrait:** Slim status header (Moves, optional Timer, Daily icon, Stats icon) → Stock/Waste + 4 Foundations row → 7-column Tableau → Fixed 4-button labeled Bottom Bar (`Undo`, `Hint`, `New`, `Settings`, `≥52dp` height, `≥12dp` spacing, zero bottom ads).
  - **Tablet Landscape (`width > height && width >= 700`):** Ergonomic wide-screen felt layout maximizing card legibility with comfortable thumb-reachable action controls.
- **Audio & Lifecycle Hygiene:**
  - Independent `Card Sound Volume` and `Music Volume` sliders (no binary mute/full-blast).
  - Immediate audio pause/release when switching apps or locking screen.

### 4.3 Retention & Personal Progress (No Stress)
- **Offline Daily Calendar:** Monthly calendar showing completed day stamps, streak count, and ability to play past days of the current/previous months offline.
- **Reliable Personal Statistics:** Games Played, Games Won, Win Rate %, Current Win Streak, Best Win Streak, Best Moves, Best Time.

---

## 5. Phased Roadmap: v1.0 Free Beta → v1.1 Monetization

### Beta Go / No-Go Quality Gate (v1.0 → v1.1)
Before enabling monetization in v1.1, verify v1.0 Free Beta meets:
- **D1 Retention:** `≥ 45%`
- **D7 Retention:** `≥ 25%`
- **D30 Retention:** `≥ 13%`
- **Crash-Free Sessions:** `≥ 99.8%`
- **Average Daily Session Duration:** `≥ 8 minutes`

### v1.1 Commercial Monetization Blueprint (Drop-In via Service Interfaces)
1. **Clean Interstitials:** 0 ads for first 3 hands; then max 1 closable interstitial every 2–3 completed wins with `≥ 4 minute` cooldown (never on loss or restart; zero bottom banners; aggressive redirect/playable-trap networks blocked).
2. **Voluntary Rewarded Video:** Unlock past Daily Challenge dates or extra Smart Rewinds only when explicitly tapped.
3. **Hero IAP — `True Ad-Free Forever` (`$6.99` one-time via RevenueCat):** Strips 100% of interstitials, rewarded ad buttons (grants free usage), and review/upgrade prompts.
4. **Live Ops Infrastructure:** Firebase Analytics + Crashlytics + Remote Config (for A/B tuning ad cadence & IAP pricing) + in-app `Report Bad Ad` diagnostic logger.

### Explicit v1.0 Exclusions & Phase 2 Sister App
- **Excluded from v1.0:** Spider/FreeCell modes, social leagues, leaderboards, coin stores, mandatory accounts/cloud login, paid cosmetic bundles.
- **Phase 2 Expansion:** Launch `Spider Solitaire Large Cards` as a separate lightweight sister app (leveraging live Google Play autocomplete demand #4 `spider solitaire large cards`) to create a low-CPI cross-promotion loop.
