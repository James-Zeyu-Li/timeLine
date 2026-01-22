import SwiftUI

struct SparkleEmitter: View {
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var velocityX: CGFloat
        var velocityY: CGFloat
        var scale: CGFloat
        var opacity: Double
        var hue: Double
        var createdAt: Date
        var lifespane: TimeInterval
    }
    
    @State private var particles: [Particle] = []
    @State private var lastUpdate: Date = Date()
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Set origin to center
                context.translateBy(x: size.width / 2, y: size.height / 2)
                
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x - (4 * particle.scale),
                        y: particle.y - (4 * particle.scale),
                        width: 8 * particle.scale,
                        height: 8 * particle.scale
                    )
                    
                    var pContext = context
                    pContext.opacity = particle.opacity
                    pContext.blendMode = .plusLighter
                    
                    // Core
                    pContext.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color(hue: particle.hue, saturation: 0.2, brightness: 1.0))
                    )
                    
                    // Glow
                    pContext.addFilter(.blur(radius: 2))
                    pContext.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color(hue: particle.hue, saturation: 0.8, brightness: 1.0))
                    )
                }
            }
            .onChange(of: timeline.date) { _, newDate in
                updateParticles(currentDate: newDate)
            }
        }
    }
    
    private func updateParticles(currentDate: Date) {
        let deltaTime = currentDate.timeIntervalSince(lastUpdate)
        lastUpdate = currentDate
        
        // 1. Emit new particles (more frequently)
        // Emit 2 particles per frame approx
        for _ in 0..<2 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 10...50)
            
            let newSparkle = Particle(
                x: 0, // Emit from center
                y: 0,
                velocityX: cos(angle) * speed,
                velocityY: sin(angle) * speed,
                scale: CGFloat.random(in: 0.5...1.2),
                opacity: 1.0,
                hue: Double.random(in: 0.12...0.18), // Gold/Yellow range
                createdAt: currentDate,
                lifespane: Double.random(in: 0.5...1.0)
            )
            particles.append(newSparkle)
        }
        
        // 2. Update existing
        for i in particles.indices {
            let p = particles[i]
            particles[i].x += p.velocityX * CGFloat(deltaTime)
            particles[i].y += p.velocityY * CGFloat(deltaTime)
            particles[i].velocityY += 100 * CGFloat(deltaTime) // Gravity
            particles[i].opacity -= 1.5 * deltaTime
            particles[i].scale *= (1.0 - (0.5 * deltaTime))
        }
        
        // 3. Cleanup
        particles.removeAll { $0.opacity <= 0 }
    }
}
