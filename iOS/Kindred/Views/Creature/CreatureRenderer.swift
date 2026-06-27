import SwiftUI

// MARK: - Visual parameters derived from the creature

struct CreatureGeometry {
    let bodyWidth:      CGFloat   // relative to canvas size
    let bodyHeight:     CGFloat
    let angularity:     Double    // 0 = smooth blob, 1 = sharp angles
    let asymmetry:      Double    // 0 = symmetric, 1 = lopsided (FERAL)
    let primaryColor:   Color
    let accentColor:    Color
    let eyeScale:       Double    // 0.5–1.5, driven by bond
    let eyeOpenness:    Double    // 0–1, driven by happiness
    let spikeCount:     Int       // 0–6, nocturnality for FERAL
    let auraOpacity:    Double    // apex glow

    static func from(creature: Creature) -> CreatureGeometry {
        let traits = creature.traits
        let branch = creature.branch

        switch creature.stage {
        case .egg:
            return CreatureGeometry(
                bodyWidth: 0.45, bodyHeight: 0.55,
                angularity: 0, asymmetry: 0,
                primaryColor: Color(white: 0.88),
                accentColor: Color(white: 0.75),
                eyeScale: 0, eyeOpenness: 0,
                spikeCount: 0, auraOpacity: 0
            )
        case .blob:
            return CreatureGeometry(
                bodyWidth: 0.52, bodyHeight: 0.48,
                angularity: 0.05, asymmetry: 0.05,
                primaryColor: Color(white: 0.82),
                accentColor: Color(white: 0.65),
                eyeScale: 0.6 + (traits.bond / 100) * 0.4,
                eyeOpenness: 0.5,
                spikeCount: 0, auraOpacity: 0
            )
        case .juvenile:
            // Subtle tint toward dominant axis — hints at eventual form without declaring it
            let dominantColor = dominantAxisColor(traits: traits)
            return CreatureGeometry(
                bodyWidth: 0.50, bodyHeight: 0.50,
                angularity: 0.08, asymmetry: 0.08,
                primaryColor: Color(white: 0.80).blended(with: dominantColor, fraction: 0.18),
                accentColor: Color(white: 0.65),
                eyeScale: 0.65 + (traits.bond / 100) * 0.35,
                eyeOpenness: 0.55,
                spikeCount: 0, auraOpacity: 0
            )
        default:
            return geometry(for: branch ?? .drifter, traits: traits, isApex: creature.stage == .apex)
        }
    }

    private static func geometry(for branch: Branch, traits: TraitVector, isApex: Bool) -> CreatureGeometry {
        let eyeScale    = 0.5 + (traits.bond / 100) * 0.8
        let eyeOpn      = 0.4 + (traits.bond / 100) * 0.5
        let aura        = isApex ? 0.35 : 0.0

        switch branch {
        case .swift_:
            return CreatureGeometry(
                bodyWidth: 0.38, bodyHeight: 0.68,
                angularity: 0.6, asymmetry: 0.1,
                primaryColor: KColor.branchSwift,
                accentColor: .white,
                eyeScale: eyeScale, eyeOpenness: eyeOpn + 0.15,
                spikeCount: 0, auraOpacity: aura
            )
        case .feral:
            return CreatureGeometry(
                bodyWidth: 0.5, bodyHeight: 0.52,
                angularity: 0.8, asymmetry: 0.35,
                primaryColor: KColor.branchFeral,
                accentColor: Color(hex: "#C084FC"),
                eyeScale: eyeScale * 0.7, eyeOpenness: eyeOpn * 0.5,
                spikeCount: max(3, Int(traits.nocturnality / 18)),
                auraOpacity: aura
            )
        case .bonded:
            return CreatureGeometry(
                bodyWidth: 0.58, bodyHeight: 0.5,
                angularity: 0.05, asymmetry: 0,
                primaryColor: KColor.branchBonded,
                accentColor: Color(hex: "#FDE68A"),
                eyeScale: eyeScale * 1.2, eyeOpenness: eyeOpn + 0.2,
                spikeCount: 0, auraOpacity: aura
            )
        case .stalwart:
            return CreatureGeometry(
                bodyWidth: 0.62, bodyHeight: 0.54,
                angularity: 0.4, asymmetry: 0,
                primaryColor: KColor.branchStalwart,
                accentColor: Color(hex: "#6EE7B7"),
                eyeScale: eyeScale, eyeOpenness: eyeOpn,
                spikeCount: 0, auraOpacity: aura
            )
        case .distant:
            return CreatureGeometry(
                bodyWidth: 0.44, bodyHeight: 0.56,
                angularity: 0.75, asymmetry: 0.1,
                primaryColor: KColor.branchDistant,
                accentColor: Color(white: 0.55),
                eyeScale: eyeScale * 0.6, eyeOpenness: eyeOpn * 0.35,
                spikeCount: 0, auraOpacity: aura
            )
        case .drifter:
            return CreatureGeometry(
                bodyWidth: 0.5, bodyHeight: 0.5,
                angularity: 0.2, asymmetry: 0.05,
                primaryColor: KColor.branchDrifter,
                accentColor: Color(white: 0.7),
                eyeScale: eyeScale, eyeOpenness: eyeOpn,
                spikeCount: 0, auraOpacity: aura
            )
        }
    }
}

