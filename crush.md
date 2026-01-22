
-------------------------------------
Translated Report (Full Report Below)
-------------------------------------
Process:             timeLine [96358]
Path:                /Users/USER/Library/Developer/CoreSimulator/Devices/2BE3E771-EFE0-4305-9889-D4347DAB80D8/data/Containers/Bundle/Application/880883B5-522C-492F-8588-078363B2765B/timeLine.app/timeLine
Identifier:          personal.timeLine
Version:             1.0 (1)
Code Type:           ARM-64 (Native)
Role:                Foreground
Parent Process:      launchd_sim [96128]
Coalition:           com.apple.CoreSimulator.SimDevice.2BE3E771-EFE0-4305-9889-D4347DAB80D8 [165815]
Responsible Process: SimulatorTrampoline [92731]
User ID:             501

Date/Time:           2026-01-22 11:49:12.3991 -0800
Launch Time:         2026-01-22 11:17:59.6821 -0800
Hardware Model:      Mac14,9
OS Version:          macOS 26.2 (25C56)
Release Type:        User

Crash Reporter Key:  E1C6602B-FD20-0B3A-C7E6-B3355E7E2549
Incident Identifier: 96F97BFC-A48D-4995-A061-E2CE632C3612

Sleep/Wake UUID:       075F3D84-CB0F-49AF-B33E-58DC40F43A9A

Time Awake Since Boot: 1000000 seconds
Time Since Wake:       1095932 seconds

System Integrity Protection: enabled

Triggered by Thread: 0, Dispatch Queue: com.apple.main-thread

Exception Type:    EXC_BREAKPOINT (SIGTRAP)
Exception Codes:   0x0000000000000001, 0x000000019772c2ec

Termination Reason:  Namespace SIGNAL, Code 5, Trace/BPT trap: 5
Terminating Process: exc handler [96358]


Thread 0 Crashed::  Dispatch queue: com.apple.main-thread
0   libswiftCore.dylib            	       0x19772c2ec _assertionFailure(_:_:file:line:flags:) + 156
1   SwiftUICore                   	       0x1db33a938 specialized EnvironmentObject.error() + 264
2   SwiftUICore                   	       0x1db33a958 specialized EnvironmentObject.wrappedValue.getter + 28
3   SwiftUICore                   	       0x1db339ebc EnvironmentObject.wrappedValue.getter + 12
4   timeLine.debug.dylib          	       0x105b91264 TodoSheet.dragCoordinator.getter + 96
5   timeLine.debug.dylib          	       0x105bae584 TodoSheet.cancelButton.getter + 3292 (TodoSheet.swift:372)
6   timeLine.debug.dylib          	       0x105bab8bc closure #1 in TodoSheet.actionBar.getter + 576 (TodoSheet.swift:324)
7   SwiftUICore                   	       0x1dafd4410 <deduplicated_symbol> + 88
8   SwiftUICore                   	       0x1db45c5e0 _VariadicView.Tree.init(_:content:) + 112
9   SwiftUICore                   	       0x1db36fc38 HStack.init(alignment:spacing:content:) + 76
10  timeLine.debug.dylib          	       0x105b96c78 TodoSheet.actionBar.getter + 808 (TodoSheet.swift:323)
11  timeLine.debug.dylib          	       0x105b95350 closure #1 in TodoSheet.body.getter + 2076 (TodoSheet.swift:65)
12  SwiftUICore                   	       0x1dafd4410 <deduplicated_symbol> + 88
13  SwiftUICore                   	       0x1db45c5e0 _VariadicView.Tree.init(_:content:) + 112
14  SwiftUICore                   	       0x1db1503a0 VStack.init(alignment:spacing:content:) + 76
15  timeLine.debug.dylib          	       0x105b943f8 TodoSheet.body.getter + 796 (TodoSheet.swift:56)
16  timeLine.debug.dylib          	       0x105bbe024 protocol witness for View.body.getter in conformance TodoSheet + 12
17  SwiftUICore                   	       0x1db33e7d0 closure #1 in ViewBodyAccessor.updateBody(of:changed:) + 1436
18  SwiftUICore                   	       0x1db33e204 ViewBodyAccessor.updateBody(of:changed:) + 180
19  SwiftUICore                   	       0x1db33e8f0 protocol witness for BodyAccessor.updateBody(of:changed:) in conformance ViewBodyAccessor<A> + 12
20  SwiftUICore                   	       0x1db466fc8 closure #1 in DynamicBody.updateValue() + 856
21  SwiftUICore                   	       0x1db4669b4 DynamicBody.updateValue() + 836
22  SwiftUICore                   	       0x1db1d88e0 partial apply for implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 28
23  AttributeGraph                	       0x1c4794728 AG::Graph::UpdateStack::update() + 492
24  AttributeGraph                	       0x1c4794e18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
-------- RECURSION LEVEL 10
25  AttributeGraph                	       0x1c479c54c AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long) + 668
26  AttributeGraph                	       0x1c47b41cc AGGraphGetValue + 236
27  SwiftUICore                   	       0x1db0c9780 specialized DynamicViewList.updateValue() + 84
28  SwiftUICore                   	       0x1db0d4e60 specialized implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 20
29  AttributeGraph                	       0x1c4794728 AG::Graph::UpdateStack::update() + 492
30  AttributeGraph                	       0x1c4794e18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
-------- RECURSION LEVEL 9
31  AttributeGraph                	       0x1c479c54c AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long) + 668
32  AttributeGraph                	       0x1c47b41cc AGGraphGetValue + 236
33  SwiftUICore                   	       0x1db5b38f0 specialized implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 160
34  AttributeGraph                	       0x1c4794728 AG::Graph::UpdateStack::update() + 492
35  AttributeGraph                	       0x1c4794e18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
-------- RECURSION LEVEL 8
--------
-------- ELIDED 4 LEVELS OF RECURSION THROUGH 0x1c4794e18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
--------
72  AttributeGraph                	       0x1c479c54c AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long) + 668
73  AttributeGraph                	       0x1c47b41cc AGGraphGetValue + 236
74  SwiftUICore                   	       0x1db0af978 specialized DynamicContainerInfo.updateItems(disableTransitions:) + 92
75  SwiftUICore                   	       0x1db0ae838 specialized DynamicContainerInfo.updateValue() + 424
76  SwiftUICore                   	       0x1db0d4230 specialized implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 20
77  AttributeGraph                	       0x1c4794728 AG::Graph::UpdateStack::update() + 492
78  AttributeGraph                	       0x1c4794e18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
-------- RECURSION LEVEL 3
79  AttributeGraph                	       0x1c479c54c AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long) + 668
80  AttributeGraph                	       0x1c47b41cc AGGraphGetValue + 236
81  SwiftUICore                   	       0x1db4f0bc4 DynamicPreferenceCombiner.info.getter + 80
82  SwiftUICore                   	       0x1db4f0cb8 DynamicPreferenceCombiner.value.getter + 140
83  SwiftUICore                   	       0x1db4ff154 implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 148
84  AttributeGraph                	       0x1c4794728 AG::Graph::UpdateStack::update() + 492
85  AttributeGraph                	       0x1c4794e18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
-------- RECURSION LEVEL 2
86  AttributeGraph                	       0x1c479c54c AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long) + 668
87  AttributeGraph                	       0x1c47b41cc AGGraphGetValue + 236
88  SwiftUICore                   	       0x1db19ed20 PairPreferenceCombiner.value.getter + 96
89  SwiftUICore                   	       0x1db4ff154 implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:) + 148
90  AttributeGraph                	       0x1c4794728 AG::Graph::UpdateStack::update() + 492
91  AttributeGraph                	       0x1c4794e18 AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int) + 352
-------- RECURSION LEVEL 1
92  AttributeGraph                	       0x1c479bc58 AG::Graph::value_ref(AG::AttributeID, unsigned int, AGSwiftMetadata const*, unsigned char&) + 260
93  AttributeGraph                	       0x1c47b450c AGGraphGetWeakValue + 368
94  SwiftUICore                   	       0x1db697ee8 GraphHost.preferenceValue<A>(_:) + 504
95  SwiftUICore                   	       0x1dba8a100 partial apply for closure #1 in ViewGraphRootValueUpdater._preferenceValue<A>(_:) + 32
96  SwiftUICore                   	       0x1dba87068 ViewGraphRootValueUpdater._updateViewGraph<A>(body:) + 200
97  SwiftUICore                   	       0x1dba84e4c ViewGraphRootValueUpdater._preferenceValue<A>(_:) + 180
98  SwiftUI                       	       0x1da1e66b4 specialized PresentationHostingController.setupDelayIfNeeded() + 140
99  SwiftUI                       	       0x1da1070e4 SheetBridge.present(_:from:animated:existingPresentedVC:isPreempting:) + 1008
100 SwiftUI                       	       0x1da1089c8 SheetBridge.contingentlyPresent(_:from:animated:) + 1364
101 SwiftUI                       	       0x1da016d60 specialized SheetBridge.preferencesDidChange(_:) + 5504
102 SwiftUI                       	       0x1da012024 _UIHostingView.preferencesDidChange() + 1136
103 SwiftUICore                   	       0x1dba917bc specialized update #1 () in ViewGraph.updateOutputs(async:) + 304
104 SwiftUICore                   	       0x1dba8bf94 ViewGraph.updateOutputs(at:) + 484
105 SwiftUICore                   	       0x1dba8612c closure #1 in ViewGraphRootValueUpdater.render(interval:updateDisplayList:targetTimestamp:) + 644
106 SwiftUICore                   	       0x1dba84858 ViewGraphRootValueUpdater.render(interval:updateDisplayList:targetTimestamp:) + 420
107 UIKitCore                     	       0x1852f9198 0x18519e000 + 1421720
108 SwiftUI                       	       0x1dab25470 _UIHostingView.layoutSubviews() + 80
109 SwiftUI                       	       0x1dab254a4 @objc _UIHostingView.layoutSubviews() + 32
110 UIKitCore                     	       0x18558294c 0x18519e000 + 4081996
111 UIKitCore                     	       0x185582ce0 0x18519e000 + 4082912
112 UIKitCore                     	       0x1869151c8 -[UIView(CALayerDelegate) layoutSublayersOfLayer:] + 2656
113 QuartzCore                    	       0x18c7e7ff8 CA::Layer::perform_update_(CA::Layer*, CALayer*, unsigned int, CA::LayerUpdateReason, CA::Transaction*) + 452
114 QuartzCore                    	       0x18c7e7848 CA::Layer::update_if_needed_(CA::Transaction*, CA::LayerUpdateReason) + 600
115 QuartzCore                    	       0x18c7f34d8 CA::Layer::layout_and_display_if_needed(CA::Transaction*) + 152
116 QuartzCore                    	       0x18c7089fc CA::Context::commit_transaction(CA::Transaction*, double, double*) + 544
117 QuartzCore                    	       0x18c738b54 CA::Transaction::commit() + 636
118 QuartzCore                    	       0x18c73a3fc CA::Transaction::flush_as_runloop_observer(bool) + 68
119 UIKitCore                     	       0x186346ca0 _UIApplicationFlushCATransaction + 48
120 UIKitCore                     	       0x186263c48 __setupUpdateSequence_block_invoke_2 + 372
121 UIKitCore                     	       0x18582f378 _UIUpdateSequenceRunNext + 120
122 UIKitCore                     	       0x1862640a4 schedulerStepScheduledMainSectionContinue + 56
123 UpdateCycle                   	       0x2501912b4 UC::DriverCore::continueProcessing() + 80
124 CoreFoundation                	       0x1804563a4 __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__ + 24
125 CoreFoundation                	       0x1804562ec __CFRunLoopDoSource0 + 168
126 CoreFoundation                	       0x180455a78 __CFRunLoopDoSources0 + 220
127 CoreFoundation                	       0x180454c4c __CFRunLoopRun + 760
128 CoreFoundation                	       0x18044fcec _CFRunLoopRunSpecificWithOptions + 496
129 GraphicsServices              	       0x192a669bc GSEventRunModal + 116
130 UIKitCore                     	       0x186348574 -[UIApplication _run] + 772
131 UIKitCore                     	       0x18634c79c UIApplicationMain + 124
132 SwiftUI                       	       0x1da58d620 closure #1 in KitRendererCommon(_:) + 164
133 SwiftUI                       	       0x1da58d368 runApp<A>(_:) + 180
134 SwiftUI                       	       0x1da31b42c static App.main() + 148
135 timeLine.debug.dylib          	       0x105dc5c4c static AppEntryPoint.main() + 128 (TimeLineApp.swift:14)
136 timeLine.debug.dylib          	       0x105dc648c static AppEntryPoint.$main() + 12
137 timeLine.debug.dylib          	       0x105dcde9c __debug_main_executable_dylib_entry_point + 12
138 ???                           	       0x104b4d3d0 ???
139 dyld                          	       0x104decd54 start + 7184

