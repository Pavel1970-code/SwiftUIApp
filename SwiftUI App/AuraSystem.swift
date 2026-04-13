import Foundation
import SwiftUI

// MARK: - Domain (скрытая модель; в UI не показываем числа)

enum AuraInteractionKind: String, Codable, CaseIterable {
    case thanksSent
    case thanksReceived
    case donationSent
    case donationReceived

    var isOutgoing: Bool {
        switch self {
        case .thanksSent, .donationSent: return true
        case .thanksReceived, .donationReceived: return false
        }
    }
}

/// Флаги контекста (локация и т.д.) — пока вручную / из будущего CoreLocation.
struct AuraContextFlags: Equatable {
    var isPublicPlace: Bool = false
    var isWorkZone: Bool = false
}

struct AuraLedgerEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let kind: AuraInteractionKind
    let peerId: UUID?
    /// Произведение множителей (для будущего синка / отладки; пользователю не показываем).
    let multiplierProduct: Double
    /// Вклад в «тёплое» кольцо; сумма ≈ 1.0 соответствует заполнению 15 сегментов.
    let warmDelta: Double
}

struct AuraVisualState: Equatable {
    /// Накопленное тепло 0...1 (15 сегментов ≈ 1.0).
    var warmFill: Double
    var glow: Double
    var orbScale: CGFloat
    var pulsePeriod: Double
    var narrative: String

    static let initial = AuraVisualState(
        warmFill: 0.06,
        glow: 0.52,
        orbScale: 1.0,
        pulsePeriod: 3.2,
        narrative: "Аура спокойная и ясная."
    )
}

enum AuraPersistence {
    private static let ledgerKey = "aura_ledger_v1"
    private static let maxEntries = 500

    static func loadLedger() -> [AuraLedgerEntry] {
        guard let data = UserDefaults.standard.data(forKey: ledgerKey),
              let decoded = try? JSONDecoder().decode([AuraLedgerEntry].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.timestamp < $1.timestamp }
    }

    static func saveLedger(_ entries: [AuraLedgerEntry]) {
        let trimmed = Array(entries.suffix(maxEntries))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: ledgerKey)
        }
    }
}

enum AuraEngine {
    private static let segmentUnit = 1.0 / 15.0
    private static let maxWarmTotal = 1.0
    private static let fastLoopWindow: TimeInterval = 120
    private static let burstWindow: TimeInterval = 300
    private static let burstCountThreshold = 4
    private static let repeatWindowDays = 7
    private static let rareWindowDays = 60
    private static let rarePriorReceivedMax = 2

    static func visualState(from ledger: [AuraLedgerEntry]) -> AuraVisualState {
        let totalWarm = min(maxWarmTotal, ledger.reduce(0) { $0 + $1.warmDelta })
        let warmFillRaw = maxWarmTotal > 0 ? totalWarm / maxWarmTotal : 0
        let warmFill = min(1, max(0.04, warmFillRaw))

        let glow = 0.42 + warmFill * 0.48
        let orbScale = 1.0 + CGFloat(warmFill) * 0.08
        let pulsePeriod = max(1.85, 3.35 - warmFill * 0.95)

        let narrative: String
        switch warmFill {
        case ..<0.12:
            narrative = "Аура спокойная и ясная."
        case ..<0.35:
            narrative = "Аура чуть теплеет — это про качество контакта, не про количество."
        case ..<0.62:
            narrative = "Твоя аура стала теплее сегодня."
        case ..<0.82:
            narrative = "Связи сегодня ощущаются особенно живыми."
        default:
            narrative = "Аура наполнена теплом — след в мире заметен."
        }

        return AuraVisualState(
            warmFill: warmFill,
            glow: glow,
            orbScale: orbScale,
            pulsePeriod: pulsePeriod,
            narrative: narrative
        )
    }

    static func makeEntry(
        existingLedger: [AuraLedgerEntry],
        kind: AuraInteractionKind,
        peerId: UUID?,
        date: Date = Date(),
        flags: AuraContextFlags = AuraContextFlags()
    ) -> AuraLedgerEntry {
        var factors: [Double] = []

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        if hour < 10 {
            factors.append(1.5)
        }

        if let pid = peerId {
            let repeated = hadInteraction(with: pid, withinDays: repeatWindowDays, strictlyBefore: date, ledger: existingLedger)
            factors.append(repeated ? 0.3 : 2.0)

            if kind == .thanksReceived || kind == .donationReceived {
                let priorIn = receivedCount(from: pid, withinDays: rareWindowDays, strictlyBefore: date, ledger: existingLedger)
                if priorIn <= rarePriorReceivedMax {
                    factors.append(1.7)
                }
            }
        } else {
            factors.append(0.85)
        }

        if flags.isPublicPlace { factors.append(1.5) }
        if flags.isWorkZone { factors.append(0.1) }

        if let pid = peerId, isFastLoop(ledger: existingLedger, peerId: pid, kind: kind, at: date) {
            factors.append(0.1)
        }

        if burstPenalty(ledger: existingLedger, at: date) {
            factors.append(0.35)
        }

        let product = factors.reduce(1.0, *)
        let shaped = min(3.2, sqrt(max(0.01, product)))
        var warmDelta = segmentUnit * shaped * 0.9
        warmDelta += morningClusterBonus(ledger: existingLedger, newDate: date)
        warmDelta = max(0.000_05, warmDelta)

        return AuraLedgerEntry(
            id: UUID(),
            timestamp: date,
            kind: kind,
            peerId: peerId,
            multiplierProduct: product,
            warmDelta: warmDelta
        )
    }

