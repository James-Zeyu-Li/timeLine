# Current Project State: TimeLineApp

> **Last Updated**: 2025-12-30 (稳定性与测试修复已同步)  
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
| **Interaction** | Tap to start, DeckOverlay bottom sheet (Cards/Library/Decks), drag from Library/Decks, edit via sheet, floating Add/Settings |

---

## Core Functionality + UI + Interactions (Short)

### Core Functionality
- **Timeline engine**: `DaySession` manages nodes, progression, and lock states; `BattleEngine` handles focus timing and outcomes.
- **Template semantics**: `CardTemplate` + `DeckTemplate` are reusable; timeline placement creates occurrences (templates never consumed). `CardTemplate` carries taskMode/repeatRule/fixedTime/remindAt/leadTime/deadlineWindowDays. Inbox stores CardTemplate IDs in `AppState.inbox` with templates persisted in `AppState.cardTemplates`.
- **Write path**: placement uses `TimelineStore.placeCardOccurrence / placeDeckBatch / placeFocusGroupOccurrence` (Inbox/QuickEntry create CardTemplate then place).
- **Task behavior**: `.battle` vs `.reminder`（remindAt / legacy passive / reminderOnly 都映射为 reminder）。Reminder 不进入 BattleView。
- **App mode**: `AppModeManager` enforces overlay/drag/edit exclusivity.
- **Drag system**: `DragDropCoordinator` handles global coords + hover targeting; drop targets are upcoming (non-completed) nodes.
- **Persistence + events**: `AppStateManager` saves; `TimelineEventCoordinator` advances on battle end.
- **Exit rules**: Retreat offers Undo Start ≤60s (no record). Otherwise End & Record → incompleteExit. FocusGroupFlexible uses “End Exploring” and emits completedExploration (no Undo Start).
- **Freeze tokens**: 3/day; Freeze suspends battle and returns to map, resume continues same task; logs duration.
- **Routine decks**: `RoutineTemplate` converts into Decks; no direct DaySession append in UI.

### UI Surfaces
- **RootView**: map layer, DeckOverlay, drag layer, edit sheets, floating Add/Settings + message.
- **RogueMapView**: map route with node snapping, header, and banners.
- **GroupFocusView**: focus group nodes open a switchable task list with total focused timer.
- **DeckOverlay** + **CardFanView**: bottom sheet overlay with Cards/Library/Decks tabs; Cards add to Library (tap or multi-select).
- **Library tab**: long-press drag a single task to map; Select mode shows Add to Group + drag token for group placement; sections are `Reminders`, `1/3/5/7 Days`, `Later`, `Expired`（按 deadlineWindowDays 分桶 + 过期折叠）。
- **QuickBuilderSheet**: fast template creator (no direct timeline writes), supports Task Mode selection（任务模式选择）.
- **DeckDetailEditSheet / CardDetailEditSheet**: long-press edit for Decks and CardTemplates, includes Task Mode selection（任务模式选择）and Library toggle.
- **RoutinePickerView**: Routine Decks list + preview sheet.
- **Exploration report sheet**: completedExploration triggers a finished report (per-task times).
- **Drag ghost + Undo**: deck hover preview + 2s undo toast.
- **Empty drop zone**: drag-to-drop creates first node.
- **SettingsView**: time format toggle.
- **ReminderBanner**: remindAt 触发后弹出“完成 / 稍后 10 分钟”.

### Interaction Flow
- **+ Add → DeckOverlay** is the primary creation surface.
- **Cards → Library** is required before placement; drag from Library or Decks to create occurrences via `TimelineStore`.
- **Deck hover** shows “Insert N / Est. X”; drop inserts batch + Undo.
- **Long press** opens template/deck edit sheets; map node long press opens TaskSheet for node edit.
- **QuickBuilder create** returns to Cards tab with add-to-Library hint.
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
- **RogueMapView**: pinned header, event banners, pulse effects, node snapping
- **DeckOverlay**: Cards / Library / Decks tabs in a bottom sheet
- **Library tab**: long-press drag to map; Select mode enables Add to Group and a draggable group token (drop to insert; quick append still places at end); deadlineWindowDays buckets + Expired 折叠区
- **CardFanView**: tap to add to Library; long-press edit
- **QuickBuilderSheet**: Add Card button opens quick template creator (no direct timeline writes)
- **Deck Edit**: long-press deck → rename + reorder + add/remove cards
- **Routine Decks**: Decks tab top strip + See All picker
- **Drag Layer**: floating card/deck follows global drag location
- **Deck Ghost + Undo**: hover shows insert summary; drop creates batch + undo toast
- **Empty Map Drop**: drag-to-drop auto-creates first node
- **Floating Controls**: Add + Settings buttons + floating message
- **Inbox Section**: tomorrow tasks stored outside today
- **Labels**: FIRST / NEXT / STARTED status tags
- **Recommended Time**: RECOMMENDED label from `Boss.recommendedStart`
- **Settings**: 24h/12h time toggle
- **PixelTheme**: unified palette, grid scale, borders, shadows
- **Terrain Tiles**: forest/plains/cave/campfire tiles behind nodes
- **Reminder UX**: timeline countdown + in-focus countdown + banner → detail jump

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
- Map 主流程（地图交互、拖拽放置、节点高亮、事件提示）
- Focus List 主入口（Timeline 底部入口 + ad-hoc 输入 + Start Focus）
- Focus List Store（staged items + ad-hoc staging）
- Ephemeral Cleanup（新的一天自动清理未保存临时模板）

### 未完成（V1 关键缺口）
- Focus List：从 Cards / Library / Decks 加入 + 可排序/删除
- In Focus (n) 占用态显示（Library 折叠区 + 地图 Exploring 标记）
- ad-hoc → isEphemeral → 收藏/留存流程

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
