# Journey System Logic (Architecture V1)

> **Last Updated**: 2025-12-25  
> Core models live in `TimeLineCore`.

---

## 1. Core Metaphor
The app models a day as a linear **Journey** composed of **Timeline Nodes**.
- **Journey**: `DaySession` with ordered nodes.
- **Battle Nodes**: focus tasks (Boss fights).
- **Bonfire Nodes**: rest breaks.
- **Progress**: `currentIndex` + per-node completion/lock state.

The UI is a projection of `DaySession` plus transient UI state.

---

## 2. Domain Models (`TimeLineCore`)

### A. `TimelineNode`
A single step in the route.
- **Type**:
  - `.battle(Boss)`
  - `.bonfire(TimeInterval)`
  - `.treasure`
- **State**:
  - `isCompleted`
  - `isLocked`

### B. `Boss` (Task)
Represents a focused task.
- **Fields**: `id`, `name`, `maxHp`, `currentHp`, `style`, `category`
- **Recommended Start**: `recommendedStart: DateComponents?` (for UI hints)

### C. `TaskTemplate` (Legacy: repeat/QuickEntry/TaskSheet)
Reusable task definition for legacy flows.
- **Fields**: `title`, `duration`, `fixedTime`, `repeatRule`, `category`, `style`
- **Repeat Rules**: daily/weekly/monthly for auto-spawn.
- **Usage**: repeat rules + TaskSheet edits; QuickEntry returns TaskTemplate but app converts to CardTemplate for placement.

### D. `DaySession`
Route manager and progression.
- **Fields**: `nodes`, `currentIndex`
- **Responsibilities**:
  - `advance()` marks current complete and unlocks next
  - `moveNode()` reorders and recalculates lock states
  - `resetCurrentToFirstUpcoming()` for idle state
  - Timeline placement is handled in the app layer (`TimelineStore.place*`)

### E. Card & Deck Models
Card system lives in `TimeLineCore` for persistence.
- `CardTemplate`: reusable card concept used by DeckOverlay.
- `DeckTemplate`: app-layer deck bundle (stored in app target).
- `EnergyColorToken`: token enum only (no UI color in core).
App layer creates timeline occurrences via `TimelineStore.placeCardOccurrence` / `placeDeckBatch` (empty timeline uses `placeCardOccurrenceAtStart`; no CardInstance store).

---

## 3. Core Engines

### `BattleEngine`
Strict-mode focus timer.
- Wall-clock timing; wasted time tracking.
- Emits `SessionResult` on victory/retreat.

### `StatsAggregator`
Aggregates daily history and heatmap intensity.

---

## 4. Planning & Spawning

### Templates & Routines
- `TemplateStore` provides defaults (including 25m).
- `RoutineProvider` supplies routine presets; app layer converts them into Decks.

### Quick Entry Flow
- `QuickEntryParser.parseDetailed()` returns:
  - `TaskTemplate` (legacy template type, not `CardTemplate`)
  - `placement`: `.today` or `.inbox`
  - `suggestedTime` (e.g., "今晚" -> 20:00)
- **"明天"** tasks go to `inbox` (not added to today).

### Spawning
- `SpawnManager.spawn(from:)` creates `Boss` with `recommendedStart`.
- Timeline nodes are appended to `DaySession` via `TimelineStore` in the app layer (placeCardOccurrence/placeDeckBatch for DeckOverlay; inbox/QuickEntry creates CardTemplate and uses placeCardOccurrence).

---

## 5. Bonfire Suggestions (V1)
`TimelineEventCoordinator` tracks:
- `battlesSinceRest`
- `focusedSecondsSinceRest`

When thresholds are met, it emits `bonfireSuggested` to UI and highlights the next bonfire node.

---

## 6. Day Boundary & Reset
On launch, `TimeLineApp.restoreState()`:
1. Loads `AppState` from JSON.
2. If day changed: archive yesterday, spawn repeats, reset state.
3. Else: reconcile engine and continue.

---

## 7. Persistence
`AppState` stores:
- `daySession`, `engineState`, `history`, `templates`, `cardTemplates`
- `inbox` (CardTemplate IDs for tomorrow tasks)
- `spawnedKeys` ledger
