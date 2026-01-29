# Current Project State: TimeLine (Observation & Collection)

> **Last Updated:** 2026-01-29
> **Version:** 1.1 (Stability + UI + Live Activity)

## 1. Project Overview

**TimeLine** is a calm, observation‑first focus manager. Users arrange tasks along a day timeline, start focused sessions, and record results into a lightweight collection log (Field Journal). The goal is **steady progress, gentle cues, and long‑term clarity**.

### Core Loop (Current)
1. **Plan**: Create tasks (quick input, builder, or library).
2. **Focus**: Start a session and track time (strict or flexible).
3. **Rest**: Accept a soft rest suggestion (50/10 rhythm).
4. **Record**: Session results appear in the Field Journal.
5. **Review**: See day/week/month/year focus stats.

---

## 2. Feature Implementation Status

### ✅ Implemented (Core)

#### 🗺️ Timeline / Map
- **Infinite Timeline** (`RogueMapView`) with inverted ScrollView layout.
- **Global Drag & Drop** with overlay dragging layer.
- **Stable Current Task Anchor** (auto‑scroll to a fixed screen ratio).
- **Jump to Now** floating button (appears when far from anchor).

#### 🧩 Task Creation & Management
- **Quick Entry Parser** (duration + tags + simple time keywords).
- **Quick Builder** (structured task creation for mode/reminders/deadlines).
- **Library / Backlog buckets** (deadline tiers, no‑deadline, frozen/stale, expired).
- **Task Modes**: strict focus, group focus (multi‑task), reminder‑only.

#### 🧠 Focus Engine
- **Session State Machine** (idle / fighting / paused / frozen / resting / victory / retreat).
- **Freeze Tokens** for interruptions.
- **Grace Period** for short backgrounding.
- **50‑minute cue** for gentle rest prompts.

#### 📊 Stats & Journal
- **Day/Week/Month/Year** stats with range navigation.
- **Day line chart** (2‑hour buckets), month heatmap, week/year bars.
- **Field Journal** view after session completion.

#### 🧾 Persistence
- JSON persistence (`PersistenceManager`), 500ms debounce.
- Restore on launch; new‑day reset with auto‑spawn of repeating tasks.

#### 🔔 Live Activity (iOS)
- Live Activity starts on session start and is cleaned up on background/exit.

---

## 3. Project Structure & File Dictionary

### 📂 `timeLine/timeLine`

**App Entry**
- `timeLine/timeLine/TimeLineApp.swift`
- `timeLine/timeLine/AppStateManager.swift`

**State & Coordination**
- `timeLine/timeLine/State/TimelineStore.swift`
- `timeLine/timeLine/TimelineEventCoordinator.swift`

**Views**
- Map: `timeLine/timeLine/Views/Map/*`
- Focus: `timeLine/timeLine/Views/Battle/*` (legacy naming; focus session UI)
- Rest: `timeLine/timeLine/Views/BonfireView.swift` (legacy naming; rest UI)
- Stats: `timeLine/timeLine/Views/Stats/*`
- Settings: `timeLine/timeLine/Views/Settings/*`

### 📂 `TimeLineCore`

**Domain Models**
- `TimeLineCore/Sources/TimeLineCore/Domain/*`

**Services**
- `TimeLineCore/Sources/TimeLineCore/Services/BattleEngine.swift`
- `TimeLineCore/Sources/TimeLineCore/Services/SpawnManager.swift`
- `TimeLineCore/Sources/TimeLineCore/Services/LiveActivityManager.swift`

**Persistence**
- `TimeLineCore/Sources/TimeLineCore/Persistence/PersistenceManager.swift`

---

## 4. Key Implementation Details (Accurate to Code)

### 4.1 Drag & Drop
- Drag proxy rendered in overlay to avoid layout drift.
- Hover target tracking uses global frames and a ghost node placeholder.

### 4.2 Timeline Anchoring
- Current task auto‑scrolls to a fixed ratio in `TimelineListView` (`fixedTopTargetRatio = 0.65`).
- `MapViewModel.mapAnchorY()` now uses the same ratio to keep padding and anchoring consistent.

### 4.3 Event Flow
- `BattleEngine` emits `SessionResult` → `TimelineEventCoordinator` advances `DaySession` and publishes UI events.
- Coordinator handles reminders, rest suggestions, and settlement trigger.

### 4.4 Persistence & Restore
- App state saved as JSON; restore also reconciles day change and repeats.
- `AppStateManager` clamps invalid indices before saving.

### 4.5 Live Activity Sync
- Live Activity starts on session start; `syncLiveActivity()` keeps it consistent on app lifecycle changes.

---

## 5. Recent Changes (Jan 29, 2026)

- Added Light/Dark/System appearance toggle and applied globally.
- Simplified auto‑scroll (anchor‑based only) and added a soft “Now” button.
- Fixed edit mode: edit/delete controls now receive taps even with drag overlay.
- Live Activity now ends/starts correctly when app background/foreground changes.
