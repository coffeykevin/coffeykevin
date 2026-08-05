// The concept HUD in SwiftUI: weather+time top-left, full-width charcoal
// bar (PLAYER · POWER · WIND · ANGLE · PLAYER), title, debrief, and match
// end. tvOS has no Slider, so meters render read-only there and the Siri
// Remote / controller adjusts values through InputController.

import SwiftUI

private let bananaYellow = Color(red: 1.0, green: 0.788, blue: 0.235)
private let signalCyan = Color(red: 0.208, green: 0.769, blue: 0.941)
private let hudCharcoal = Color(red: 0.11, green: 0.125, blue: 0.15).opacity(0.94)

struct HUDView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        ZStack {
            VStack {
                topRow
                Spacer()
                if let d = engine.debrief { DebriefCard(d: d) }
                controlBar
            }
            if engine.state == .title { titleOverlay }
            if engine.state == .matchEnd { endOverlay }
        }
        .padding(12)
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.weatherName).font(.headline.weight(.heavy))
                Text(engine.weatherTime).font(.caption).opacity(0.8)
            }
            .foregroundColor(.white)
            .shadow(radius: 4)
            Spacer()
            Text(engine.banner)
                .font(.headline.weight(.heavy))
                .foregroundColor(engine.bannerIsP1 ? bananaYellow : signalCyan)
                .shadow(radius: 4)
            Spacer()
            Color.clear.frame(width: 80, height: 1)
        }
    }

    private var controlBar: some View {
        HStack(spacing: 18) {
            playerTag(name: "KILO", color: bananaYellow, score: engine.scores[0])
            meterGroup(label: "POWER", color: bananaYellow,
                       value: engine.power, range: 1...100,
                       set: { engine.setPower($0) })
            Text(engine.windText)
                .font(.title3.weight(.heavy))
                .foregroundColor(.white)
                .fixedSize()
            meterGroup(label: "ANGLE", color: signalCyan,
                       value: engine.angle, range: 0...90,
                       set: { engine.setAngle($0) })
            playerTag(name: "NEWTON", color: signalCyan, score: engine.scores[1])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(hudCharcoal)
        .cornerRadius(14)
    }

    private func playerTag(name: String, color: Color, score: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.headline.weight(.heavy)).foregroundColor(color)
            HStack(spacing: 4) {
                ForEach(0..<GameEngine.pointsToWin, id: \.self) { i in
                    Circle()
                        .fill(i < score ? color : Color.clear)
                        .overlay(Circle().stroke(color.opacity(0.6), lineWidth: 1))
                        .frame(width: 7, height: 7)
                }
            }
        }
    }

    private func meterGroup(label: String, color: Color, value: Double,
                            range: ClosedRange<Double>,
                            set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 10) {
            Text("\(Int(value))\(label == "ANGLE" ? "°" : "")")
                .font(.title.weight(.heavy))
                .foregroundColor(.white)
                .monospacedDigit()
                .frame(minWidth: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2.weight(.heavy))
                    .foregroundColor(color).kerning(2)
                #if os(tvOS)
                ProgressView(value: value, total: range.upperBound)
                    .tint(color)
                #else
                Slider(value: Binding(get: { value }, set: set), in: range)
                    .tint(color)
                #endif
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var titleOverlay: some View {
        VStack(spacing: 16) {
            Text("BANANARC")
                .font(.system(size: 64, weight: .black))
                .foregroundColor(bananaYellow)
            Text("ANGLE · POWER · BANANAS")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
                .kerning(2)
            Button("Hot-Seat Duel (2 players)") { engine.startMatch(vsAI: false) }
                .buttonStyle(.borderedProminent)
            Button("Solo vs. Newton (AI)") { engine.startMatch(vsAI: true) }
                .buttonStyle(.bordered)
            Text(platformHint)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.82))
    }

    private var platformHint: String {
        #if os(tvOS)
        return "Swipe up/down for angle, left/right for power.\nPress the touch surface to throw."
        #elseif os(macOS)
        return "Drag the meters or use a controller.\nSpace or controller A to throw."
        #else
        return "Drag the meters, then tap the city to throw.\nControllers welcome — A to throw."
        #endif
    }

    private var endOverlay: some View {
        VStack(spacing: 16) {
            Text(engine.endText)
                .font(.system(size: 40, weight: .black))
                .foregroundColor(bananaYellow)
                .multilineTextAlignment(.center)
            Button("Rematch") { engine.rematch() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.82))
    }
}

struct DebriefCard: View {
    let d: DebriefInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("● \(d.who)")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(d.accentIsP1 ? bananaYellow : signalCyan)
                Text("THROW \(d.n)").font(.caption2).opacity(0.7)
            }
            row("Angle", "\(d.angle)°")
            row("Power", "\(d.power)")
            row("Flight", String(format: "%.1f s", d.time))
            row("Apex", "\(Int(d.apex)) m")
            row("Distance", "\(Int(d.dist)) m")
            HStack {
                Text("Wind drift").font(.caption)
                Spacer()
                Text("\(d.drift >= 0 ? "+" : "")\(Int(d.drift.rounded())) m \(d.drift >= 0 ? "→" : "←")")
                    .font(.caption.weight(.heavy))
            }
            .foregroundColor(signalCyan)
            if !d.note.isEmpty {
                Text(d.note).font(.caption2).opacity(0.6)
            }
        }
        .foregroundColor(.white)
        .padding(12)
        .frame(maxWidth: 230)
        .background(hudCharcoal)
        .cornerRadius(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private func row(_ l: String, _ v: String) -> some View {
        HStack {
            Text(l).font(.caption).opacity(0.7)
            Spacer()
            Text(v).font(.caption.weight(.semibold)).monospacedDigit()
        }
    }
}
