# Current Project State: TimeLine (Focus RPG)

> **Last Updated:** 2026-01-25
> **Version:** 1.0 (In Development)

## 1. Project Overview

**TimeLine** is a gamified focus management application that combines strict time-blocking with RPG mechanics (Rogue-like progression). Users plan their day as a "Quest Line" (Timeline), battle distractions (Focus Sessions), and rest at Bonfires (Breaks).

### Core Gameplay Loop
1.  **Plan (Deck Builder)**: Build your day using "Cards" (Tasks) from your Deck/Library.
2.  **Focus (Battle)**: Execute tasks. Time passing = Damage to Boss. Distractions = Player taking damage.
3.  **Reward (Loot)**: Completing tasks grants XP and Items (Cards).
4.  **Rest (Bonfire)**: Strategic breaks to recover HP (Stamina).

---

## 2. Feature Implementation Status

### ✅ Implemented (V1 Core)
*   **Infinite Scrolling Timeline (`RogueMapView`)**: Vertical timeline of tasks (Future -> Current -> Completed).
*   **Global Drag & Drop System**:
    *   **Card to Timeline**: Drag new tasks from `DeckOverlay` to Map.
    *   **Reordering**: Drag existing tasks within the Timeline using a **Global Visual Proxy** (solves layout drifting).
    *   **Multi-Select Drag**: Drag "Focus Groups" (multiple cards) at once.
*   **Deck System (`DeckOverlay`)**:
    *   **Library**: All available task templates (`CardFanView`).
    *   **Decks**: Pre-built routines (Morning Routine, Deep Work Block).
    *   **Hand Management**: Card fanning and selection logic.
*   **Battle Engine (`BattleEngine`)**:
    *   State machine: `Idle` -> `Fighting` -> `Paused` -> `Victory` -> `Resting`.
    *   real-time timer countdown.
*   **Persistence**: `StateSaver` protocol and JSON-based restoration (implied via `AppStateManager`).

### 🚧 In Progress / Planned
*   **Phase 19: Ambient Companion**: A dedicated "Pet" or "Spirit" that reacts to your focus state.
*   **Phase 20: Settlement**: Visual progression of your base/city based on productivity.

---

## 3. Project Structure & File Dictionary

### 📂 `timeLine/timeLine` (Root Source)

#### 3.1 App Entry
*   **`TimeLineApp.swift`**: Main generic entry point. Sets up the Environment Objects (`AppStateManager`, `BattleEngine`, etc.).
*   **`TestAppEntryPoint.swift`**: Test-specific entry point configuration.
*   **`AppStateManager.swift`**: The "Save File" manager. Handles serialization of the entire app state (`DaySession`, `Stores`) to disk.
*   **`TimelineEventCoordinator.swift`**: Central message bus for UI events (e.g., "Show Toast", "Trigger Haptics") decoupling Logic from Views.
*   **`TimelineEvents.swift`**: Enum definitions for the Coordinator events.

#### 3.2 📂 `State` (Data & Logic Layer)
*   **`AppModeManager.swift`**: Controls the high-level UI mode state machine (`home`, `deckOverlay`, `dragging`, `cardEdit`, `focusMode`).
*   **`BattleExitPolicy.swift`**: Logic for what happens when a session ends (Victory vs Retreat calculations).
*   **`CardTemplateStore.swift`**: The "Database" of all Task Definitions (Templates) and the User's Library.
*   **`DeckStore.swift`**: Manages "Decks" (Collections of Cards/Routines).
*   **`DragDropCoordinator.swift`**: **[CRITICAL]** The "Brain" of the Drag system. Tracks touch location globally and manages the `DragPayload`.
*   **`DragPayload.swift`**: Data struct defining *what* is being dragged (`.card`, `.node`, `.deck`).
*   **`StateSaver.swift`**: Protocol definition for persistence behavior.
*   **`TimelineStore.swift`**: Manages the logic of adding/removing/moving nodes in the `DaySession`. The "Controller" for the data model.

#### 3.3 📂 `Views` (UI Layer)

**Root**
*   **`RootView.swift`**: **[CRITICAL]** The Main View.
    *   Holds the high-level `ZStack`.
    *   Manages the **Global Drag Layer** (renders `DraggingNodeView` on top of everything).
    *   Injects all EnvironmentObjects.

