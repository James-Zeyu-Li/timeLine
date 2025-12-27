# Current Project State: TimeLineApp

> **Last Updated**: 2025-12-26 (DeckOverlay + template-driven placement + floating controls)  
> **Status**: V1 Core Complete + UI Semantics Expanded

---

## Overview

A roguelike-inspired iOS focus app built with SwiftUI.

| Aspect | Description |
|---|---|
| **Core Loop** | Battle (Focus) → Bonfire (Rest) → Repeat |
| **Design** | Strict Mode (no pause), single-day timeline + Inbox for tomorrow |
| **Tech** | Pure Swift (`TimeLineCore`) + SwiftUI |
| **Persistence** | Local JSON + debounced save (500ms) |
| **Interaction** | Tap to start, DeckOverlay drag-to-node, edit via sheet, floating Add/Settings |

---

## Core Functionality + UI + Interactions (Short)

### Core Functionality
- **Timeline engine**: `DaySession` manages nodes, progression, and lock states; `BattleEngine` handles focus timing and outcomes.
- **Template semantics**: `CardTemplate` + `DeckTemplate` are reusable; timeline placement creates occurrences (templates never consumed). `CardTemplate` carries repeatRule/fixedTime. Inbox stores CardTemplate IDs in `AppState.inbox` with templates persisted in `AppState.cardTemplates`.
- **Write path**: placement uses `TimelineStore.placeCardOccurrence / placeDeckBatch` (Inbox/QuickEntry create CardTemplate then place).
- **App mode**: `AppModeManager` enforces overlay/drag/edit exclusivity.
- **Drag system**: `DragDropCoordinator` handles global coords + hover targeting.
- **Persistence + events**: `AppStateManager` saves; `TimelineEventCoordinator` advances on battle end.
- **Routine decks**: `RoutineTemplate` converts into Decks; no direct DaySession append in UI.

### UI Surfaces
- **RootView**: layered map/timeline, DeckOverlay, drag layer, edit sheets, floating Add/Settings + message.
- **TimelineView**: card timeline with edit mode reorder/delete and finished section.
- **DeckOverlay** + **CardFanView**: Cards/Decks tabs with fan layout.
- **QuickBuilderSheet**: fast template creator (no direct timeline writes).
- **DeckDetailEditSheet / CardDetailEditSheet**: long-press edit for Decks and CardTemplates.
- **RoutinePickerView**: Routine Decks list + preview sheet.
- **Drag ghost + Undo**: deck hover preview + 2s undo toast.
- **Empty drop zone**: drag-to-drop creates first node.
- **SettingsView**: time format toggle + map prototype.

### Interaction Flow
- **+ Add → DeckOverlay** is the primary creation surface.
- **Drag card/deck → node** creates occurrence(s) via `TimelineStore`; source remains reusable.
- **Deck hover** shows “Insert N / Est. X”; drop inserts batch + Undo.
- **Long press** opens template/deck edit sheets.
- **QuickBuilder create** returns to Cards tab with drag hint.
- **Empty timeline** accepts drop to create the first node.

### Key Types (Core)
- `DaySession`, `TimelineNode`, `Boss`, `BattleEngine`, `AppState`
- `RepeatRule`, `TaskCategory`, `BossStyle`
- `CardTemplate`, `EnergyColorToken`, `RoutineTemplate`

### Key Types (App Layer)
- `AppModeManager`, `DragDropCoordinator`, `TimelineStore`
- `CardTemplateStore`, `DeckStore`, `DeckTemplate`, `DeckBatchResult`

## ✅ Completed Features

### Core Logic (`TimeLineCore`)
- **BattleEngine**: timer, wasted time, immunity, reconciliation, idempotent finalization
- **SessionResult Publisher**: victory/retreat events (atomic, data-rich)
- **DaySession**: append/move/delete, lock-state recalculation, reset to first upcoming
- **RouteGenerator**: bonfire auto-insertion every N battles
- **DefaultCardTemplates**: stable UUID defaults for card templates
- **SpawnManager**: template spawning + recommended start time passthrough
- **QuickEntryParser**: supports tonight/tomorrow/daily keywords
- **AppState**: `inbox` for tomorrow tasks
- **Card Models**: `CardTemplate` + Deck models (template-driven placement)
- **Energy Tokens**: `EnergyColorToken` stored as token only (no UI color)