Thread 1:: com.apple.uikit.eventfetch-thread
0   libsystem_kernel.dylib        	       0x104adcb70 mach_msg2_trap + 8
1   libsystem_kernel.dylib        	       0x104aed90c mach_msg2_internal + 72
2   libsystem_kernel.dylib        	       0x104ae4c10 mach_msg_overwrite + 480
3   libsystem_kernel.dylib        	       0x104adcee4 mach_msg + 20
4   CoreFoundation                	       0x180455c04 __CFRunLoopServiceMachPort + 156
5   CoreFoundation                	       0x180454dbc __CFRunLoopRun + 1128
6   CoreFoundation                	       0x18044fcec _CFRunLoopRunSpecificWithOptions + 496
7   Foundation                    	       0x18110be48 -[NSRunLoop(NSRunLoop) runMode:beforeDate:] + 208
8   Foundation                    	       0x18110c068 -[NSRunLoop(NSRunLoop) runUntilDate:] + 60
9   UIKitCore                     	       0x18609fc50 -[UIEventFetcher threadMain] + 392
10  Foundation                    	       0x181132d14 __NSThread__start__ + 716
11  libsystem_pthread.dylib       	       0x104cae5ac _pthread_start + 104
12  libsystem_pthread.dylib       	       0x104ca9998 thread_start + 8

Thread 2:: com.apple.UIKit.inProcessAnimationManager
0   libsystem_kernel.dylib        	       0x104adcaec semaphore_wait_trap + 8
1   libdispatch.dylib             	       0x1801c2258 _dispatch_sema4_wait + 24
2   libdispatch.dylib             	       0x1801c27e0 _dispatch_semaphore_wait_slow + 128
3   UIKitCore                     	       0x1856619c0 0x18519e000 + 4995520
4   UIKitCore                     	       0x185665e88 0x18519e000 + 5013128
5   UIKitCore                     	       0x1852f85d0 0x18519e000 + 1418704
6   Foundation                    	       0x181132d14 __NSThread__start__ + 716
7   libsystem_pthread.dylib       	       0x104cae5ac _pthread_start + 104
8   libsystem_pthread.dylib       	       0x104ca9998 thread_start + 8

Thread 3:

Thread 4::  Dispatch queue: com.apple.root.utility-qos
0   libswiftCore.dylib            	       0x19768d750 swift_conformsToProtocolMaybeInstantiateSuperclasses(swift::TargetMetadata<swift::InProcess> const*, swift::TargetProtocolDescriptor<swift::InProcess> const*, bool)::$_1::operator()((anonymous namespace)::ConformanceSection const&) const::'lambda'(swift::TargetProtocolConformanceDescriptor<swift::InProcess> const&)::operator()(swift::TargetProtocolConformanceDescriptor<swift::InProcess> const&) const + 152
1   libswiftCore.dylib            	       0x19768c84c swift_conformsToProtocolMaybeInstantiateSuperclasses(swift::TargetMetadata<swift::InProcess> const*, swift::TargetProtocolDescriptor<swift::InProcess> const*, bool) + 2952
2   libswiftCore.dylib            	       0x19768a958 swift_conformsToProtocolWithExecutionContext + 68
3   libswiftCore.dylib            	       0x1976364c4 swift::_conformsToProtocol(swift::OpaqueValue const*, swift::TargetMetadata<swift::InProcess> const*, swift::TargetProtocolDescriptorRef<swift::InProcess>, swift::TargetWitnessTable<swift::InProcess> const**, swift::ConformanceExecutionContext*) + 48
4   libswiftCore.dylib            	       0x197688d78 swift::_checkGenericRequirements(__swift::__runtime::llvm::ArrayRef<swift::GenericParamDescriptor>, __swift::__runtime::llvm::ArrayRef<swift::TargetGenericRequirementDescriptor<swift::InProcess>>, __swift::__runtime::llvm::SmallVectorImpl<void const*>&, std::__1::function<void const* (unsigned int, unsigned int)>, std::__1::function<void const* (unsigned int, unsigned int)>, std::__1::function<swift::TargetWitnessTable<swift::InProcess> const* (swift::TargetMetadata<swift::InProcess> const*, unsigned int)>, swift::ConformanceExecutionContext*) + 6456
5   libswiftCore.dylib            	       0x1976870fc swift::TargetProtocolConformanceDescriptor<swift::InProcess>::getWitnessTable(swift::TargetMetadata<swift::InProcess> const*, swift::ConformanceExecutionContext&) const + 468
6   libswiftCore.dylib            	       0x19768c778 swift_conformsToProtocolMaybeInstantiateSuperclasses(swift::TargetMetadata<swift::InProcess> const*, swift::TargetProtocolDescriptor<swift::InProcess> const*, bool) + 2740
7   libswiftCore.dylib            	       0x19768a3f8 swift_conformsToProtocol + 60
8   AttributeGraph                	       0x1c47a8574 AG::LayoutDescriptor::Builder::should_visit_fields(AG::swift::metadata const*, bool) + 324
9   AttributeGraph                	       0x1c47a9138 AG::LayoutDescriptor::make_layout(AG::swift::metadata const*, AGComparisonMode, AG::LayoutDescriptor::HeapMode) + 96
10  AttributeGraph                	       0x1c47aad84 AG::(anonymous namespace)::TypeDescriptorCache::drain_queue(void*) + 356
11  libdispatch.dylib             	       0x1801db4b0 _dispatch_client_callout + 12
12  libdispatch.dylib             	       0x1801f6824 <deduplicated_symbol> + 28
13  libdispatch.dylib             	       0x1801d3d58 _dispatch_root_queue_drain + 916
14  libdispatch.dylib             	       0x1801d4510 _dispatch_worker_thread2 + 252
15  libsystem_pthread.dylib       	       0x104caab50 _pthread_wqthread + 228
16  libsystem_pthread.dylib       	       0x104ca998c start_wqthread + 8


Thread 0 crashed with ARM Thread State (64-bit):
    x0: 0x0000000107109388   x1: 0x0000000200000003   x2: 0x0000000000000000   x3: 0x0000600003534800
    x4: 0x0000600003534800   x5: 0x0000000000000003   x6: 0x0000000000000020   x7: 0x0000000000000000
    x8: 0xfffffffe00000000   x9: 0x0000000200000003  x10: 0x0000000000000003  x11: 0x0000000000000790
   x12: 0x00000000000007fb  x13: 0x00000000000007fd  x14: 0x00000000ab21d80c  x15: 0x00000000ab01d01c
   x16: 0x00000000ab200000  x17: 0x000000000000000c  x18: 0x0000000000000000  x19: 0x000060000178c2c0
   x20: 0x000000016b342b60  x21: 0x000060000178c2c0  x22: 0xd00000000000001c  x23: 0x000000016b345690
   x24: 0x000000016b344fd0  x25: 0x00000001088a3f30  x26: 0x00000001ef6399b8  x27: 0x0000000000000000
   x28: 0x000000016b355db0   fp: 0x000000016b342b40   lr: 0x000000019772c2ec
    sp: 0x000000016b342ac0   pc: 0x000000019772c2ec cpsr: 0x60001000
   far: 0x0000000000000000  esr: 0xf2000001 (Breakpoint) brk 1

Binary Images:
       0x104de4000 -        0x104e83fff dyld (*) <0975afba-c46b-364c-bd84-a75daa9e455a> /usr/lib/dyld
       0x104a9c000 -        0x104a9ffff personal.timeLine (1.0) <692738d5-dd0f-3019-82d5-0bcea9fce45f> /Users/USER/Library/Developer/CoreSimulator/Devices/2BE3E771-EFE0-4305-9889-D4347DAB80D8/data/Containers/Bundle/Application/880883B5-522C-492F-8588-078363B2765B/timeLine.app/timeLine
       0x104ac8000 -        0x104acbfff libLogRedirect.dylib (*) <6de309ef-3434-318a-b6d1-f91eda806f38> /Volumes/VOLUME/*/libLogRedirect.dylib
       0x105a98000 -        0x105ecffff timeLine.debug.dylib (*) <c88ffa41-a2db-334c-83de-9a362f8206aa> /Users/USER/Library/Developer/CoreSimulator/Devices/2BE3E771-EFE0-4305-9889-D4347DAB80D8/data/Containers/Bundle/Application/880883B5-522C-492F-8588-078363B2765B/timeLine.app/timeLine.debug.dylib
       0x104c08000 -        0x104c0ffff libsystem_platform.dylib (*) <de4033bb-4a6b-317a-bda6-b3a408656844> /usr/lib/system/libsystem_platform.dylib
       0x104adc000 -        0x104b17fff libsystem_kernel.dylib (*) <8f54f386-9b41-376a-9ba3-9423bbabb1b6> /usr/lib/system/libsystem_kernel.dylib
       0x104ca8000 -        0x104cb7fff libsystem_pthread.dylib (*) <48ca2121-5ca2-3e04-bc91-a33151256e77> /usr/lib/system/libsystem_pthread.dylib
       0x104db8000 -        0x104dc3fff libobjc-trampolines.dylib (*) <997b234d-5c24-3e21-97d6-33b6853818c0> /Volumes/VOLUME/*/libobjc-trampolines.dylib
       0x197628000 -        0x197acd4df libswiftCore.dylib (*) <c62f8d53-88b1-335b-991e-5bc56d71d347> /Volumes/VOLUME/*/libswiftCore.dylib
       0x1daf5b000 -        0x1dbc8651f com.apple.SwiftUICore (7.2.5.1.102) <f7e2bb37-d266-38fc-b8cc-80664c89f0b4> /Volumes/VOLUME/*/SwiftUICore.framework/SwiftUICore
       0x1c4789000 -        0x1c47ca07f com.apple.AttributeGraph (7.0.80) <bfbc22b3-f2d6-39cf-8d0e-1d09fbcca27c> /Volumes/VOLUME/*/AttributeGraph.framework/AttributeGraph
       0x1d9dd4000 -        0x1daf5a47f com.apple.SwiftUI (7.2.5.1.102) <719cf349-8c4a-3054-9536-23eb53648ee0> /Volumes/VOLUME/*/SwiftUI.framework/SwiftUI
       0x18519e000 -        0x1873c071f com.apple.UIKitCore (1.0) <196154ff-ba04-33cd-9277-98f9aa0b7499> /Volumes/VOLUME/*/UIKitCore.framework/UIKitCore
       0x18c611000 -        0x18c93f91f com.apple.QuartzCore (1193.47.1) <886d5a00-871b-360c-9b22-4d902b80f230> /Volumes/VOLUME/*/QuartzCore.framework/QuartzCore
       0x250190000 -        0x250191e9f com.apple.UpdateCycle (1) <e2e29a67-7d1d-333d-9227-e405451edb7d> /Volumes/VOLUME/*/UpdateCycle.framework/UpdateCycle
       0x1803c3000 -        0x1807df37f com.apple.CoreFoundation (6.9) <4f6d050d-95ee-3a95-969c-3a98b29df6ff> /Volumes/VOLUME/*/CoreFoundation.framework/CoreFoundation
       0x192a64000 -        0x192a6bdbf com.apple.GraphicsServices (1.0) <4e5b0462-6170-3367-9475-4ff8b8dfe4e6> /Volumes/VOLUME/*/GraphicsServices.framework/GraphicsServices
               0x0 - 0xffffffffffffffff ??? (*) <00000000-0000-0000-0000-000000000000> ???
       0x18085f000 -        0x1815d18df com.apple.Foundation (6.9) <c153116f-dd31-3fa9-89bb-04b47c1fa83d> /Volumes/VOLUME/*/Foundation.framework/Foundation
       0x1801bf000 -        0x1802041bf libdispatch.dylib (*) <ec9ecf10-959d-3da1-a055-6de970159b9d> /Volumes/VOLUME/*/libdispatch.dylib
       0x24c382000 -        0x24c44184b com.apple.SonicFoundation (1.0) <c62cf68a-95d1-3e3f-af1e-fc28f6306790> /Volumes/VOLUME/*/SonicFoundation.framework/SonicFoundation

External Modification Summary:
  Calls made by other processes targeting this process:
    task_for_pid: 0
    thread_create: 0
    thread_set_state: 0
  Calls made by this process:
    task_for_pid: 0
    thread_create: 0
    thread_set_state: 0
  Calls made by all processes on this machine:
    task_for_pid: 57
    thread_create: 0
    thread_set_state: 0

