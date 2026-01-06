# Journey System Logic (Architecture V1)

> **Last Updated**: 2026-01-05  
> Core models live in `TimeLineCore` (Domain / Services / Parsing / Persistence / Utilities).

---

## 中文说明（核心概念）
- **Timeline Map 是舞台**：UI 只是 `DaySession` 的投影；放置只通过 `TimelineStore.place*` 写入。
- **Cards / Library / Decks 语义**：Cards 是模板仓库，先加入 Library；Library 是近期要做的任务池；Decks 是可复用的任务组合。
- **放置路径**：Library/Deck → 生成 occurrence → 写入 `DaySession.nodes`。
- **提醒行为统一**：`TaskBehavior` 只有 `.battle` / `.reminder`，不再区分旧的 reminderOnly/passive。

## 功能位置索引（简版）
- **CardTemplate**：`TimeLineCore/Sources/TimeLineCore/Domain/CardTemplate.swift`
- **LibraryEntry**：`TimeLineCore/Sources/TimeLineCore/Domain/LibraryEntry.swift`
- **TimelineNode / DaySession**：`TimeLineCore/Sources/TimeLineCore/Domain/TimelineNode.swift` / `TimeLineCore/Sources/TimeLineCore/Domain/DaySession.swift`
- **FocusGroup**：`TimeLineCore/Sources/TimeLineCore/Domain/FocusGroupPayload.swift` / `TimeLineCore/Sources/TimeLineCore/Services/FocusGroupSessionCoordinator.swift`
- **App 层放置**：`timeLine/timeLine/State/TimelineStore.swift`

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
- **Behavior**:
  - `TaskBehavior`（`.battle` / `.reminder`）
  - reminder 判断：`remindAt` / legacy `taskMode.reminderOnly` / `BossStyle.passive`

### B. `Boss` (Task)
Represents a focused task.
- **Fields**: `id`, `name`, `maxHp`, `currentHp`, `style`, `category`
- **Recommended Start**: `recommendedStart: DateComponents?` (for UI hints)
- **Reminder Fields**: `remindAt`, `leadTimeMinutes`

### C. `CardTemplate`
Reusable task definition for creation and repeat spawning.
- **Fields**: `title`, `defaultDuration`, `taskMode`, `fixedTime`, `repeatRule`, `deadlineWindowDays`, `remindAt`, `leadTimeMinutes`, `isEphemeral`, `category`, `style`, `icon`, `tags`, `energyColor`
- **Repeat Rules**: daily/weekly/monthly for auto-spawn.
- **Scheduling vs Mode**: `fixedTime/repeatRule/deadlineWindowDays` are scheduling semantics; `taskMode` is execution semantics (orthogonal, not a replacement).
- **Usage**: TaskSheet edits and QuickEntry both produce `CardTemplate` directly; Cards tab仅负责加入 Library。
- **Reminder**: `remindAt` / `leadTimeMinutes` 仅用于提醒触发（不进入 BattleView）。

### C-1. `LibraryEntry`
Library 的最小持久化条目。
- **Fields**: `templateId`, `addedAt`, `deadlineStatus`
- **Derived**: `deadlineAt = addedAt + deadlineWindowDays`（由 UI/Store 计算，不强制落库）
- **Usage**: Library 作为“近期想做的任务池”，拖拽到地图生成 occurrence。

### D. `DaySession`
Route manager and progression.
- **Fields**: `nodes`, `currentIndex`
- **Responsibilities**:
  - `advance()` marks current complete and unlocks next
  - `moveNode()` reorders and recalculates lock states
  - `resetCurrentToFirstUpcoming()` for idle state
  - Timeline placement is handled in the app layer (`TimelineStore.place*`)

`TimelineNode` stores an optional `taskModeOverride`; effective task mode resolves override first, then template.

### E. Card & Deck Models
Card system lives in `TimeLineCore` for persistence.
- `CardTemplate`: reusable card concept used by DeckOverlay.
- `DeckTemplate`: app-layer deck bundle (stored in app target).
- `EnergyColorToken`: token enum only (no UI color in core).
App layer creates timeline occurrences via `TimelineStore.placeCardOccurrence` / `placeDeckBatch` (empty timeline uses `placeCardOccurrenceAtStart`; occurrences are `TimelineNode`, no CardInstance model).

### F. Focus Group (Unknown Length)
- **Payload**: `FocusGroupPayload` stores `memberTemplateIds` + `activeIndex`.
- **Timing**: `FocusGroupSessionCoordinator` allocates seconds per member.
- **Completion**: emits `SessionResult.completedExploration` with allocations + total focused seconds.

---

## 3. Core Engines

### `BattleEngine`
Strict-mode focus timer.
- Wall-clock timing; wasted time tracking.
- Emits `SessionResult` on victory/retreat.

### `ReminderScheduler`
In-app reminder trigger.
- Evaluates `remindAt - leadTimeMinutes`.
- Emits `ReminderEvent` (UI handles banner; no BattleEngine).

### `StatsAggregator`
Aggregates daily history and heatmap intensity.

---

## 4. Planning & Spawning

### Templates & Routines
- `DefaultCardTemplates` provides defaults (stable UUIDs).
- `RoutineProvider` supplies routine presets; app layer converts them into Decks.

### Quick Entry Flow
- `QuickEntryParser.parseDetailed()` returns:
  - `CardTemplate`
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
- `daySession`, `engineState`, `history`, `cardTemplates`
- `inbox` (CardTemplate IDs for tomorrow tasks)
- `spawnedKeys` ledger