### UI
- **TimelineView**: pinned header, event banners, pulse effects
- **DeckOverlay**: Cards / Decks tabs with fan display
- **CardFanView**: tap preview, long-press edit, drag to map node
- **QuickBuilderSheet**: Add Card button opens quick template creator (no direct timeline writes)
- **Deck Edit**: long-press deck → rename + reorder + add/remove cards
- **Routine Decks**: Decks tab top strip + See All picker
- **Drag Layer**: floating card/deck follows global drag location
- **Deck Ghost + Undo**: hover shows insert summary; drop creates batch + undo toast
- **Empty Timeline Drop**: drag-to-drop auto-creates first node
- **Floating Controls**: Add + Settings buttons + floating message
- **Inbox Section**: tomorrow tasks stored outside today
- **Labels**: FIRST / NEXT / STARTED status tags
- **Recommended Time**: RECOMMENDED label from `Boss.recommendedStart`
- **Edit Mode**: drag handle reorder, delete button, swipe actions
- **Settings**: 24h/12h time toggle
- **RogueMapView (Prototype)**: map-style route with node snapping + bottom anchor
- **PixelTheme**: unified palette, grid scale, borders, shadows
- **Terrain Tiles**: forest/plains/cave/campfire tiles behind nodes
- **Map Prototype Toggle**: Settings switch to swap Timeline vs Map

### Event System
- **TimelineEventCoordinator**: unified advancement + bonfire suggestion
- **Banner Types**: distraction, rest complete, bonfire suggested

### App State & Stores
- **AppModeManager**: single overlay state machine + transition guards
- **CardTemplateStore / DeckStore**: template and deck sources for DeckOverlay
- **TimelineStore.placeCardOccurrence / placeDeckBatch**: single placement write path
- **DragDropCoordinator**: global drag tracking + hover detection + deck summary

---

## ✅ Phase 12-15 Complete

| Item | Status |
|---|---|
| 12.1-4 UX & Onboarding | ✅ Complete |
| 13.1-3 Event System & Validation | ✅ Complete |
| 14.1 Finished Section Refinements | ✅ Complete |
| 14.2 Hero Task Visuals | ✅ Complete |
| 14.3 Drag/Switch Interactions | ✅ Complete |
| 14.4 Timeline Code Refactoring | ✅ Complete |
| **15.1 Interaction Simplification** | ✅ **Complete** |
| **15.2 Data Reset & Defaults** | ✅ **Complete** |
| **15.3 Bonfire System Optimization** | ✅ **Complete** |

---

## Task Mechanisms Status (v1 / vNext)

### 2.1 已知长度任务（主要已完成）
- 模板卡创建（名称/时长/重复性），拖拽到时间线放置
- 进入 Focus 模式执行（BattleEngine）
- 待补：强制退出拦截 + “未专注完成”提示文案

### 2.2 未知长度任务库 + 同一节点多任务（未实现，需新增机制）
- 需要：任务库/Backlog、FocusGroupOccurrence、Focus 内切换与计时分账
- 退出语义需改为“完成今日探险”

### 2.3 Reminder-only 任务（未实现，可行）
- 需要：remindAt/leadTime 字段 + 时间线倒计时 + in-app 提示

---

## 📋 Next Steps (V1 Final)

- [ ] Duration formatting for timeline nodes (use `TimeFormatter.formatDuration`)
- [ ] Header date display (Mon • Dec 22)
- [ ] Empty state illustration + CTA
- [ ] Audio + haptics polish
- [ ] App icon design
- [ ] Map polish: terrain transitions + snap tuning
- [ ] Deck card visuals: energy color tokens → UI color mapping in app layer

---

## 🔴 Deferred (V2+)

- iOS Calendar sync (EventKit)
- Multi-day browsing
- Advanced pomodoro patterns
- CloudKit sync