// MARK: - Renderer

struct CreatureRenderer: View {
    let creature: Creature
    @State private var breathePhase: Double = 0
    @State private var blinkPhase: Double = 0

    private var geo: CreatureGeometry { CreatureGeometry.from(creature: creature) }

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width  / 2
            let cy = size.height / 2

            let bW = size.width  * geo.bodyWidth
            let bH = size.height * geo.bodyHeight

            // Breathe offset: subtle vertical pulse
            let breathe = sin(breathePhase) * 3.0

            // Apex aura
            if geo.auraOpacity > 0 {
                let auraRect = CGRect(x: cx - bW * 0.7, y: cy - bH * 0.7 + breathe,
                                      width: bW * 1.4, height: bH * 1.4)
                ctx.fill(
                    Path(ellipseIn: auraRect),
                    with: .color(geo.primaryColor.opacity(geo.auraOpacity))
                )
            }

            // Body
            let bodyPath = buildBody(cx: cx, cy: cy + breathe, width: bW, height: bH, geo: geo)
            ctx.fill(bodyPath, with: .color(geo.primaryColor))

            // Spikes (FERAL branch)
            if geo.spikeCount > 0 {
                let spikePath = buildSpikes(cx: cx, cy: cy + breathe, width: bW, height: bH, count: geo.spikeCount, asymmetry: geo.asymmetry)
                ctx.fill(spikePath, with: .color(geo.accentColor.opacity(0.8)))
            }

            // Eyes
            if geo.eyeScale > 0 {
                drawEyes(ctx: ctx, cx: cx, cy: cy + breathe, width: bW, height: bH, geo: geo, blink: blinkPhase)
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: Body path

    private func buildBody(cx: Double, cy: Double, width: Double, height: Double, geo: CreatureGeometry) -> Path {
        let ang = geo.angularity
        let asym = geo.asymmetry * 10

        // Interpolate between smooth ellipse (ang=0) and angular shape (ang=1)
        // using a bezier quad approximation
        let hw = width  / 2
        let hh = height / 2

        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy - hh))

