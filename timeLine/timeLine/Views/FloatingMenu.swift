import SwiftUI

struct FloatingMenu: View {
    @State private var isExpanded = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var showResetConfirmation = false
    
    @EnvironmentObject var stateManager: AppStateManager
    
    var body: some View {
        VStack(spacing: 12) {
            // 展开的菜单项（从下往上显示）
            if isExpanded {
                VStack(spacing: 12) {
                    // Reset 按钮 - 放在最上面，红色警告色
                    MenuButton(
                        icon: "arrow.counterclockwise.circle.fill",
                        label: "Reset",
                        color: .red
                    ) {
                        showResetConfirmation = true
                    }
                    
                    // Help按钮
                    MenuButton(
                        icon: "questionmark.circle.fill",
                        label: "Help",
                        color: .blue
                    ) {
                        showHelp = true
                    }
                    
                    // Settings按钮
                    MenuButton(
                        icon: "gearshape.fill",
                        label: "Settings",
                        color: .gray
                    ) {
                        showSettings = true
                    }
                    
                    // Stats按钮
                    MenuButton(
                        icon: "chart.bar.fill",
                        label: "Stats",
                        color: .green
                    ) {
                        showStats = true
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            // 主菜单按钮（三道杠）
            Button(action: {
                // 触觉反馈
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .scaleEffect(isExpanded ? 1.1 : 1.0)
            }
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                // 触觉反馈
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                
                // 执行重置
                stateManager.resetAllData()
                
                // 自动收起菜单
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded = false
                }
                
                // 提示用户重启应用
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        // 显示重置成功提示
                        let alert = UIAlertController(
                            title: "重置成功",
                            message: "请关闭并重新打开应用以完成重置。",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "好的", style: .default) { _ in
                            // 退出应用
                            exit(0)
                        })
                        window.rootViewController?.present(alert, animated: true)
                    }
                }
            }
        } message: {
            Text("这将删除所有任务、历史和模板。\n此操作无法撤销！")
        }
    }
}

// 菜单按钮组件
struct MenuButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // 触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(label)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: color.opacity(0.3), radius: isPressed ? 2 : 4, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingMenu()
                    .padding()
            }
        }
    }
}