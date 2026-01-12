# Current Project State: TimeLineApp

> **Last Updated**: 2026-01-11
> **Status**: V1 Core Complete + V2 Pixel Healing UI (Phases 16.1-16.4 Complete)

---

## Overview

A roguelike-inspired iOS focus app built with SwiftUI.

| Aspect | Description |
|---|---|
| **Core Loop** | Battle (Focus) → Bonfire (Rest) → Repeat |
| **Design** | Strict Mode (no pause), single-day timeline + Inbox for tomorrow |
| **Tech** | Pure Swift (`TimeLineCore`) + SwiftUI |
| **Persistence** | Local JSON + debounced save (500ms) |
| **Interaction** | Tap to start, Dual Entry (Strict/Todo), drag from TodoSheet, map swipe-to-edit, floating Settings |

---

## Core Functionality + UI + Interactions (Short)

### Core Functionality
- **Timeline engine**: `DaySession` manages nodes, progression, and lock states; `BattleEngine` handles focus timing and outcomes.
- **Template semantics**: `CardTemplate` + `DeckTemplate` are reusable; timeline placement creates occurrences (templates never consumed). `CardTemplate` carries taskMode/repeatRule/fixedTime/remindAt/leadTime/deadlineWindowDays. Inbox stores CardTemplate IDs in `AppState.inbox` with templates persisted in `AppState.cardTemplates`.
- **Write path**: placement uses `TimelineStore.placeCardOccurrence / placeDeckBatch / placeFocusGroupOccurrence` (Inbox/QuickEntry create CardTemplate then place).
- **Task behavior**: `.battle` (Focus/Strict/Flexible) vs `.reminder`. Flexible Tasks (`.passive` style) now behave as open-ended stopwatch battles.
- **Insert Logic**: "Add to Timeline" prioritizes "Insert at Front" (Next Up) over deadline-based backlog placement.
- **App mode**: `AppModeManager` enforces overlay/drag/edit exclusivity.
- **Drag system**: Global "Lift and Drop" reordering fully implemented via `DragDropCoordinator` and Long-Press gesture.
- **Persistence + events**: `AppStateManager` saves; `TimelineEventCoordinator` advances on battle end.
- **Exit rules**: Retreat offers Undo Start ≤60s (no record). Otherwise End & Record → incompleteExit. FocusGroupFlexible uses “End Exploring” and emits completedExploration (no Undo Start).
- **Freeze tokens**: 3/day; Freeze suspends battle and returns to map, resume continues same task; logs duration.
- **Routine decks**: `RoutineTemplate` converts into Decks; no direct DaySession append in UI.

### UI Surfaces
- **RootView**: map layer, Dual Entry Buttons (Strict/Todo), floating Settings + message.
- **RogueMapView**: map route with node snapping, header, and banners. Uses `SwipeableTimelineNode` for swipe-to-edit interactions.
- **GroupFocusView**: focus group nodes open a switchable task list with total focused timer.
- **StrictSheet**: bottom sheet with Cards/Decks tabs for Strict Focus Mode.
- **TodoSheet**: merged "Backlog" + "Quick Add" sheet for flexible tasks; supports multi-selection and "Start Group Focus".
- **QuickBuilderSheet**: fast template creator (no direct timeline writes), supports Task Mode selection（任务模式选择）.
- **DeckDetailEditSheet / CardDetailEditSheet**: long-press edit for Decks and CardTemplates, includes Task Mode selection（任务模式选择）and Library toggle.
- **RoutinePickerView**: Routine Decks list + preview sheet.
- **Exploration report sheet**: completedExploration triggers a finished report (per-task times).
- **Drag ghost + Undo**: deck hover preview + 2s undo toast.
- **Empty drop zone**: drag-to-drop creates first node.
- **SettingsView**: time format toggle.
- **ReminderBanner**: remindAt 触发后弹出“完成 / 稍后 10 分钟”.