VM Region Summary:
ReadOnly portion of Libraries: Total=1.6G resident=0K(0%) swapped_out_or_unallocated=1.6G(100%)
Writable regions: Total=745.4M written=2627K(0%) resident=2035K(0%) swapped_out=592K(0%) unallocated=742.9M(100%)

                                VIRTUAL   REGION 
REGION TYPE                        SIZE    COUNT (non-coalesced) 
===========                     =======  ======= 
Activity Tracing                   256K        1 
AttributeGraph Data               1024K        1 
CG raster data                    1472K        4 
ColorSync                           32K        2 
CoreAnimation                      752K       31 
CoreUI image data                  144K        1 
Foundation                          16K        1 
IOSurface                          128K        1 
Kernel Alloc Once                   32K        1 
MALLOC                           727.1M       81 
MALLOC guard page                  192K       12 
STACK GUARD                       56.1M        5 
Stack                             10.1M        5 
VM_ALLOCATE                       3232K        3 
__DATA                            41.6M      688 
__DATA_CONST                      91.9M      714 
__DATA_DIRTY                       139K       13 
__FONT_DATA                        2352        1 
__LINKEDIT                       711.4M        9 
__OBJC_RO                         62.5M        1 
__OBJC_RW                         2771K        1 
__TEXT                           916.2M      727 
__TPRO_CONST                       148K        2 
dyld private memory                2.2G       19 
mapped file                      269.8M       23 
page table in kernel              2035K        1 
shared memory                     1040K        2 
===========                     =======  ======= 
TOTAL                              5.0G     2350 


-----------
Full Report
-----------

