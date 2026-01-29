# Current Project State: TimeLine (Focus RPG)

> **Last Updated:** 2026-01-29
> **Version:** 1.1 (Stats Update)

## 1. Project Overview

**TimeLine** is a gamified focus management application that combines strict time-blocking with RPG mechanics (Rogue-like progression). Users plan their day as a "Quest Line" (Timeline), battle distractions (Focus Sessions), and rest at Bonfires (Breaks).

### Core Gameplay Loop
1.  **Plan (Deck Builder)**: Build your day using "Cards" (Tasks) from your Deck/Library.
2.  **Focus (Battle)**: Execute tasks. Time passing = Damage to Boss. Distractions = Player taking damage.
3.  **Reward (Loot)**: Completing tasks grants XP and Items (Cards).
4.  **Rest (Bonfire)**: Strategic breaks to recover HP (Stamina).
5.  **Review (Stats)**: Analyze performance across Day, Week, Month, and Year.

---

## 2. Feature Implementation Status

### ✅ Implemented (V1 Core)

#### 🗺️ Map & Timeline
*   **Infinite Scrolling Timeline (`RogueMapView`)**: Vertical timeline of tasks.
*   **Global Drag & Drop**: Smooth reordering and dragging from DeckOverlay.
*   **Anchored Scrolling**: "Current Task" anchored at 75% screen height.

#### 🃏 Deck & Tasks
*   **Deck System**: Library, Decks, and Hand management.
*   **Magic Input**: "Natural Language" style task entry (parsing basic duration/title).

#### ⚔️ Battle Engine
*   **Focus Session**: Real-time battle timer.
*   **Rest System**: Bonfire breaks logic.

#### 📊 Stats & Progression
*   **Multi-View Analysis**:
    *   **Day**: Line Chat (2-hour buckets) for daily focus distribution.
    *   **Week**: Bar chart summary.
    *   **Month**: Heatmap visualization.
    *   **Year**: 12-month bar chart breakdown.
*   **Navigation**: Time travel (Previous/Next) for all stat ranges.
*   **XP & Levels**: Basic leveling system based on focus time.

### 🚧 In Progress / Planned
*   **Phase 19: Ambient Companion**: A dedicated "Pet" or "Spirit" that reacts to your focus state.
*   **Phase 20: Settlement**: Visual progression of your base/city based on productivity.
*   **Routine Builder**: More advanced tools for creating recurring task "Packs".

---

## 3. Project Structure & File Dictionary

### 📂 `timeLine/timeLine` (Root Source)

#### 3.1 App Entry
*   **`TimeLineApp.swift`**: Main entry point.
*   **`AppStateManager.swift`**: Persistence manager (JSON state).

#### 3.2 📂 `State` (Logic)
*   **`StatsViewModel.swift`**: **[UPDATED]** Handles data aggregation for Day/Week/Month/Year stats and navigation state.
*   **`TimelineStore.swift`**: Core data controller for the DaySession.
*   **`BattleEngine.swift`**: Executing task logic.

#### 3.3 📂 `Views` (UI)

**Stats**
*   **`AdventurerLogView.swift`**: Main stats container with Navigation Header and Range Picker.
*   **`AdventurerLogView_Components.swift`**:
    *   `AdventurerDayLineChart`: **[NEW]** Daily focus distribution path.
    *   `AdventurerMonthHeatmap`: Monthly activity grid.
    *   `AdventurerRangeChart`: Bar charts for Week/Year.

**Map**
*   **`TimelineListView.swift`**: Main list rendering logic.
*   **`MapViewModel.swift`**: View logic for layout and anchoring.

---

## 4. Key Implementation Details

### 4.1 Global Drag Proxy System
Solved layout drifting during drag by decoupling the dragged view (`DraggingNodeView`) from the ScrollView and placing it in a root Overlay, using Global Coordinates.

### 4.2 Timeline Anchoring
The "Current Task" is visually anchored at `0.75` (75% down) of the viewport height to maximize visibility of upcoming tasks (which flow upwards).

### 4.3 Stats Data Aggregation
*   **Source**: `DailyFunctionality` (historical summaries) and `SpecimenCollection` (granular task logs).
*   **Day Chart**: Derives hourly buckets by processing `CollectedSpecimen` durations.
