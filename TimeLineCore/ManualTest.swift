import Foundation

// We need to make sure we can see the internal types if we were in the same module, 
// but since we compile together, it should be fine.

// Mock Boss
let boss = Boss(name: "Test Boss", maxHp: 60)
let engine = BattleEngine()

print("--- Starting Manual Verification ---")

// Monitor
var cancellable = engine.$state.sink { state in
    print("State changed to: \(state)")
}

// 1. Start Battle
print("[Test] Starting Battle...")
let startTime = Date()
engine.startBattle(boss: boss, at: startTime)
assert(engine.state == .fighting, "State should be fighting")
assert(engine.currentBoss?.currentHp == 60, "HP should be 60")
print("✅ Start Battle Passed")

// 2. Tick Logic
print("[Test] Ticking 10s...")
let tenSecondsLater = startTime.addingTimeInterval(10)
engine.tick(at: tenSecondsLater)
if let hp = engine.currentBoss?.currentHp {
     print("Current HP: \(hp)")
     assert(abs(hp - 50) < 0.1, "HP should be 50")
} else {
    assertionFailure("Boss missing")
}
print("✅ Tick Logic Passed")

// 3. Pause
print("[Test] Pausing...")
engine.pause(at: tenSecondsLater)
assert(engine.state == .paused, "State should be paused")
print("✅ Pause Passed")

// 4. Resume
print("[Test] Resuming after 20s...")
let resumeTime = tenSecondsLater.addingTimeInterval(20)
engine.resume(at: resumeTime)
assert(engine.state == .fighting, "State should be fighting")
print("✅ Resume Passed")

// 5. Victory
print("[Test] Checking Victory...")
let finishTime = resumeTime.addingTimeInterval(51) // 50 left + 1 buffer
engine.tick(at: finishTime)
assert(engine.state == .victory, "State should be victory")
assert(engine.currentBoss?.currentHp == 0, "HP should be 0")
print("✅ Victory Passed")

print("🎉 ALL TESTS PASSED")