    private static func hadInteraction(
        with peerId: UUID,
        withinDays days: Int,
        strictlyBefore date: Date,
        ledger: [AuraLedgerEntry]
    ) -> Bool {
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: date) else { return false }
        return ledger.contains { $0.peerId == peerId && $0.timestamp >= start && $0.timestamp < date }
    }

    private static func receivedCount(
        from peerId: UUID,
        withinDays days: Int,
        strictlyBefore date: Date,
        ledger: [AuraLedgerEntry]
    ) -> Int {
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: date) else { return 0 }
        return ledger.filter { entry in
            guard entry.peerId == peerId else { return false }
            guard entry.timestamp >= start && entry.timestamp < date else { return false }
            return entry.kind == .thanksReceived || entry.kind == .donationReceived
        }.count
    }

    private static func isFastLoop(
        ledger: [AuraLedgerEntry],
        peerId: UUID,
        kind: AuraInteractionKind,
        at date: Date
    ) -> Bool {
        guard let last = ledger
            .filter({ $0.peerId == peerId })
            .max(by: { $0.timestamp < $1.timestamp }) else { return false }
        let dt = date.timeIntervalSince(last.timestamp)
        guard dt > 0, dt < fastLoopWindow else { return false }
        return last.kind.isOutgoing != kind.isOutgoing
    }

    private static func burstPenalty(ledger: [AuraLedgerEntry], at date: Date) -> Bool {
        let start = date.addingTimeInterval(-burstWindow)
        let n = ledger.filter { $0.timestamp >= start && $0.timestamp < date }.count
        return n >= burstCountThreshold
    }

    private static func morningClusterBonus(ledger: [AuraLedgerEntry], newDate: Date) -> Double {
        let cal = Calendar.current
        guard cal.component(.hour, from: newDate) < 12 else { return 0 }
        let startOfDay = cal.startOfDay(for: newDate)
        guard let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: newDate) else { return 0 }
        let priorSameMorning = ledger.filter {
            $0.timestamp >= startOfDay && $0.timestamp < newDate && $0.timestamp < noon
        }
        let countWithNew = priorSameMorning.count + 1
        if (3...5).contains(countWithNew) {
            return segmentUnit * 0.12
        }
        return 0
    }
}

// MARK: - Визуал: 15 сегментов + пульсация (без цифр)

struct AuraOrbView: View {
    let state: AuraVisualState
    var diameter: CGFloat = 168

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 1.0 + 0.018 * sin(t * (2 * .pi / state.pulsePeriod))
            AuraFifteenSegmentOrb(warmFill: state.warmFill, glow: state.glow)
                .frame(width: diameter, height: diameter)
                .scaleEffect(pulse * state.orbScale)
        }
    }
}

private struct AuraFifteenSegmentOrb: View {
    let warmFill: Double
    let glow: Double

    private let segmentCount = 15
    private let coolInner = Color(red: 0.32, green: 0.55, blue: 0.92)
    private let coolOuter = Color(red: 0.12, green: 0.28, blue: 0.55)
    private let warmInner = Color(red: 0.72, green: 0.38, blue: 0.88)
    private let warmOuter = Color(red: 0.95, green: 0.42, blue: 0.62)

    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 * 0.92
            let innerR = r * 0.38

            let baseCircle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            context.fill(
                baseCircle,
                with: .radialGradient(
                    Gradient(colors: [coolInner, coolOuter]),
                    center: c,
                    startRadius: innerR * 0.2,
                    endRadius: r * 1.05
                )
            )

            let warmPortion = min(1, max(0, warmFill))
            let fullSegments = warmPortion * Double(segmentCount)
            let whole = Int(floor(fullSegments))
            let frac = CGFloat(fullSegments - Double(whole))

            let gap: CGFloat = 0.04
            let segAngle = (2 * CGFloat.pi / CGFloat(segmentCount))
            var a: CGFloat = -.pi / 2

            for i in 0..<segmentCount {
                let t = CGFloat(i) / CGFloat(segmentCount)
                var span = segAngle - gap
                if i >= whole {
                    if i == whole {
                        span *= frac
                    } else {
                        span = 0
                    }
                }
                if span > 0.0001 {
                    var wedge = Path()
                    wedge.move(to: c)
                    wedge.addArc(
                        center: c,
                        radius: r * 1.02,
                        startAngle: .radians(Double(a)),
                        endAngle: .radians(Double(a + span)),
                        clockwise: false
                    )
                    wedge.closeSubpath()

                    let warmAlpha = 0.35 + glow * 0.45
                    let mix = warmInner.opacity(0.15 + warmAlpha * (0.35 + t * 0.35))
                    context.fill(
                        wedge,
                        with: .radialGradient(
                            Gradient(colors: [mix, warmOuter.opacity(warmAlpha)]),
                            center: CGPoint(x: c.x + cos(Double(a + span / 2)) * r * 0.35, y: c.y + sin(Double(a + span / 2)) * r * 0.35),
                            startRadius: 2,
                            endRadius: r * 1.1
                        )
                    )
                }
                a += segAngle
            }

            context.stroke(
                Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                with: .color(Color.white.opacity(0.22 + glow * 0.18)),
                lineWidth: 1.2
            )
        }
        .drawingGroup(opaque: false)
    }
}
