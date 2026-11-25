# ClearDeck Solitaire — Technical Architecture (v1.0)

## 1. Architectural Principles

1. **Pure Dart Engine Boundary (`lib/engine/`):**
   - Zero `package:flutter/...` imports anywhere under `lib/engine/`.
   - Guarantees deterministic unit testing, fast execution, and clean separation between Klondike math/AI and UI rendering.
2. **Move-by-Move Zero-Loss Persistence:**
   - Every valid move mutates immutable state and triggers an immediate asynchronous write of the serialized `GameState` JSON to `SharedPreferences` (plus lifecycle flush on `AppLifecycleState.paused`/`inactive`).
3. **v1.1 Commercial Swap-In Interfaces (`lib/services/`):**
   - UI and controllers depend strictly on abstract interfaces (`MonetizationService`, `AnalyticsService`, `AudioService`, `PersistenceService`).
   - v1.0 injects `BetaFreeMonetizationService` and `DebugAnalyticsService`. Upgrading to AdMob/MAX + RevenueCat + Firebase in v1.1 requires **zero game logic or UI rewrites**.
4. **Ultra-Lightweight Build Target (`~25–35 MB`):**
   - Minimal dependencies (`shared_preferences`, `flutter_lints` in dev) and custom vector/widget card rendering with zero heavy bitmap asset bloat or continuous idle GPU loops.

---

## 2. Directory Structure

```text
lib/
├── main.dart                          # Boot, SharedPreferences init, lifecycle observer, ClearDeckApp
├── engine/                            # 100% pure Dart (ZERO Flutter imports)
│   ├── engine.dart                    # Barrel export
│   ├── card.dart                      # Suit, PlayingCard, rank labels, JSON serialization
│   ├── move.dart                      # DrawMode, DealType, MoveKind, SolitaireMove
│   ├── game_state.dart                # BoardSnapshot (+ canonicalKey), GameState, JSON serialization
│   ├── rules.dart                     # Legal move validation, applyMove, auto-complete, win checks
│   ├── solver.dart                    # Bounded Best-First KlondikeSolver + safe foundation auto-moves
│   ├── deal_generator.dart            # Seeded shuffle, Guaranteed Winnable Deals, YYYYMMDD Daily Deals
│   ├── hint_engine.dart               # Loop-free Smart Hint & Stock-cycle Dead-End Detector
│   └── tap_resolver.dart              # 1-Tap smart destination picker for Tableau, Waste, Stock
├── services/                          # Abstract commercial & platform boundaries
│   ├── persistence_service.dart       # GameState, AppSettings, PlayerStats, Daily completions
│   ├── monetization_service.dart      # Interface + BetaFreeMonetizationService (v1.0)
│   ├── analytics_service.dart         # Interface + DebugAnalyticsService (v1.0)
│   └── audio_service.dart             # Interface + LightweightAudioService (independent BGM/SFX + pauseAll)
├── state/                             # Native Flutter ChangeNotifier controllers
│   ├── settings_controller.dart       # AppSettings (drawMode, dealType, 4-color, scale, handedness, theme, timer, audio)
│   ├── stats_controller.dart          # PlayerStats + Daily challenge completions + streaks
│   └── game_controller.dart           # Active game orchestration, undo, smart rewind, auto-complete timer
├── theme/                             # WCAG AAA high-contrast tokens & deck colorways
│   ├── deck_palette.dart              # 2-Color & 4-Color suit palettes
│   └── app_theme.dart                 # Classic Matte Green, Warm Ivory Paper, Warm OLED Night
└── ui/                                # Responsive Phone + Tablet presentation layer
    ├── strings.dart                   # Centralized US English UI copy
    ├── game_screen.dart               # Responsive Phone Portrait & Tablet Landscape game board + dialogs
    └── widgets/
        ├── playing_card_widget.dart   # Cascade-safe Large/Jumbo card face, back, hint ring
        ├── bottom_action_bar.dart     # 4 fixed labeled buttons (≥52dp height, ≥12dp spacing)
        ├── settings_sheet.dart        # 1-tap accessibility & theme switches, audio sliders, stats link
        ├── daily_sheet.dart           # Offline monthly Daily Challenge calendar & stamps
        └── stats_sheet.dart           # Personal stats modal

test/
├── engine/
│   ├── rules_test.dart
│   ├── deal_generator_test.dart
│   ├── hint_and_rewind_test.dart
│   └── persistence_test.dart
└── widget_test.dart                   # Phone Portrait (390x844) + Tablet Landscape (1194x834) smoke & overflow tests
```

---

## 3. Core Data Models & Persistence Format

### `BoardSnapshot`
- `stock`: `List<PlayingCard>` (face-down; `.last` is next card to draw)
- `waste`: `List<PlayingCard>` (face-up; `.last` is top playable card)
- `foundations`: `List<List<PlayingCard>>` (4 piles; ascending `A..K` per pile)
- `tableau`: `List<List<PlayingCard>>` (7 columns; `index 0` is base card, `.last` is exposed top card)

**Canonical Key (`BoardSnapshot.canonicalKey()`):**
Produces a compact deterministic string encoding stock cards, waste cards, foundation top ranks (by suit), and all 7 tableau columns (suit/rank/faceUp). Used by `KlondikeSolver` to deduplicate visited states in a `HashSet<String>` without exponential cycles.