{"app_name":"timeLine","timestamp":"2026-01-22 11:49:27.00 -0800","app_version":"1.0","slice_uuid":"692738d5-dd0f-3019-82d5-0bcea9fce45f","build_version":"1","platform":7,"bundleID":"personal.timeLine","share_with_app_devs":0,"is_first_party":0,"bug_type":"309","os_version":"macOS 26.2 (25C56)","roots_installed":0,"name":"timeLine","incident_id":"96F97BFC-A48D-4995-A061-E2CE632C3612"}
{
  "uptime" : 1000000,
  "procRole" : "Foreground",
  "version" : 2,
  "userID" : 501,
  "deployVersion" : 210,
  "modelCode" : "Mac14,9",
  "coalitionID" : 165815,
  "osVersion" : {
    "train" : "macOS 26.2",
    "build" : "25C56",
    "releaseType" : "User"
  },
  "captureTime" : "2026-01-22 11:49:12.3991 -0800",
  "codeSigningMonitor" : 2,
  "incident" : "96F97BFC-A48D-4995-A061-E2CE632C3612",
  "pid" : 96358,
  "translated" : false,
  "cpuType" : "ARM-64",
  "procLaunch" : "2026-01-22 11:17:59.6821 -0800",
  "procStartAbsTime" : 26272183186424,
  "procExitAbsTime" : 26317121544716,
  "procName" : "timeLine",
  "procPath" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/2BE3E771-EFE0-4305-9889-D4347DAB80D8\/data\/Containers\/Bundle\/Application\/880883B5-522C-492F-8588-078363B2765B\/timeLine.app\/timeLine",
  "bundleInfo" : {"CFBundleShortVersionString":"1.0","CFBundleVersion":"1","CFBundleIdentifier":"personal.timeLine"},
  "storeInfo" : {"deviceIdentifierForVendor":"D83670AE-A4A3-5455-9040-C2BB2EEED25A","thirdParty":true},
  "parentProc" : "launchd_sim",
  "parentPid" : 96128,
  "coalitionName" : "com.apple.CoreSimulator.SimDevice.2BE3E771-EFE0-4305-9889-D4347DAB80D8",
  "crashReporterKey" : "E1C6602B-FD20-0B3A-C7E6-B3355E7E2549",
  "appleIntelligenceStatus" : {"reasons":["assetIsNotReady","notOptedIn"],"state":"unavailable"},
  "developerMode" : 1,
  "responsiblePid" : 92731,
  "responsibleProc" : "SimulatorTrampoline",
  "codeSigningID" : "personal.timeLine",
  "codeSigningTeamID" : "",
  "codeSigningFlags" : 570425857,
  "codeSigningValidationCategory" : 10,
  "codeSigningTrustLevel" : 4294967295,
  "codeSigningAuxiliaryInfo" : 0,
  "instructionByteStream" : {"beforePC":"IAAg1IEF+LfpAwC54gMDquMDBKrkAwWq5QMGquYDB6rnAwiqKAMAlA==","atPC":"IAAg1IgSgFL\/EwC56AcA+UgAgFLoAwA5YBUA8AAQL5FjFQDwY8A5kQ=="},
  "bootSessionUUID" : "150898E5-F664-436A-A5B2-E720E5BD0F59",
  "wakeTime" : 1095932,
  "sleepWakeUUID" : "075F3D84-CB0F-49AF-B33E-58DC40F43A9A",
  "sip" : "enabled",
  "exception" : {"codes":"0x0000000000000001, 0x000000019772c2ec","rawCodes":[1,6835847916],"type":"EXC_BREAKPOINT","signal":"SIGTRAP"},
  "termination" : {"flags":0,"code":5,"namespace":"SIGNAL","indicator":"Trace\/BPT trap: 5","byProc":"exc handler","byPid":96358},
  "os_fault" : {"process":"timeLine"},
  "extMods" : {"caller":{"thread_create":0,"thread_set_state":0,"task_for_pid":0},"system":{"thread_create":0,"thread_set_state":0,"task_for_pid":57},"targeted":{"thread_create":0,"thread_set_state":0,"task_for_pid":0},"warnings":0},
  "faultingThread" : 0,
  "threads" : [{"frames":[{"imageOffset":1065708,"symbol":"_assertionFailure(_:_:file:line:flags:)","symbolLocation":156,"imageIndex":8},{"imageOffset":4061496,"symbol":"specialized EnvironmentObject.error()","symbolLocation":264,"imageIndex":9},{"imageOffset":4061528,"symbol":"specialized EnvironmentObject.wrappedValue.getter","symbolLocation":28,"imageIndex":9},{"imageOffset":4058812,"symbol":"EnvironmentObject.wrappedValue.getter","symbolLocation":12,"imageIndex":9},{"imageOffset":1020516,"sourceFile":"TodoSheet.swift","symbol":"TodoSheet.dragCoordinator.getter","symbolLocation":96,"imageIndex":3},{"imageOffset":1140100,"sourceLine":372,"sourceFile":"TodoSheet.swift","symbol":"TodoSheet.cancelButton.getter","imageIndex":3,"symbolLocation":3292},{"imageOffset":1128636,"sourceLine":324,"sourceFile":"TodoSheet.swift","symbol":"closure #1 in TodoSheet.actionBar.getter","imageIndex":3,"symbolLocation":576},{"imageOffset":496656,"symbol":"<deduplicated_symbol>","symbolLocation":88,"imageIndex":9},{"imageOffset":5248480,"symbol":"_VariadicView.Tree.init(_:content:)","symbolLocation":112,"imageIndex":9},{"imageOffset":4279352,"symbol":"HStack.init(alignment:spacing:content:)","symbolLocation":76,"imageIndex":9},{"imageOffset":1043576,"sourceLine":323,"sourceFile":"TodoSheet.swift","symbol":"TodoSheet.actionBar.getter","imageIndex":3,"symbolLocation":808},{"imageOffset":1037136,"sourceLine":65,"sourceFile":"TodoSheet.swift","symbol":"closure #1 in TodoSheet.body.getter","imageIndex":3,"symbolLocation":2076},{"imageOffset":496656,"symbol":"<deduplicated_symbol>","symbolLocation":88,"imageIndex":9},{"imageOffset":5248480,"symbol":"_VariadicView.Tree.init(_:content:)","symbolLocation":112,"imageIndex":9},{"imageOffset":2053024,"symbol":"VStack.init(alignment:spacing:content:)","symbolLocation":76,"imageIndex":9},{"imageOffset":1033208,"sourceLine":56,"sourceFile":"TodoSheet.swift","symbol":"TodoSheet.body.getter","imageIndex":3,"symbolLocation":796},{"imageOffset":1204260,"sourceFile":"\/<compiler-generated>","symbol":"protocol witness for View.body.getter in conformance TodoSheet","symbolLocation":12,"imageIndex":3},{"imageOffset":4077520,"symbol":"closure #1 in ViewBodyAccessor.updateBody(of:changed:)","symbolLocation":1436,"imageIndex":9},{"imageOffset":4076036,"symbol":"ViewBodyAccessor.updateBody(of:changed:)","symbolLocation":180,"imageIndex":9},{"imageOffset":4077808,"symbol":"protocol witness for BodyAccessor.updateBody(of:changed:) in conformance ViewBodyAccessor<A>","symbolLocation":12,"imageIndex":9},{"imageOffset":5291976,"symbol":"closure #1 in DynamicBody.updateValue()","symbolLocation":856,"imageIndex":9},{"imageOffset":5290420,"symbol":"DynamicBody.updateValue()","symbolLocation":836,"imageIndex":9},{"imageOffset":2611424,"symbol":"partial apply for implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:)","symbolLocation":28,"imageIndex":9},{"imageOffset":46888,"symbol":"AG::Graph::UpdateStack::update()","symbolLocation":492,"imageIndex":10},{"imageOffset":48664,"symbol":"AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int)","symbolLocation":352,"imageIndex":10},{"imageOffset":79180,"symbol":"AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long)","symbolLocation":668,"imageIndex":10},{"imageOffset":176588,"symbol":"AGGraphGetValue","symbolLocation":236,"imageIndex":10},{"imageOffset":1501056,"symbol":"specialized DynamicViewList.updateValue()","symbolLocation":84,"imageIndex":9},{"imageOffset":1547872,"symbol":"specialized implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:)","symbolLocation":20,"imageIndex":9},{"imageOffset":46888,"symbol":"AG::Graph::UpdateStack::update()","symbolLocation":492,"imageIndex":10},{"imageOffset":48664,"symbol":"AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int)","symbolLocation":352,"imageIndex":10},{"imageOffset":79180,"symbol":"AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long)","symbolLocation":668,"imageIndex":10},{"imageOffset":176588,"symbol":"AGGraphGetValue","symbolLocation":236,"imageIndex":10},{"imageOffset":6654192,"symbol":"specialized implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:)","symbolLocation":160,"imageIndex":9},{"imageOffset":46888,"symbol":"AG::Graph::UpdateStack::update()","symbolLocation":492,"imageIndex":10},{"imageOffset":48664,"symbol":"AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int)","symbolLocation":352,"imageIndex":10},{"imageOffset":79180,"symbol":"AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long)","symbolLocation":668,"imageIndex":10},{"imageOffset":176588,"symbol":"AGGraphGetValue","symbolLocation":236,"imageIndex":10},{"imageOffset":1395064,"symbol":"specialized DynamicContainerInfo.updateItems(disableTransitions:)","symbolLocation":92,"imageIndex":9},{"imageOffset":1390648,"symbol":"specialized DynamicContainerInfo.updateValue()","symbolLocation":424,"imageIndex":9},{"imageOffset":1544752,"symbol":"specialized implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:)","symbolLocation":20,"imageIndex":9},{"imageOffset":46888,"symbol":"AG::Graph::UpdateStack::update()","symbolLocation":492,"imageIndex":10},{"imageOffset":48664,"symbol":"AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int)","symbolLocation":352,"imageIndex":10},{"imageOffset":79180,"symbol":"AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long)","symbolLocation":668,"imageIndex":10},{"imageOffset":176588,"symbol":"AGGraphGetValue","symbolLocation":236,"imageIndex":10},{"imageOffset":5856196,"symbol":"DynamicPreferenceCombiner.info.getter","symbolLocation":80,"imageIndex":9},{"imageOffset":5856440,"symbol":"DynamicPreferenceCombiner.value.getter","symbolLocation":140,"imageIndex":9},{"imageOffset":5914964,"symbol":"implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:)","symbolLocation":148,"imageIndex":9},{"imageOffset":46888,"symbol":"AG::Graph::UpdateStack::update()","symbolLocation":492,"imageIndex":10},{"imageOffset":48664,"symbol":"AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int)","symbolLocation":352,"imageIndex":10},{"imageOffset":79180,"symbol":"AG::Graph::input_value_ref_slow(AG::data::ptr<AG::Node>, AG::AttributeID, unsigned int, unsigned int, AGSwiftMetadata const*, unsigned char&, long)","symbolLocation":668,"imageIndex":10},{"imageOffset":176588,"symbol":"AGGraphGetValue","symbolLocation":236,"imageIndex":10},{"imageOffset":2374944,"symbol":"PairPreferenceCombiner.value.getter","symbolLocation":96,"imageIndex":9},{"imageOffset":5914964,"symbol":"implicit closure #1 in closure #1 in closure #1 in Attribute.init<A>(_:)","symbolLocation":148,"imageIndex":9},{"imageOffset":46888,"symbol":"AG::Graph::UpdateStack::update()","symbolLocation":492,"imageIndex":10},{"imageOffset":48664,"symbol":"AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int)","symbolLocation":352,"imageIndex":10},{"imageOffset":76888,"symbol":"AG::Graph::value_ref(AG::AttributeID, unsigned int, AGSwiftMetadata const*, unsigned char&)","symbolLocation":260,"imageIndex":10},{"imageOffset":177420,"symbol":"AGGraphGetWeakValue","symbolLocation":368,"imageIndex":10},{"imageOffset":7589608,"symbol":"GraphHost.preferenceValue<A>(_:)","symbolLocation":504,"imageIndex":9},{"imageOffset":11727104,"symbol":"partial apply for closure #1 in ViewGraphRootValueUpdater._preferenceValue<A>(_:)","symbolLocation":32,"imageIndex":9},{"imageOffset":11714664,"symbol":"ViewGraphRootValueUpdater._updateViewGraph<A>(body:)","symbolLocation":200,"imageIndex":9},{"imageOffset":11705932,"symbol":"ViewGraphRootValueUpdater._preferenceValue<A>(_:)","symbolLocation":180,"imageIndex":9},{"imageOffset":4269748,"symbol":"specialized PresentationHostingController.setupDelayIfNeeded()","symbolLocation":140,"imageIndex":11},{"imageOffset":3354852,"symbol":"SheetBridge.present(_:from:animated:existingPresentedVC:isPreempting:)","symbolLocation":1008,"imageIndex":11},{"imageOffset":3361224,"symbol":"SheetBridge.contingentlyPresent(_:from:animated:)","symbolLocation":1364,"imageIndex":11},{"imageOffset":2370912,"symbol":"specialized SheetBridge.preferencesDidChange(_:)","symbolLocation":5504,"imageIndex":11},{"imageOffset":2351140,"symbol":"_UIHostingView.preferencesDidChange()","symbolLocation":1136,"imageIndex":11},{"imageOffset":11757500,"symbol":"specialized update #1 () in ViewGraph.updateOutputs(async:)","symbolLocation":304,"imageIndex":9},{"imageOffset":11734932,"symbol":"ViewGraph.updateOutputs(at:)","symbolLocation":484,"imageIndex":9},{"imageOffset":11710764,"symbol":"closure #1 in ViewGraphRootValueUpdater.render(interval:updateDisplayList:targetTimestamp:)","symbolLocation":644,"imageIndex":9},{"imageOffset":11704408,"symbol":"ViewGraphRootValueUpdater.render(interval:updateDisplayList:targetTimestamp:)","symbolLocation":420,"imageIndex":9},{"imageOffset":1421720,"imageIndex":12},{"imageOffset":13964400,"symbol":"_UIHostingView.layoutSubviews()","symbolLocation":80,"imageIndex":11},{"imageOffset":13964452,"symbol":"@objc _UIHostingView.layoutSubviews()","symbolLocation":32,"imageIndex":11},{"imageOffset":4081996,"imageIndex":12},{"imageOffset":4082912,"imageIndex":12},{"imageOffset":24605128,"symbol":"-[UIView(CALayerDelegate) layoutSublayersOfLayer:]","symbolLocation":2656,"imageIndex":12},{"imageOffset":1929208,"symbol":"CA::Layer::perform_update_(CA::Layer*, CALayer*, unsigned int, CA::LayerUpdateReason, CA::Transaction*)","symbolLocation":452,"imageIndex":13},{"imageOffset":1927240,"symbol":"CA::Layer::update_if_needed_(CA::Transaction*, CA::LayerUpdateReason)","symbolLocation":600,"imageIndex":13},{"imageOffset":1975512,"symbol":"CA::Layer::layout_and_display_if_needed(CA::Transaction*)","symbolLocation":152,"imageIndex":13},{"imageOffset":1014268,"symbol":"CA::Context::commit_transaction(CA::Transaction*, double, double*)","symbolLocation":544,"imageIndex":13},{"imageOffset":1211220,"symbol":"CA::Transaction::commit()","symbolLocation":636,"imageIndex":13},{"imageOffset":1217532,"symbol":"CA::Transaction::flush_as_runloop_observer(bool)","symbolLocation":68,"imageIndex":13},{"imageOffset":18517152,"symbol":"_UIApplicationFlushCATransaction","symbolLocation":48,"imageIndex":12},{"imageOffset":17587272,"symbol":"__setupUpdateSequence_block_invoke_2","symbolLocation":372,"imageIndex":12},{"imageOffset":6886264,"symbol":"_UIUpdateSequenceRunNext","symbolLocation":120,"imageIndex":12},{"imageOffset":17588388,"symbol":"schedulerStepScheduledMainSectionContinue","symbolLocation":56,"imageIndex":12},{"imageOffset":4788,"symbol":"UC::DriverCore::continueProcessing()","symbolLocation":80,"imageIndex":14},{"imageOffset":603044,"symbol":"__CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__","symbolLocation":24,"imageIndex":15},{"imageOffset":602860,"symbol":"__CFRunLoopDoSource0","symbolLocation":168,"imageIndex":15},{"imageOffset":600696,"symbol":"__CFRunLoopDoSources0","symbolLocation":220,"imageIndex":15},{"imageOffset":597068,"symbol":"__CFRunLoopRun","symbolLocation":760,"imageIndex":15},{"imageOffset":576748,"symbol":"_CFRunLoopRunSpecificWithOptions","symbolLocation":496,"imageIndex":15},{"imageOffset":10684,"symbol":"GSEventRunModal","symbolLocation":116,"imageIndex":16},{"imageOffset":18523508,"symbol":"-[UIApplication _run]","symbolLocation":772,"imageIndex":12},{"imageOffset":18540444,"symbol":"UIApplicationMain","symbolLocation":124,"imageIndex":12},{"imageOffset":8099360,"symbol":"closure #1 in KitRendererCommon(_:)","symbolLocation":164,"imageIndex":11},{"imageOffset":8098664,"symbol":"runApp<A>(_:)","symbolLocation":180,"imageIndex":11},{"imageOffset":5534764,"symbol":"static App.main()","symbolLocation":148,"imageIndex":11},{"imageOffset":3333196,"sourceLine":14,"sourceFile":"TimeLineApp.swift","symbol":"static AppEntryPoint.main()","imageIndex":3,"symbolLocation":128},{"imageOffset":3335308,"sourceFile":"\/<compiler-generated>","symbol":"static AppEntryPoint.$main()","symbolLocation":12,"imageIndex":3},{"imageOffset":3366556,"sourceFile":"TimeLineApp.swift","symbol":"__debug_main_executable_dylib_entry_point","symbolLocation":12,"imageIndex":3},{"imageOffset":4373926864,"imageIndex":17},{"imageOffset":36180,"symbol":"start","symbolLocation":7184,"imageIndex":0}],"id":20762195,"recursionInfoArray":[{"hottestElided":36,"coldestElided":71,"depth":10,"keyFrame":{"imageOffset":48664,"symbol":"AG::Graph::update_attribute(AG::data::ptr<AG::Node>, unsigned int)","symbolLocation":352,"imageIndex":10}}],"originalLength":141,"triggered":true,"threadState":{"x":[{"value":4413494152},{"value":8589934595},{"value":0},{"value":105553172056064},{"value":105553172056064},{"value":3},{"value":32},{"value":0},{"value":18446744065119617024},{"value":8589934595},{"value":3},{"value":1936},{"value":2043},{"value":2045},{"value":2871121932},{"value":2869022748},{"value":2871001088},{"value":12},{"value":0},{"value":105553140957888},{"value":6093548384},{"value":105553140957888},{"value":14987979559889010716},{"value":6093559440},{"value":6093557712},{"value":4438245168},{"value":8311249336,"symbolLocation":0,"symbol":"value witness table for _HStackLayout"},{"value":0},{"value":6093626800}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6835847916},"cpsr":{"value":1610616832},"fp":{"value":6093548352},"sp":{"value":6093548224},"esr":{"value":4060086273,"description":"(Breakpoint) brk 1"},"pc":{"value":6835847916,"matchesCrashFrame":1},"far":{"value":0}},"queue":"com.apple.main-thread"},{"id":20762527,"name":"com.apple.uikit.eventfetch-thread","threadState":{"x":[{"value":268451845},{"value":21592279046},{"value":8589934592},{"value":48391396524032},{"value":0},{"value":48391396524032},{"value":2},{"value":4294967295},{"value":0},{"value":17179869184},{"value":0},{"value":2},{"value":0},{"value":0},{"value":11267},{"value":3072},{"value":18446744073709551569},{"value":2},{"value":0},{"value":4294967295},{"value":2},{"value":48391396524032},{"value":0},{"value":48391396524032},{"value":6096526728},{"value":8589934592},{"value":21592279046},{"value":18446744073709550527},{"value":4412409862}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4373534988},"cpsr":{"value":4096},"fp":{"value":6096526576},"sp":{"value":6096526496},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4373465968},"far":{"value":0}},"frames":[{"imageOffset":2928,"symbol":"mach_msg2_trap","symbolLocation":8,"imageIndex":5},{"imageOffset":71948,"symbol":"mach_msg2_internal","symbolLocation":72,"imageIndex":5},{"imageOffset":35856,"symbol":"mach_msg_overwrite","symbolLocation":480,"imageIndex":5},{"imageOffset":3812,"symbol":"mach_msg","symbolLocation":20,"imageIndex":5},{"imageOffset":601092,"symbol":"__CFRunLoopServiceMachPort","symbolLocation":156,"imageIndex":15},{"imageOffset":597436,"symbol":"__CFRunLoopRun","symbolLocation":1128,"imageIndex":15},{"imageOffset":576748,"symbol":"_CFRunLoopRunSpecificWithOptions","symbolLocation":496,"imageIndex":15},{"imageOffset":9096776,"symbol":"-[NSRunLoop(NSRunLoop) runMode:beforeDate:]","symbolLocation":208,"imageIndex":18},{"imageOffset":9097320,"symbol":"-[NSRunLoop(NSRunLoop) runUntilDate:]","symbolLocation":60,"imageIndex":18},{"imageOffset":15735888,"symbol":"-[UIEventFetcher threadMain]","symbolLocation":392,"imageIndex":12},{"imageOffset":9256212,"symbol":"__NSThread__start__","symbolLocation":716,"imageIndex":18},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":6},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":6}]},{"id":20764148,"name":"com.apple.UIKit.inProcessAnimationManager","threadState":{"x":[{"value":14},{"value":18446744073709551615},{"value":1},{"value":1},{"value":17179869187},{"value":3},{"value":17179869187},{"value":3},{"value":8211},{"value":18446744073709551615},{"value":0},{"value":0},{"value":8589934595},{"value":3},{"value":8362150760,"symbolLocation":0,"symbol":"OBJC_CLASS_$_OS_dispatch_semaphore"},{"value":8362150760,"symbolLocation":0,"symbol":"OBJC_CLASS_$_OS_dispatch_semaphore"},{"value":18446744073709551580},{"value":6444291256,"symbolLocation":0,"symbol":"-[OS_object retain]"},{"value":0},{"value":105553150972592},{"value":105553150972528},{"value":18446744073709551615},{"value":4416633136},{"value":8512434176,"objc-selector":"OfBytesUsingEncoding:"},{"value":8512434176,"objc-selector":"OfBytesUsingEncoding:"},{"value":105553150972528},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6444294744},"cpsr":{"value":1610616832},"fp":{"value":6094236736},"sp":{"value":6094236720},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4373465836},"far":{"value":0}},"frames":[{"imageOffset":2796,"symbol":"semaphore_wait_trap","symbolLocation":8,"imageIndex":5},{"imageOffset":12888,"symbol":"_dispatch_sema4_wait","symbolLocation":24,"imageIndex":19},{"imageOffset":14304,"symbol":"_dispatch_semaphore_wait_slow","symbolLocation":128,"imageIndex":19},{"imageOffset":4995520,"imageIndex":12},{"imageOffset":5013128,"imageIndex":12},{"imageOffset":1418704,"imageIndex":12},{"imageOffset":9256212,"symbol":"__NSThread__start__","symbolLocation":716,"imageIndex":18},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":6},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":6}]},{"id":20764149,"frames":[],"threadState":{"x":[{"value":6094811136},{"value":28423},{"value":6094274560},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":4096},"fp":{"value":0},"sp":{"value":6094811136},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4375353732},"far":{"value":0}}},{"id":20795367,"threadState":{"x":[{"value":6095381632},{"value":9869306252,"symbolLocation":1140,"symbol":"__unnamed_1"},{"value":0},{"value":0},{"value":6839515236,"symbolLocation":0,"symbol":"protocol descriptor for Equatable"},{"value":4374060776},{"value":6095382632},{"value":6095382600},{"value":9869306256,"symbolLocation":1144,"symbol":"__unnamed_1"},{"value":258926008},{"value":6095381478},{"value":0},{"value":1},{"value":8362161992,"symbolLocation":0,"symbol":"OBJC_CLASS_$_NSObject"},{"value":8362161992,"symbolLocation":0,"symbol":"OBJC_CLASS_$_NSObject"},{"value":1},{"value":4374693764,"symbolLocation":0,"symbol":"os_unfair_lock_unlock"},{"value":4378913320},{"value":0},{"value":4479572712},{"value":6095381632},{"value":9869306252,"symbolLocation":1140,"symbol":"__unnamed_1"},{"value":9869389804},{"value":9869388464},{"value":6095381488},{"value":8370931048,"symbolLocation":0,"symbol":"Conformances"},{"value":6095381479},{"value":6095381464},{"value":6095381496}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6835193932},"cpsr":{"value":1610616832},"fp":{"value":6095381296},"sp":{"value":6095381184},"esr":{"value":2449473543,"description":"(Data Abort) byte read Translation fault"},"pc":{"value":6835197776},"far":{"value":10128232264}},"queue":"com.apple.root.utility-qos","frames":[{"imageOffset":415568,"symbol":"swift_conformsToProtocolMaybeInstantiateSuperclasses(swift::TargetMetadata<swift::InProcess> const*, swift::TargetProtocolDescriptor<swift::InProcess> const*, bool)::$_1::operator()((anonymous namespace)::ConformanceSection const&) const::'lambda'(swift::TargetProtocolConformanceDescriptor<swift::InProcess> const&)::operator()(swift::TargetProtocolConformanceDescriptor<swift::InProcess> const&) const","symbolLocation":152,"imageIndex":8},{"imageOffset":411724,"symbol":"swift_conformsToProtocolMaybeInstantiateSuperclasses(swift::TargetMetadata<swift::InProcess> const*, swift::TargetProtocolDescriptor<swift::InProcess> const*, bool)","symbolLocation":2952,"imageIndex":8},{"imageOffset":403800,"symbol":"swift_conformsToProtocolWithExecutionContext","symbolLocation":68,"imageIndex":8},{"imageOffset":58564,"symbol":"swift::_conformsToProtocol(swift::OpaqueValue const*, swift::TargetMetadata<swift::InProcess> const*, swift::TargetProtocolDescriptorRef<swift::InProcess>, swift::TargetWitnessTable<swift::InProcess> const**, swift::ConformanceExecutionContext*)","symbolLocation":48,"imageIndex":8},{"imageOffset":396664,"symbol":"swift::_checkGenericRequirements(__swift::__runtime::llvm::ArrayRef<swift::GenericParamDescriptor>, __swift::__runtime::llvm::ArrayRef<swift::TargetGenericRequirementDescriptor<swift::InProcess>>, __swift::__runtime::llvm::SmallVectorImpl<void const*>&, std::__1::function<void const* (unsigned int, unsigned int)>, std::__1::function<void const* (unsigned int, unsigned int)>, std::__1::function<swift::TargetWitnessTable<swift::InProcess> const* (swift::TargetMetadata<swift::InProcess> const*, unsigned int)>, swift::ConformanceExecutionContext*)","symbolLocation":6456,"imageIndex":8},{"imageOffset":389372,"symbol":"swift::TargetProtocolConformanceDescriptor<swift::InProcess>::getWitnessTable(swift::TargetMetadata<swift::InProcess> const*, swift::ConformanceExecutionContext&) const","symbolLocation":468,"imageIndex":8},{"imageOffset":411512,"symbol":"swift_conformsToProtocolMaybeInstantiateSuperclasses(swift::TargetMetadata<swift::InProcess> const*, swift::TargetProtocolDescriptor<swift::InProcess> const*, bool)","symbolLocation":2740,"imageIndex":8},{"imageOffset":402424,"symbol":"swift_conformsToProtocol","symbolLocation":60,"imageIndex":8},{"imageOffset":128372,"symbol":"AG::LayoutDescriptor::Builder::should_visit_fields(AG::swift::metadata const*, bool)","symbolLocation":324,"imageIndex":10},{"imageOffset":131384,"symbol":"AG::LayoutDescriptor::make_layout(AG::swift::metadata const*, AGComparisonMode, AG::LayoutDescriptor::HeapMode)","symbolLocation":96,"imageIndex":10},{"imageOffset":138628,"symbol":"AG::(anonymous namespace)::TypeDescriptorCache::drain_queue(void*)","symbolLocation":356,"imageIndex":10},{"imageOffset":115888,"symbol":"_dispatch_client_callout","symbolLocation":12,"imageIndex":19},{"imageOffset":227364,"symbol":"<deduplicated_symbol>","symbolLocation":28,"imageIndex":19},{"imageOffset":85336,"symbol":"_dispatch_root_queue_drain","symbolLocation":916,"imageIndex":19},{"imageOffset":87312,"symbol":"_dispatch_worker_thread2","symbolLocation":252,"imageIndex":19},{"imageOffset":11088,"symbol":"_pthread_wqthread","symbolLocation":228,"imageIndex":6},{"imageOffset":6540,"symbol":"start_wqthread","symbolLocation":8,"imageIndex":6}]}],
  "usedImages" : [
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 4376641536,
    "size" : 655360,
    "uuid" : "0975afba-c46b-364c-bd84-a75daa9e455a",
    "path" : "\/usr\/lib\/dyld",
    "name" : "dyld"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4373200896,
    "CFBundleShortVersionString" : "1.0",
    "CFBundleIdentifier" : "personal.timeLine",
    "size" : 16384,
    "uuid" : "692738d5-dd0f-3019-82d5-0bcea9fce45f",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/2BE3E771-EFE0-4305-9889-D4347DAB80D8\/data\/Containers\/Bundle\/Application\/880883B5-522C-492F-8588-078363B2765B\/timeLine.app\/timeLine",
    "name" : "timeLine",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4373381120,
    "size" : 16384,
    "uuid" : "6de309ef-3434-318a-b6d1-f91eda806f38",
    "path" : "\/Volumes\/VOLUME\/*\/libLogRedirect.dylib",
    "name" : "libLogRedirect.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4389961728,
    "size" : 4423680,
    "uuid" : "c88ffa41-a2db-334c-83de-9a362f8206aa",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/2BE3E771-EFE0-4305-9889-D4347DAB80D8\/data\/Containers\/Bundle\/Application\/880883B5-522C-492F-8588-078363B2765B\/timeLine.app\/timeLine.debug.dylib",
    "name" : "timeLine.debug.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4374691840,
    "size" : 32768,
    "uuid" : "de4033bb-4a6b-317a-bda6-b3a408656844",
    "path" : "\/usr\/lib\/system\/libsystem_platform.dylib",
    "name" : "libsystem_platform.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4373463040,
    "size" : 245760,
    "uuid" : "8f54f386-9b41-376a-9ba3-9423bbabb1b6",
    "path" : "\/usr\/lib\/system\/libsystem_kernel.dylib",
    "name" : "libsystem_kernel.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4375347200,
    "size" : 65536,
    "uuid" : "48ca2121-5ca2-3e04-bc91-a33151256e77",
    "path" : "\/usr\/lib\/system\/libsystem_pthread.dylib",
    "name" : "libsystem_pthread.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4376461312,
    "size" : 49152,
    "uuid" : "997b234d-5c24-3e21-97d6-33b6853818c0",
    "path" : "\/Volumes\/VOLUME\/*\/libobjc-trampolines.dylib",
    "name" : "libobjc-trampolines.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6834782208,
    "size" : 4871392,
    "uuid" : "c62f8d53-88b1-335b-991e-5bc56d71d347",
    "path" : "\/Volumes\/VOLUME\/*\/libswiftCore.dylib",
    "name" : "libswiftCore.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 7968501760,
    "CFBundleShortVersionString" : "7.2.5.1.102",
    "CFBundleIdentifier" : "com.apple.SwiftUICore",
    "size" : 13808928,
    "uuid" : "f7e2bb37-d266-38fc-b8cc-80664c89f0b4",
    "path" : "\/Volumes\/VOLUME\/*\/SwiftUICore.framework\/SwiftUICore",
    "name" : "SwiftUICore",
    "CFBundleVersion" : "7.2.5.1.102"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 7591202816,
    "CFBundleShortVersionString" : "7.0.80",
    "CFBundleIdentifier" : "com.apple.AttributeGraph",
    "size" : 266368,
    "uuid" : "bfbc22b3-f2d6-39cf-8d0e-1d09fbcca27c",
    "path" : "\/Volumes\/VOLUME\/*\/AttributeGraph.framework\/AttributeGraph",
    "name" : "AttributeGraph",
    "CFBundleVersion" : "7.0.80"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 7950123008,
    "CFBundleShortVersionString" : "7.2.5.1.102",
    "CFBundleIdentifier" : "com.apple.SwiftUI",
    "size" : 18375808,
    "uuid" : "719cf349-8c4a-3054-9536-23eb53648ee0",
    "path" : "\/Volumes\/VOLUME\/*\/SwiftUI.framework\/SwiftUI",
    "name" : "SwiftUI",
    "CFBundleVersion" : "7.2.5.1.102"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6528032768,
    "CFBundleShortVersionString" : "1.0",
    "CFBundleIdentifier" : "com.apple.UIKitCore",
    "size" : 35792672,
    "uuid" : "196154ff-ba04-33cd-9277-98f9aa0b7499",
    "path" : "\/Volumes\/VOLUME\/*\/UIKitCore.framework\/UIKitCore",
    "name" : "UIKitCore",
    "CFBundleVersion" : "9126.2.4.1.111"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6650138624,
    "CFBundleShortVersionString" : "1193.47.1",
    "CFBundleIdentifier" : "com.apple.QuartzCore",
    "size" : 3336480,
    "uuid" : "886d5a00-871b-360c-9b22-4d902b80f230",
    "path" : "\/Volumes\/VOLUME\/*\/QuartzCore.framework\/QuartzCore",
    "name" : "QuartzCore",
    "CFBundleVersion" : "1193.47.1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 9933750272,
    "CFBundleShortVersionString" : "1",
    "CFBundleIdentifier" : "com.apple.UpdateCycle",
    "size" : 7840,
    "uuid" : "e2e29a67-7d1d-333d-9227-e405451edb7d",
    "path" : "\/Volumes\/VOLUME\/*\/UpdateCycle.framework\/UpdateCycle",
    "name" : "UpdateCycle",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6446395392,
    "CFBundleShortVersionString" : "6.9",
    "CFBundleIdentifier" : "com.apple.CoreFoundation",
    "size" : 4309888,
    "uuid" : "4f6d050d-95ee-3a95-969c-3a98b29df6ff",
    "path" : "\/Volumes\/VOLUME\/*\/CoreFoundation.framework\/CoreFoundation",
    "name" : "CoreFoundation",
    "CFBundleVersion" : "4201"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6755336192,
    "CFBundleShortVersionString" : "1.0",
    "CFBundleIdentifier" : "com.apple.GraphicsServices",
    "size" : 32192,
    "uuid" : "4e5b0462-6170-3367-9475-4ff8b8dfe4e6",
    "path" : "\/Volumes\/VOLUME\/*\/GraphicsServices.framework\/GraphicsServices",
    "name" : "GraphicsServices",
    "CFBundleVersion" : "1.0"
  },
  {
    "size" : 0,
    "source" : "A",
    "base" : 0,
    "uuid" : "00000000-0000-0000-0000-000000000000"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6451228672,
    "CFBundleShortVersionString" : "6.9",
    "CFBundleIdentifier" : "com.apple.Foundation",
    "size" : 14100704,
    "uuid" : "c153116f-dd31-3fa9-89bb-04b47c1fa83d",
    "path" : "\/Volumes\/VOLUME\/*\/Foundation.framework\/Foundation",
    "name" : "Foundation",
    "CFBundleVersion" : "4201"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6444281856,
    "size" : 283072,
    "uuid" : "ec9ecf10-959d-3da1-a055-6de970159b9d",
    "path" : "\/Volumes\/VOLUME\/*\/libdispatch.dylib",
    "name" : "libdispatch.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 9868681216,
    "CFBundleShortVersionString" : "1.0",
    "CFBundleIdentifier" : "com.apple.SonicFoundation",
    "size" : 784460,
    "uuid" : "c62cf68a-95d1-3e3f-af1e-fc28f6306790",
    "path" : "\/Volumes\/VOLUME\/*\/SonicFoundation.framework\/SonicFoundation",
    "name" : "SonicFoundation",
    "CFBundleVersion" : "25310.25.45.301"
  }
],
  "sharedCache" : {
  "base" : 6442450944,
  "size" : 4230184960,
  "uuid" : "a6c0479d-4a05-3659-bf82-42eebf5fb5a0"
},
  "vmSummary" : "ReadOnly portion of Libraries: Total=1.6G resident=0K(0%) swapped_out_or_unallocated=1.6G(100%)\nWritable regions: Total=745.4M written=2627K(0%) resident=2035K(0%) swapped_out=592K(0%) unallocated=742.9M(100%)\n\n                                VIRTUAL   REGION \nREGION TYPE                        SIZE    COUNT (non-coalesced) \n===========                     =======  ======= \nActivity Tracing                   256K        1 \nAttributeGraph Data               1024K        1 \nCG raster data                    1472K        4 \nColorSync                           32K        2 \nCoreAnimation                      752K       31 \nCoreUI image data                  144K        1 \nFoundation                          16K        1 \nIOSurface                          128K        1 \nKernel Alloc Once                   32K        1 \nMALLOC                           727.1M       81 \nMALLOC guard page                  192K       12 \nSTACK GUARD                       56.1M        5 \nStack                             10.1M        5 \nVM_ALLOCATE                       3232K        3 \n__DATA                            41.6M      688 \n__DATA_CONST                      91.9M      714 \n__DATA_DIRTY                       139K       13 \n__FONT_DATA                        2352        1 \n__LINKEDIT                       711.4M        9 \n__OBJC_RO                         62.5M        1 \n__OBJC_RW                         2771K        1 \n__TEXT                           916.2M      727 \n__TPRO_CONST                       148K        2 \ndyld private memory                2.2G       19 \nmapped file                      269.8M       23 \npage table in kernel              2035K        1 \nshared memory                     1040K        2 \n===========                     =======  ======= \nTOTAL                              5.0G     2350 \n",
  "legacyInfo" : {
  "threadTriggered" : {
    "queue" : "com.apple.main-thread"
  }
},
  "logWritingSignature" : "5cdfed62429ef67ffeb0cc32f306637acc3e2e24",
  "bug_type" : "309",
  "roots_installed" : 0,
  "trmStatus" : 1,
  "trialInfo" : {
  "rollouts" : [
    {
      "rolloutId" : "6297d96be2c9387df974efa4",
      "factorPackIds" : [

      ],
      "deploymentId" : 240000032
    },
    {
      "rolloutId" : "60186475825c62000ccf5450",
      "factorPackIds" : [

      ],
      "deploymentId" : 240000083
    }
  ],
  "experiments" : [

  ]
}
}

Model: Mac14,9, BootROM 13822.61.10, proc 10:6:4 processors, 16 GB, SMC 
Graphics: Apple M2 Pro, Apple M2 Pro, Built-In
Display: LG ULTRAWIDE, 2560 x 1080 (UW-UXGA - Ultra Wide - Ultra Extended Graphics Array), Main, MirrorOff, Online
Display: LG FULL HD, 1920 x 1080 (1080p FHD - Full High Definition), MirrorOff, Online
Display: Sidecar Display, 2388 x 1668, MirrorOff
Memory Module: LPDDR5, Hynix
AirPort: spairport_wireless_card_type_wifi (0x14E4, 0x4388), wl0: Oct  3 2025 00:48:21 version 23.41.7.0.41.51.200 FWID 01-0473880e
IO80211_driverkit-1533.5 "IO80211_driverkit-1533.5" Nov 14 2025 18:26:34
AirPort: 
Bluetooth: Version (null), 0 services, 0 devices, 0 incoming serial ports
Network Service: Wi-Fi, AirPort, en0
Thunderbolt Bus: MacBook Pro, Apple Inc.
Thunderbolt Bus: MacBook Pro, Apple Inc.
Thunderbolt Bus: MacBook Pro, Apple Inc.
