# TimeLine App — UI & Coordination Logic

> **Last Updated**: 2025-12-24  
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
| **`TimelineStore`** | Single placement write path | `placeCardOccurrence()`, `placeDeckBatch()`, `placeCardOccurrenceAtStart()` |
| **`DragDropCoordinator`** | Drag location + hover | `startDrag(payload:)`, `updatePosition()`, `drop()` |

---

## View Logic Map

### `RootView.swift`
Layer orchestration and drag routing.

| Feature | Code Component | Logic Description |
|---|---|---|
| **Layer Order** | `RootView` | Map → DeckOverlay → DraggingCard/Deck → Modal edit sheet |
| **Drag Routing** | `DragGesture` | Global coords; uses `nodeFrames` from preference |
| **Drop Handling** | `handleDrop()` | calls `TimelineStore.place*` then `exitDrag()` |
| **Empty Drop** | `handleEmptyDropFallback()` | empty timeline → create first node |
| **Floating Controls** | `RootView` overlay | Add + Settings floating buttons |
| **Card Edit** | `.sheet` | `cardEdit` presented as modal sheet |

### `DeckOverlay.swift`
Primary creation surface.

| Feature | Code Component | Logic Description |
|---|---|---|
| **Tabs** | `DeckTab` | Cards / Decks (Create tab removed; Add Card opens QuickBuilder) |
| **Fan** | `CardFanView` | tap preview, long press → edit, drag → start |
| **QuickBuilder** | `QuickBuilderSheet` | Add Card opens template creator; returns to Cards with drag hint |
| **Routine Decks** | Decks tab | small row of routine decks + See All |
| **Close** | background tap / swipe | `exitToHome()` |

### `RogueMapView.swift`
Map route UI + drop target feedback.

| Feature | Code Component | Logic Description |
|---|---|---|
| **Node Frames** | `NodeFrameKey` | global frames for drop hit-testing |
| **Drop Rings** | MapNodeRow overlay | highlight nodes during drag |
| **Insert Hint** | MapNodeRow overlay | Hover shows insert before/after |

### Gesture System (Current)

| Gesture | Action | Notes |
|---|---|---|
| **Tap** | Start task | Starts battle or rest |
| **Drag Card/Deck** | Place on node | Empty map creates first node |
| **Scroll Drag** | Map snap | Drag ends → snaps to nearest node |

---

## Event Banners

| Banner | Trigger | Content |
|---|---|---|
| **Distraction** | Retreat with wasted time | "Wasted +X min" |
| **Rest Complete** | Bonfire ends | "Up next: Task (Xm)" |
| **Bonfire Suggested** | After streak/long focus | "前面有个篝火，要不要歇一会？" |

Banners auto-dismiss after ~1.8s. Next actionable node pulses with cyan glow.

---

## Settings & Display

- **24h/12h Toggle**: `@AppStorage("use24HourClock")` controls time format.
- **Upcoming Time Label**: uses `TimeFormatter.formatClock()`.
- **Default Tonight Time**: Quick Entry assumes 20:00 when "今晚" is used.

---

## Coordination Flows

### Deck Drag → Timeline Placement
1. Drag card/deck enters `.dragging(DragPayload)`.
2. `DragDropCoordinator` tracks global drag location.
3. On drop, `TimelineStore.placeCardOccurrence/ placeDeckBatch` inserts before/after anchor based on hover.
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