### `GameState`
- `board`: current `BoardSnapshot`
- `drawMode`: `draw1 | draw3`
- `dealType`: `winnable | random | daily`
- `dealSeed`: `int` (exact seed for "Replay Same Deal")
- `dailyDateKey`: `String?` (`"YYYY-MM-DD"` when playing a Daily Challenge)
- `movesCount`: `int`
- `elapsedSeconds`: `int`
- `hasStarted`: `bool` (flips `true` ONLY on first legal player move; ensures timer never starts on mis-taps)
- `isWon`: `bool`
- `undoHistory`: `List<BoardSnapshot>` (index `0` = initial deal snapshot)
- `lastKnownSolvableHistoryIndex`: `int?` (used for instant fallback in Smart Rewind)

All objects implement strict `toJson()` / `fromJson()` maps persisted under keys:
- `cleardeck_active_game_v1`
- `cleardeck_settings_v1`
- `cleardeck_stats_v1`
- `cleardeck_daily_completed_v1`

---

## 4. Guaranteed Winnable Deal & Solver Architecture

### `KlondikeSolver` (Bounded Best-First Search)
- **Node Budget:** `maxNodes = 2500` during deal generation; `maxNodes = 1200` for quick dead-end / Smart Rewind checks.
- **Safe Foundation Dominance Pruning:** Automatically advances Aces, Twos, and cards whose rank `r` is `<= minOppositeColorFoundationRank + 1` onto foundations inside solver expansion to eliminate pointless branching.
- **Heuristic Priority:**
  - `+25` per card in foundations
  - `+18` per newly uncovered face-down tableau card
  - `+10` for freeing an empty column when a King is exposed
  - Prunes redundant tableau-to-tableau transfers that neither flip a face-down card, empty a column for a King, nor unblock a card to a foundation.
- **Deal Generation (`DealGenerator.generateWinnableDeal`):**
  - Probes sequential seeds starting from `baseSeed` using Fisher-Yates shuffle (`Random(seed)`).
  - Returns the first seed verified solvable by `KlondikeSolver` (`<30ms` typical in Draw-1, `<80ms` in Draw-3), with pre-verified fallback seeds guaranteed if `maxAttempts` is reached.
- **Offline Daily Deal (`DealGenerator.generateDailyDeal`):**
  - Deterministically maps `year * 10000 + month * 100 + day` to a stable `baseSeed`, guaranteeing every offline device generates the exact same winnable puzzle for any calendar date.

---

## 5. Loop-Free Smart Hint & Smart Rewind

### `HintEngine.findSmartHint`
Explicitly fixes competitor anti-patterns:
1. **Forbidden Hints:**
   - Never suggests moving a King from an empty column (`cardIndex == 0`) to another empty column.
   - Never suggests shifting a face-up run from column A to column B when the card below it in column A is already face-up (unless it immediately exposes a card playable to a foundation).
   - Never loops stock draws forever: before returning `drawStock` or `recycleStock`, performs a deterministic lookahead over the remaining stock/waste cycle in the current `DrawMode`. If zero cards in the cycle are playable and no constructive tableau/foundation moves exist, immediately signals `isDeadEnd = true`.

### Smart Rewind
- Stores every board snapshot in `undoHistory`.
- When the player requests **Rewind to Last Solvable Move**, `GameController` walks backward from the previous snapshot toward index `0` using `KlondikeSolver.isSolvableQuick` (capped per step and falling back to `lastKnownSolvableHistoryIndex` / index `0` for winnable deals) and restores the newest solvable state in a single tap.

---

## 6. Responsive Geometry & Tactile Input Engineering

### Jitter-Tolerant Touch Handling (`14dp` Threshold)
- Flutter's default `Draggable` begins dragging at `kTouchSlop` (~`8–18px` depending on platform, often hijacking shaky taps).
- `ClearDeck` uses a dedicated tap-and-pan wrapper (`_CardGestureWrapper`) or custom `Draggable` slop/tap detector ensuring:
  - Pointer movements `< 14.0` logical pixels cleanly trigger `onTap` (`TapResolver` 1-Tap smart move) with zero lost taps.
  - Movements `>= 14.0` logical pixels transition cleanly into live drag-and-drop without requiring any long press.

### Cascade-Safe Column Sizing
Inside a `LayoutBuilder`, each tableau column computes:
- `cardWidth = min(maxTabletCardWidth, (boardWidth - 6 * gap) / 7)`
- `cardHeight = cardWidth * 1.42`
- Available column height `H`:
  - Base offsets: `faceDownOffset` (`~14–18dp`), `faceUpOffset` (`~28–38dp`, scaled for `Large` vs `Jumbo`).
  - If `cardHeight + faceDownCount * faceDownOffset + faceUpCount * faceUpOffset > H`, offsets scale proportionally (`>= 12dp` minimum for face-down, `>= 22dp` minimum for exposed index header) so even a full 19-card column never triggers a Flutter `RenderFlex` overflow on small phones (`390x844`) or tablets (`1194x834`).

---

## 7. v1.1 Commercial SDK Upgrade Map

| Capability | v1.0 Free Beta | v1.1 Production Drop-In |
|---|---|---|
| **Monetization** | `BetaFreeMonetizationService` | `AdMobMonetizationService` (or `AppLovinMax`) + `RevenueCatBillingService` |
| **Analytics / Crash / Config** | `DebugAnalyticsService` | `FirebaseAnalyticsService` + `Crashlytics` + `RemoteConfig` |
| **Audio** | `LightweightAudioService` | `JustAudioService` / `AudioplayersService` with bundled card-felt `.wav` clips |
