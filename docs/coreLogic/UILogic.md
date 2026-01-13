# TimeLine App — UI & Coordination Logic

> **Last Updated**: 2026-01-05  
> Location: `timeLine/timeLine/` (Main App Target)

---

## App Architecture

| Component | Purpose | Key Function/Method |
|---|---|---|
| **`TimelineEventCoordinator`** | Multi-system sync + bonfire suggestions | `safeAdvance()`, `maybeSuggestBonfire()` |
| **`AppStateManager`** | Global state & persistence | `requestSave()` (debounced 500ms) |
| **`BattleEngine`** | Focus logic (Core) | `startBattle(boss:)`, `tick()` |
| **`AppModeManager`** | Single overlay state machine | `enter(_:)`, `exitDrag()`, `exitCardEdit()` |
| **`CardTemplateStore`** | Template cards for DeckOverlay | `add()`, `update()`, `orderedTemplates()` |
| **`DeckStore`** | Deck bundles | `add()`, `update()`, `orderedDecks()` |
| **`TimelineStore`** | Single placement write path | `placeCardOccurrence()`, `placeDeckBatch()`, `placeCardOccurrenceAtStart()`, `placeCardOccurrenceByTime()` |
| **`DragDropCoordinator`** | Drag location + hover | `startDrag(payload:)`, `updatePosition()`, `drop()` |
| **`ReminderScheduler`** | In-app reminder trigger | `evaluate(nodes:at:)` |

---

## 功能位置索引（中文）

### 卡片 / Library / Deck
- **TaskBehavior**：`TimeLineCore/Sources/TimeLineCore/Domain/TaskBehavior.swift`
- **CardTemplate 模型**：`TimeLineCore/Sources/TimeLineCore/Domain/CardTemplate.swift`
- **CardTemplateStore / LibraryStore**：`timeLine/timeLine/State/CardTemplateStore.swift`
- **LibraryEntry**：`TimeLineCore/Sources/TimeLineCore/Domain/LibraryEntry.swift`
- **Cards UI**：`timeLine/timeLine/Views/Deck/CardFanView.swift`
- **Library UI**：`timeLine/timeLine/Views/Deck/DeckOverlay.swift`（`LibraryTabView`）
- **Library 选卡弹窗**：`timeLine/timeLine/Views/Deck/CardLibraryPickerSheet.swift`
- **Library 选择列表**：`timeLine/timeLine/Views/Deck/CardLibrarySelectionView.swift`
- **DeckTemplate / DeckStore**：`timeLine/timeLine/State/DeckStore.swift`
- **Decks UI**：`timeLine/timeLine/Views/Deck/DeckOverlay.swift`

### 拖拽与放置
- **拖拽 payload / state**：`timeLine/timeLine/State/DragPayload.swift` / `timeLine/timeLine/State/DragDropCoordinator.swift`
- **拖拽落点与 placement**：`timeLine/timeLine/Views/RootView.swift` (Drop Handling) & `RogueMapView.swift` (Visual Feedback)
- **放置写入**：`timeLine/timeLine/State/TimelineStore.swift`
- **路线结构**：`TimeLineCore/Sources/TimeLineCore/Domain/DaySession.swift`

### Focus Group / Rest Prompt
- **FocusGroup payload**：`TimeLineCore/Sources/TimeLineCore/Domain/FocusGroupPayload.swift`
- **Group Focus UI**：`timeLine/timeLine/Views/FocusGroup/GroupFocusView.swift`
- **完成/报告协调**：`timeLine/timeLine/TimelineEventCoordinator.swift`
- **RestPrompt UI**：`timeLine/timeLine/Views/Shared/RestSuggestionBanner.swift`
- **Reminder UI**：`timeLine/timeLine/Views/Shared/ReminderBanner.swift`

---

## View Logic Map

### `RootView.swift`
Layer orchestration and drag routing.

| Feature | Code Component | Logic Description |
|---|---|---|
| **Layer Order** | `RootView` | Map → DeckOverlay → DraggingCard/Deck/Group → Modal edit sheet |
| **Drag Routing** | `DragGesture` | Global coords; uses `nodeFrames` from preference |
| **Drop Handling** | `handleDrop()` | calls `TimelineStore.place*` then `exitDrag()` |
| **Empty Drop** | `handleEmptyDropFallback()` | empty timeline → create first node |
| **Floating Controls** | `RootView` overlay | Add + Settings floating buttons |
| **Card Edit** | `.sheet` | `cardEdit` presented as modal sheet |
| **Reminder Banner** | `RootView` overlay | `pendingReminder` → 完成 / 稍后（标题可跳转详情） |