### Interaction Flow
- **Dual Entry**: Left = Strict (Cards/Decks), Right = Todo (Backlog/Inbox).
- **Cards → Backlog**: is required for Todo/Group Focus; Strict Mode can drag directly from Cards/Decks.
- **Map Swipe**: Swipe Timeline Node left to Edit / Copy / Delete.
- **Long press** opens template/deck edit sheets; map node long press also triggers Edit.
- **QuickBuilder create** returns to Cards tab with add-to-Backlog hint.
- **Reminder create**: if `remindAt` is set, auto-inserts into timeline by time order.
- **Empty map** accepts drop to create the first node.
- **Drop zones**: only upcoming (non-completed) nodes accept drops.
- **Reminder nodes**: tap completes immediately; in-app ReminderBanner offers Complete / Snooze.
- **Reminder banner**: tap header chevron opens CardTemplate detail (if templateId exists).
- **Reminder edit**: updating `remindAt` repositions the node by time order.
- **Reminder lead time**: QuickBuilder/TaskSheet 支持提前提醒（0/5/10/30/60m）。
- **Timeline countdown**: reminder 节点显示 at HH:mm / in Xm。
- **In-focus countdown**: BattleView / GroupFocusView 顶部显示下一个 Reminder 剩余时间（若存在）。

### Key Types (Core)
- `DaySession`, `TimelineNode`, `Boss`, `BattleEngine`, `AppState`
- `RepeatRule`, `TaskCategory`, `BossStyle`
- `CardTemplate`, `TaskMode`, `TaskBehavior`, `EnergyColorToken`, `RoutineTemplate`
- `FocusGroupPayload`
- `FocusGroupSessionCoordinator`
- `ReminderScheduler`

### Key Types (App Layer)
- `AppModeManager`, `DragDropCoordinator`, `TimelineStore`
- `CardTemplateStore`, `DeckStore`, `DeckTemplate`, `DeckBatchResult`

## ✅ Completed Features

### Core Logic (`TimeLineCore`)
- **BattleEngine**: timer, wasted time, immunity, reconciliation, idempotent finalization
- **SessionResult Publisher**: victory/retreat/incompleteExit/completedExploration events (atomic, data-rich, includes remainingSecondsAtExit)
- **DaySession**: append/move/delete, lock-state recalculation, reset to first upcoming
- **RouteGenerator**: bonfire auto-insertion every N battles
- **DefaultCardTemplates**: stable UUID defaults for card templates
- **SpawnManager**: template spawning + recommended start time passthrough
- **QuickEntryParser**: supports tonight/tomorrow/daily keywords
- **AppState**: `inbox` for tomorrow tasks
- **Card Models**: `CardTemplate` + Deck models (template-driven placement)
- **Energy Tokens**: `EnergyColorToken` stored as token only (no UI color)
- **Flexible Group Core**: `FocusGroupPayload` + `FocusGroupSessionCoordinator` allocations
- **Reminder Core**: `ReminderScheduler` + countdown formatter

### UI
- **RogueMapView**: **Vertical Dashed Line** timeline; **Card Nodes** (White/Rounded) aligned to icons.
- **DeckOverlay**: "Backpack" aesthetic with horizontal spellbook cards.
- **Library tab**: merged into TodoSheet (as Backlog).
- **CardFanView**: Cards styled as **Spellbooks/Scrolls** (Horizontal/White); Orange/Cream theme.
- **TodoSheet**: Notice Board merged with Map aesthetics.
- **QuickBuilderSheet**: Fast template creator.
- **Deck Edit**: Long-press deck to edit.
- **Routine Decks**: Decks tab with specialized "Routine" section.
- **Drag Layer**: Floating card/deck follows global drag.
- **Deck Ghost**: Hover previews insert.
- **Empty Map Drop**: Drop to create first node.
- **Labels**: IN PROGRESS / NEXT UP chips.
- **Settings**: 24h/12h toggle.
- **PixelTheme**: **V2.5 Modern RPG Palette** (Cream `#F9F5EC`, Orange `#F5A623`, White Cards); Clean rounded typography.
- **Terrain Tiles**: Replaced by dashed line.
- **Reminder UX**: Countdown on nodes + In-focus countdown banner.

### Event System
- **TimelineEventCoordinator**: unified advancement + bonfire suggestion
- **Banner Types**: distraction, incomplete exit, exploration complete, rest complete, bonfire suggested, rest prompt (50m focused, actionable)