**📂 `Views/Map` (The Timeline / Game Board)**
*   **`RogueMapView.swift`**: The infinite scrolling list. Handles `ScrollViewReader` and `mapAnchorY` (Visual Anchor Point).
*   **`TimelineNodeRow.swift`**: **[CRITICAL]** Represents a single Task Row.
    *   Contains the **Local Drag Gesture** (Sequence: LongPress -> Drag).
    *   Capture's `initialOffset` for smooth dragging.
    *   Hides itself (`opacity: 0`) when being dragged.
*   **`DraggingNodeView.swift`**: **[CRITICAL]** The Visual Proxy.
    *   This is the "Ghost" view that users see under their finger during a reorder drag.
    *   Lives in `RootView`'s overlay, structurally detached from the ScrollView.
*   **`MapViewModel.swift`**: View logic for the Map (computed properties for rendering).
*   **`MapTypes.swift` / `MapLayout.swift`**: Helpers for layout constants (node height, padding).
*   **`Components/`**: Smaller sub-views (e.g., `PathLine`, `NodeIcon`).

**📂 `Views/Deck` (Inventory & Supply)**
*   **`DeckOverlay.swift`**: The slide-over sheet containing Cards and Decks.
*   **`CardFanView.swift`**: The "Hand" view. Displays cards in a fan or grid.
*   **`DraggingCardView.swift`**: Visual proxy for dragging a *new* card from the deck.
*   **`DraggingDeckView.swift`**: Visual proxy for dragging an entire *deck*.
*   **`DraggingGroupView.swift`**: Visual proxy for dragging multiple items.
*   **`CardLibrarySelectionView.swift`**: List view for selecting multiple cards from the library.
*   **`RoutinePickerView.swift`** / **`DeckDetailEditSheet.swift`**: Editors for Decks.

**📂 `Views/Plan` (Quick Entry)**
*   **`PlanSheetView.swift`**: The specific UI for "Planning Mode" (a dedicated sheet for rapid task entry).
*   **`MagicInputBar.swift`**: Natural language input field (e.g., "Read book for 30m").

**📂 `Views/Battle` (Execution Mode)**
*   **`BattleView.swift`**: The Active Focus Screen. Shows Timer, Boss HP, and "Give Up" button.
*   **`BonfireView.swift`**: The Rest Screen. Shows Break Timer and HP Recovery.

**📂 `Views/Shared` (Common Components)**
*   **`InfoBanner.swift`**, **`ReminderBanner.swift`**: Notification toasts.
*   **`QuickBuilderSheet.swift`**: Simplified card creator.

---

## 4. Key Implementation Details

### 4.1 Global Drag Proxy System (The "Smooth Drag" Fix)
*   **Problem**: Dragging an item *inside* a ScrollView while the ScrollView is scrolling/shifting causes the item to "drift" from under your finger (Coordinate Space mismatch).
*   **Solution**:
    1.  **Source (`TimelineNodeRow`)**: Detects drag. Hides itself (`opacity: 0`). Calculates `offset` (Finger - Center).
    2.  **State (`DragDropCoordinator`)**: Stores the Global Coordinate of the touch and the Item ID.
    3.  **Proxy (`RootView` + `DraggingNodeView`)**: Renders a *copy* of the item in the Root Overlay.
    4.  **Math**: `ProxyPosition = GlobalTouchPosition + InitialOffset`.
    *Result*: The item is visually "pinned" to the screen glass, independent of the underlying list.

### 4.2 Timeline Anchoring
*   **Problem**: In an infinite timeline (Past -> Future), where should the user be looking?
*   **Solution**: `mapAnchorY` in `RogueMapView`.
    *   **Value**: `0.7` (70% down the screen).
    *   **Effect**: The "Current Task" is kept near the bottom, allowing maximizing visibility of "Future Tasks" (which flow upwards).

### 4.3 Persistence (StateSaver)
*   The app uses a snapshot-based save system.
*   Critically, `DaySession` (The Timeline) is serialized to JSON.
*   On launch, `AppStateManager` restores `DaySession`.
*   Note: `UUID` stability is key for persistence.