### `DeckOverlay.swift`
Primary creation surface.

| Feature | Code Component | Logic Description |
|---|---|---|
| **Tabs** | `DeckTab` | Cards / Library / Decks (Create tab removed; Add Card opens QuickBuilder) |
| **Fan** | `CardFanView` | tap to add to Library, long press → edit |
| **Library** | `LibraryTabView` | long-press drag to map; select → Add to Group or drag group token; sections: Reminders + 1/3/5/7 Days + Later + Expired |
| **QuickBuilder** | `QuickBuilderSheet` | Add Card opens template creator; returns to Cards with add-to-Library hint |
| **Reminder Create** | `QuickBuilderSheet` | if `remindAt` set, auto-inserts by time |
| **Routine Decks** | Decks tab | small row of routine decks + See All |
| **Close** | background tap / swipe | `exitToHome()` |
| **Sheet** | `DeckOverlay` | bottom sheet (map remains visible) |

### `RogueMapView.swift`
Map route UI + drop target feedback.

| Feature | Code Component | Logic Description |
|---|---|---|
| **Node Frames** | `NodeFrameKey` | global frames for drop hit-testing |
| **Drop Rings** | MapNodeRow overlay | highlight nodes during drag |
| **Visual Swap** | `offsetForNode()` | Dragging node swaps position with hovered node (Timeline axis static) |
| **Time Labels** | `TimelineNodeRow` | Displays estimated start time (e.g. "20:00") or "NOW" |
| **Drop Rules** | MapNodeRow overlay | only upcoming (non-completed) nodes are droppable |

### Gesture System (Current)

### Gesture System (Current)

| Gesture | Action | Notes |
|---|---|---|
| **Tap** | Start task | Reminder task tap completes immediately; battle/rest otherwise |
| **Long Press + Drag Node** | Reorder Task | **Swap Behavior**: Dragged node swaps with target; timeline axis static |
| **Drag Library/Deck** | Place on node | Empty map creates first node |
| **Drag Group Token** | Place group occurrence | Select ≥2 in Library |

---

## Event Banners

| Banner | Trigger | Content |
|---|---|---|
| **Distraction** | Retreat with wasted time | "Wasted +X min" |
| **Rest Complete** | Bonfire ends | "Up next: Task (Xm)" |
| **Bonfire Suggested** | After streak/long focus | "前面有个篝火，要不要歇一会？" |
| **Reminder** | remindAt - leadTime | "提醒：任务名" + 完成 / 稍后（标题可进入详情） |

Banners auto-dismiss after ~1.8s. Next actionable node pulses with cyan glow.
Focus session views (BattleView / GroupFocusView) show the next reminder countdown when one exists.

---

## Settings & Display

- **24h/12h Toggle**: `@AppStorage("use24HourClock")` controls time format.
- **Upcoming Time Label**: uses `TimeFormatter.formatClock()`.
- **Default Tonight Time**: Quick Entry assumes 20:00 when "今晚" is used.

---

## Coordination Flows

### Deck Drag → Timeline Placement
1. Drag Library/Deck/Group enters `.dragging(DragPayload)`.
2. `DragDropCoordinator` tracks global drag location.
3. On drop, `TimelineStore.placeCardOccurrence/ placeDeckBatch/ placeFocusGroupOccurrence` inserts before/after anchor based on hover.
4. App returns to `.deckOverlay` for chain-add.
5. Deck drop shows ghost summary on hover + undo toast after placement.

### Card Detail Edit
1. Long press card → `.cardEdit`.
2. Modal sheet edits a local draft of `CardTemplate`, save writes back to store.
3. Close → return to captured mode.

### Deck Detail Edit
1. Long press deck → `.deckEdit`.
2. Modal sheet edits a local draft; save writes deck order/title back to store.
3. Close → return to captured mode.

### Task Completion Flow
1. `BattleEngine` emits `SessionResult`.
2. `TimelineEventCoordinator` advances `DaySession`.
3. UI shows banner and pulses next node.

### Bonfire Suggestion Flow
1. Coordinator tracks battles and focused time since last rest.
2. When threshold reached, emits `bonfireSuggested`.
3. Map shows banner and highlights next bonfire node.