### App State & Stores
- **AppModeManager**: single overlay state machine + transition guards
- **CardTemplateStore / DeckStore**: template and deck sources for DeckOverlay
- **LibraryStore**: minimal library entries (templateId + addedAt + deadlineStatus), grouped by deadlineWindowDays and reminder status
- **TimelineStore.placeCardOccurrence / placeDeckBatch / placeFocusGroupOccurrence**: single placement write path
- **DragDropCoordinator**: global drag tracking + hover detection + deck summary

---

## ✅ V1 Progress Snapshot

### 已完成
- Flexible Group Focus（多任务组合、总计时不中断、自动分账、GroupFocusView + 报告页基础版）
- Reminder Only（remindAt + Banner + 时间线倒计时 + Focus 内倒计时）
- Map 主流程（地图交互、拖拽放置、节点高亮、Swipe Actions）
- Dual Entry Architecture (Strict Sheet + Todo Sheet)
- Todo/Backlog List (Library 合并 Quick Add, Save to Library)
- Time-based Insertion (TodoSheet 按时间自动插入)
- Enhanced Time Options (Next 3 Days, 智能相对时间)
- Journey Summary (Roguelike 风格, Total Damage, 成就系统)

---

## 🔜 V2–V4 Preview (Planned)

### V2 — Narrative +免疫系统
- Associated App Launch（白名单 URL Scheme + 免疫分心）
- Live Activity / 灵动岛展示
- World Chapters（世界章节 + 节点大小叙事）
- Exploration Report 强化（叙事型结算）

### V3 — Smart Library + 日程（未实现）
- Smart Library（自动分桶 + Stale 折叠 + 排序）
- EventKit 日历同步（软约束时间标签）
- 强制休息（RestPrompt 升级：休息 or 超频）

### V4 — 数据硬化与云端
- SwiftData 迁移（增量保存）
- CloudKit 私有库同步
- 长期历史分析（Heatmap / 成长曲线）

---

## ✅ Phase 12-15 Complete

| Item | Status |
|---|---|
| 12.1-4 UX & Onboarding | ✅ Complete |
| 13.1-3 Event System & Validation | ✅ Complete |
| 14.1 Map Route Visuals | ✅ Complete |
| 14.2 Hero Task Visuals | ✅ Complete |
| 14.3 Drag/Switch Interactions | ✅ Complete |
| 14.4 Timeline Code Refactoring | ✅ Complete |
| **15.1 Interaction Simplification** | ✅ **Complete** |
| **15.2 Data Reset & Defaults** | ✅ **Complete** |
| **15.3 Bonfire System Optimization** | ✅ **Complete** |

---

## Stability & Testing（稳定性与测试）

- **ASan/TSan 崩溃修复**：`TimelineEventCoordinator.stop()` 与 `MapViewModel.stop()` 显式清理异步任务/订阅，避免 deinit 期间的 bad-free。  
- **测试默认运行**：`IncompleteExitBannerTests` 不再需要环境 gate。  
- **测试环境变量**：`timeLine-ci` scheme 的 TestAction 加 `MallocNanoZone=0`，减少模拟器 nano zone 警告。  
- **全量验证**：ASan + TSan + UI Tests 均通过（iPhone 17 Pro 模拟器）。  
- **Core 结构整理**：`TimeLineCore` 已重排为 Domain / Services / Parsing / Persistence / Utilities；`swift test` 通过。  

---

## Task Mechanisms Status (v1 / vNext)

### 2.1 已知长度任务（主要已完成）
- 模板卡创建（名称/时长/重复性），从 Library/Decks 拖拽到时间线放置
- 进入 Focus 模式执行（BattleEngine）
- 待补：强制退出拦截 + “未专注完成”提示文案

### 2.2 未知长度任务库 + 同一节点多任务（未实现，需新增机制）
- 需要：任务库/Backlog、FocusGroupOccurrence、Focus 内切换与计时分账
- 退出语义：completedExploration（End Exploring）已落地，并生成 finished report

### 2.3 Reminder-only 任务（已实现）
- remindAt/leadTime 字段 + in-app ReminderBanner
- 时间线倒计时（at HH:mm / in Xm）
- Focus 界面倒计时提示（BattleView / GroupFocusView）

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