        // Top-right
        path.addQuadCurve(
            to:          CGPoint(x: cx + hw + asym, y: cy),
            control:     CGPoint(x: cx + hw * (1 - ang * 0.3) + asym, y: cy - hh * (1 - ang * 0.3))
        )
        // Bottom-right
        path.addQuadCurve(
            to:          CGPoint(x: cx, y: cy + hh),
            control:     CGPoint(x: cx + hw * (1 - ang * 0.3) + asym, y: cy + hh * (1 - ang * 0.3))
        )
        // Bottom-left
        path.addQuadCurve(
            to:          CGPoint(x: cx - hw, y: cy),
            control:     CGPoint(x: cx - hw * (1 - ang * 0.3), y: cy + hh * (1 - ang * 0.3))
        )
        // Top-left
        path.addQuadCurve(
            to:          CGPoint(x: cx, y: cy - hh),
            control:     CGPoint(x: cx - hw * (1 - ang * 0.3), y: cy - hh * (1 - ang * 0.3))
        )
        path.closeSubpath()
        return path
    }

    // MARK: Spikes

    private func buildSpikes(cx: Double, cy: Double, width: Double, height: Double, count: Int, asymmetry: Double) -> Path {
        var path = Path()
        let hw = width / 2
        let hh = height / 2
        let spikeLength = min(hw, hh) * 0.35

        for i in 0..<count {
            let angle = (Double(i) / Double(count)) * .pi * 2 - .pi / 2
            let offsetAngle = asymmetry * 0.3 * Double(i % 2 == 0 ? 1 : -1)
            let baseAngle = angle + offsetAngle
            let nx = cos(baseAngle)
            let ny = sin(baseAngle)
            // Spike base: two points straddling the body surface
            let bx = cx + nx * hw * 0.85
            let by = cy + ny * hh * 0.85
            let tipX = cx + nx * (hw + spikeLength)
            let tipY = cy + ny * (hh + spikeLength)
            let perpAngle = baseAngle + .pi / 2
            let halfBase: Double = 5
            path.move(to: CGPoint(x: bx + cos(perpAngle) * halfBase, y: by + sin(perpAngle) * halfBase))
            path.addLine(to: CGPoint(x: tipX, y: tipY))
            path.addLine(to: CGPoint(x: bx - cos(perpAngle) * halfBase, y: by - sin(perpAngle) * halfBase))
            path.closeSubpath()
        }
        return path
    }

    // MARK: Eyes

    private func drawEyes(ctx: GraphicsContext, cx: Double, cy: Double, width: Double, height: Double, geo: CreatureGeometry, blink: Double) {
        let eyeR = (width * 0.075) * geo.eyeScale
        let sep  = width  * 0.22
        let eyeY = cy - height * 0.08

        let blinkScaleY = blink > 0.9 ? max(0.05, 1 - (blink - 0.9) * 10) : 1.0

        for sign in [-1.0, 1.0] {
            let ex = cx + sign * sep
            let pupilColor = geo.primaryColor == KColor.branchFeral ? Color.red.opacity(0.8) : KColor.textPrimary
            // White sclera
            ctx.fill(
                Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR * blinkScaleY,
                                       width: eyeR * 2, height: eyeR * 2 * blinkScaleY)),
                with: .color(.white)
            )
            // Pupil
            let pupilR = eyeR * 0.55 * geo.eyeOpenness
            ctx.fill(
                Path(ellipseIn: CGRect(x: ex - pupilR, y: eyeY - pupilR * blinkScaleY,
                                       width: pupilR * 2, height: pupilR * 2 * blinkScaleY)),
                with: .color(pupilColor)
            )
        }
    }

    // MARK: Animation

    private func startAnimations() {
        // Breathe: ~3 s cycle
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            breathePhase = .pi
        }
        // Blink: every ~4 s
        Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.linear(duration: 0.12)) { self.blinkPhase = 1.0 }
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.linear(duration: 0.12)) { self.blinkPhase = 0.0 }
            }
        }
    }
}

// MARK: - Dominant axis tint (juvenile hint)

private func dominantAxisColor(traits: TraitVector) -> Color {
    let axes: [(Double, Color)] = [
        (traits.vigor,        KColor.branchSwift),
        (traits.nocturnality, KColor.branchFeral),
        (traits.bond,         KColor.branchBonded),
        (traits.discipline,   KColor.branchStalwart)
    ]
    return axes.max(by: { $0.0 < $1.0 })?.1 ?? KColor.branchDrifter
}

// MARK: - Hex color (local duplicate-safe)
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    func blended(with other: Color, fraction: Double) -> Color {
        let f = max(0, min(1, fraction))
        let resolved  = UIColor(self)
        let resolvedO = UIColor(other)
        var r1: CGFloat = 0; var g1: CGFloat = 0; var b1: CGFloat = 0; var a1: CGFloat = 0
        var r2: CGFloat = 0; var g2: CGFloat = 0; var b2: CGFloat = 0; var a2: CGFloat = 0
        resolved.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        resolvedO.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red:   Double(r1) * (1 - f) + Double(r2) * f,
            green: Double(g1) * (1 - f) + Double(g2) * f,
            blue:  Double(b1) * (1 - f) + Double(b2) * f
        )
    }
}
