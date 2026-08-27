import SwiftUI

struct HJCard<Content: View>: View { @ViewBuilder let content: Content; var body: some View { content.hjCard() } }

enum HJHeroReaction: Equatable { case opening, logged, goalReached, supportive }

private enum HJHeroDayPart: String {
    case sunrise = "Sunrise", day = "Day", sunset = "Sunset", night = "Night"

    static func current(at date: Date = Date(), calendar: Calendar = .current) -> Self {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--hero-time"), arguments.indices.contains(index + 1),
           let preview = Self(rawValue: arguments[index + 1].capitalized) { return preview }
        switch calendar.component(.hour, from: date) {
        case 5..<10: return .sunrise
        case 10..<17: return .day
        case 17..<20: return .sunset
        default: return .night
        }
    }

    var assetName: String { "TodayHeroBackground-\(rawValue)-v1" }
}

extension HJHeroReaction {
    static var launchPreview: HJHeroReaction? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--hero-reaction"), arguments.indices.contains(index + 1) else { return nil }
        return ["opening": .opening, "logged": .logged, "goalReached": .goalReached, "supportive": .supportive][arguments[index + 1]]
    }
}

struct HJAnimatedHero: View {
    let reaction: HJHeroReaction
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var reactionStarted = Date()
    @State private var dayPart = HJHeroDayPart.current()
    private var previewElapsed: TimeInterval? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--hero-frame"), arguments.indices.contains(index + 1) else { return nil }
        return TimeInterval(arguments[index + 1])
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || previewElapsed != nil)) { timeline in
            let elapsed = previewElapsed ?? max(0, timeline.date.timeIntervalSince(reactionStarted))
            let motion = values(at: elapsed)
            ZStack {
                HJBundleImage(name: dayPart.assetName)
                    .scaledToFill()
                    .scaleEffect(1.04)
                    .id(dayPart)
                    .transition(.opacity)
                Ellipse()
                    .fill(HJColor.navy.opacity(0.13))
                    .frame(width: 104, height: 12)
                    .blur(radius: 3)
                    .offset(x: 103, y: 70)
                otterRig(motion: motion)
                if !reduceMotion && motion.sparkleOpacity > 0 {
                    Image(systemName: "sparkles")
                        .font(.title2.bold())
                        .foregroundStyle(HJColor.yellow)
                        .shadow(color: .white, radius: 2)
                        .offset(x: 121, y: -54)
                        .opacity(motion.sparkleOpacity)
                        .scaleEffect(0.8 + motion.sparkleOpacity * 0.35)
                        .accessibilityHidden(true)
                }
            }
        }
        .clipped()
        .onAppear { reactionStarted = Date() }
        .onChange(of: trigger) { _, _ in reactionStarted = Date() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { updateDayPart() } }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                updateDayPart()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.4), value: dayPart)
        .accessibilityLabel("Otter companion by the lake")
        .accessibilityIdentifier("today.hero")
    }

    private func updateDayPart() {
        let next = HJHeroDayPart.current()
        guard next != dayPart else { return }
        if reduceMotion { dayPart = next }
        else { withAnimation(.easeInOut(duration: 1.4)) { dayPart = next } }
    }

    private func otterRig(motion: HJHeroMotion) -> some View {
        let still = reduceMotion
        return ZStack {
            otterLayer()

            // These overlays reuse the registered master painting, so every edge and
            // brush stroke remains pixel-identical while SwiftUI owns the motion.
            otterPart(.tail)
                .rotationEffect(.degrees(still ? 0 : motion.tail), anchor: UnitPoint(x: 0.61, y: 0.73))
            otterPart(.leftEar)
                .rotationEffect(.degrees(still ? 0 : -motion.ears), anchor: UnitPoint(x: 0.34, y: 0.23))
            otterPart(.rightEar)
                .rotationEffect(.degrees(still ? 0 : motion.ears), anchor: UnitPoint(x: 0.58, y: 0.24))
            otterPart(.backpack)
                .rotationEffect(.degrees(still ? 0 : motion.backpack), anchor: UnitPoint(x: 0.60, y: 0.62))
            otterPart(.frontPaw)
                .rotationEffect(.degrees(still ? 0 : motion.paw), anchor: UnitPoint(x: 0.58, y: 0.46))

            if !still {
                HJHeroEyelids(closedAmount: motion.blink)
            }
        }
        .frame(width: 202, height: 190)
        .scaleEffect(still ? 1 : motion.scale, anchor: .bottom)
        .rotationEffect(.degrees(still ? 0 : motion.rotation), anchor: .bottomTrailing)
        .offset(x: 101 + (still ? 0 : motion.x), y: 7 + (still ? 0 : motion.y))
    }

    private func otterLayer() -> some View {
        HJBundleImage(name: "TodayOtterLayer-v1").scaledToFit().frame(width: 202, height: 190)
    }

    private func otterPart(_ part: HJHeroPartMask.Part) -> some View {
        otterLayer().mask(HJHeroPartMask(part: part).frame(width: 202, height: 190))
    }

    private func values(at elapsed: TimeInterval) -> HJHeroMotion {
        let breathing = 1 + sin(elapsed * .pi * 2 / 5) * 0.006
        let idlePhase = elapsed.truncatingRemainder(dividingBy: 5)
        let blink = max(0, 1 - abs(idlePhase - 3.72) / 0.11)
        let ears = sin(elapsed * .pi * 2 / 5) * 0.8
        let tail = sin(elapsed * .pi * 2 / 5 + 0.7) * 0.55
        let duration = reaction == .opening ? 1.2 : 1.35
        guard elapsed < duration else { return HJHeroMotion(scale: breathing, blink: blink, ears: ears, tail: tail) }
        let t = elapsed / duration
        switch reaction {
        case .opening:
            return HJHeroMotion(scale: breathing, rotation: sin(t * .pi * 2) * 1.1, x: sin(t * .pi * 2) * 2.5, blink: blink, ears: ears, tail: tail, backpack: sin(t * .pi) * 1.4, paw: -sin(t * .pi) * 1.2)
        case .logged:
            return HJHeroMotion(scale: breathing, rotation: sin(t * .pi * 2) * 1.5, y: sin(t * .pi) * 2, sparkleOpacity: sin(t * .pi), blink: blink, ears: ears + sin(t * .pi) * 1.1, tail: tail + sin(t * .pi) * 1.4)
        case .goalReached:
            return HJHeroMotion(scale: breathing + sin(t * .pi) * 0.035, rotation: sin(t * .pi * 2) * 1.2, y: -sin(t * .pi) * 10, sparkleOpacity: sin(t * .pi), blink: blink, ears: ears + sin(t * .pi) * 1.4, tail: tail + sin(t * .pi * 2) * 2, paw: -sin(t * .pi) * 2.5)
        case .supportive:
            return HJHeroMotion(scale: breathing + sin(t * .pi) * 0.012, x: sin(t * .pi * 2) * 1.5, blink: blink, ears: ears, tail: tail * 0.45)
        }
    }
}

private struct HJHeroMotion {
    var scale = 1.0; var rotation = 0.0; var x = 0.0; var y = 0.0; var sparkleOpacity = 0.0
    var blink = 0.0; var ears = 0.0; var tail = 0.0; var backpack = 0.0; var paw = 0.0
}

private struct HJHeroPartMask: Shape {
    enum Part { case leftEar, rightEar, tail, backpack, frontPaw }
    let part: Part
    func path(in rect: CGRect) -> Path {
        func box(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> CGRect {
            CGRect(x: rect.width * x, y: rect.height * y, width: rect.width * width, height: rect.height * height)
        }
        var path = Path()
        switch part {
        case .leftEar: path.addEllipse(in: box(0.27, 0.13, 0.13, 0.16))
        case .rightEar: path.addEllipse(in: box(0.56, 0.14, 0.14, 0.17))
        case .tail: path.addEllipse(in: box(0.57, 0.59, 0.38, 0.29))
        case .backpack: path.addRoundedRect(in: box(0.57, 0.33, 0.30, 0.43), cornerSize: CGSize(width: 18, height: 18))
        case .frontPaw: path.addEllipse(in: box(0.48, 0.40, 0.22, 0.34))
        }
        return path
    }
}

private struct HJHeroEyelids: View {
    let closedAmount: Double
    var body: some View {
        ZStack {
            eyelid(x: 91, y: 39, rotation: -5)
            eyelid(x: 119, y: 40, rotation: 5)
        }
        .frame(width: 202, height: 190)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    private func eyelid(x: Double, y: Double, rotation: Double) -> some View {
        Capsule()
            .fill(Color(red: 0.49, green: 0.31, blue: 0.16))
            .frame(width: 13, height: max(0.5, 12 * closedAmount))
            .overlay(Capsule().stroke(Color(red: 0.27, green: 0.18, blue: 0.10), lineWidth: closedAmount > 0.45 ? 0.7 : 0))
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
    }
}

struct HJCalorieRing: View {
    let remaining: Int; let goal: Int; let consumed: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var dayPart = HJHeroDayPart.current()
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize = 34.0
    var progress: Double { min(1, Double(consumed) / Double(goal)) }
    var isOver: Bool { remaining < 0 }
    var progressColor: Color {
        if isOver { return HJColor.coral }
        return dayPart == .night ? Color(hex: 0x55E6D5) : HJColor.teal
    }
    var trackColor: Color {
        if isOver { return HJColor.coral.opacity(0.15) }
        return (dayPart == .night ? Color(hex: 0xBCEDE8) : HJColor.teal).opacity(0.15)
    }
    var body: some View {
        ZStack {
            Circle().stroke(trackColor, lineWidth: 11)
            Circle().trim(from: 0, to: progress).stroke(progressColor, style: StrokeStyle(lineWidth: 11, lineCap: .round)).rotationEffect(.degrees(-90)).animation(.spring(response: 0.7, dampingFraction: 0.82), value: progress)
            VStack(spacing: 1) { Image(systemName: "flame.fill").foregroundStyle(HJColor.coral); Text(abs(remaining).formatted()).font(.system(size: valueSize, weight: .bold, design: .rounded)).contentTransition(.numericText()); Text(isOver ? "kcal over" : "kcal left").font(.subheadline.weight(.semibold)) }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.4), value: dayPart)
        .onChange(of: scenePhase) { _, phase in if phase == .active { updateDayPart() } }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                updateDayPart()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isOver ? "\(abs(remaining)) calories over your \(goal) calorie goal" : "\(remaining) calories left out of \(goal)")
    }

    private func updateDayPart() {
        let next = HJHeroDayPart.current()
        guard next != dayPart else { return }
        if reduceMotion { dayPart = next }
        else { withAnimation(.easeInOut(duration: 1.4)) { dayPart = next } }
    }
}

struct HJMacroCard: View {
    let title: String; let iconAsset: String; let consumed: Double; let goal: Double; let color: Color
    var isComplete: Bool { consumed >= goal }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) { HJBundleImage(name: iconAsset).scaledToFit().frame(width: 23, height: 23); Text(title).font(.subheadline.weight(.medium)); Spacer(); if isComplete { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(HJColor.teal) } }
            Text("\(Int(consumed)) / \(Int(goal)) g").font(.system(.body, design: .rounded, weight: .semibold))
            ProgressView(value: min(consumed, goal), total: goal).tint(isComplete ? HJColor.teal : color).scaleEffect(x: 1, y: 0.72)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 11).padding(.vertical, 9).background(HJColor.card).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(isComplete ? HJColor.teal.opacity(0.5) : HJColor.line)).shadow(color: HJColor.navy.opacity(0.035), radius: 5, y: 2).accessibilityElement(children: .ignore).accessibilityLabel("\(title), \(Int(consumed)) of \(Int(goal)) grams\(isComplete ? ", goal complete" : "")")
    }
}

struct HJMealRow: View {
    let meal: MealKind; let calories: Int
    var iconAsset: String { switch meal { case .breakfast: "MealBreakfast-v1"; case .lunch: "MealLunch-v1"; case .dinner: "MealDinner-v1"; case .snack: "MealSnack-v1" } }
    var displayName: String { meal == .snack ? "Snacks" : meal.rawValue }
    var body: some View { HStack(spacing: 10) { HJBundleImage(name: iconAsset).scaledToFit().frame(width: 34, height: 34).accessibilityHidden(true); Text(displayName).fontWeight(.semibold); Spacer(); Text("\(calories) kcal").fontWeight(.semibold).contentTransition(.numericText()); Image(systemName: "chevron.right").font(.caption).foregroundStyle(HJColor.slate) }.frame(minHeight: 46).contentShape(Rectangle()).accessibilityElement(children: .combine).accessibilityHint("Opens logged foods for \(displayName)") }
}

struct HJFoodRow: View {
    let food: Food
    var body: some View { HStack(spacing: 12) { Text(food.emoji).font(.system(size: 38)); VStack(alignment: .leading, spacing: 2) { Text(food.name).fontWeight(.semibold); Text("\(food.detail) · \(food.calories) kcal").font(.caption).foregroundStyle(HJColor.slate) }; Spacer(); Image(systemName: "plus").fontWeight(.bold).frame(width: 32, height: 32).background(HJColor.teal).foregroundStyle(.white).clipShape(Circle()) }.contentShape(Rectangle()).frame(minHeight: 62) }
}

struct HJPrimaryButton: View { let title: String; let action: () -> Void; var body: some View { Button(title, action: action).fontWeight(.bold).frame(maxWidth: .infinity, minHeight: 52).background(HJColor.teal).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: HJRadius.medium, style: .continuous)) } }

struct HJDailyQuestCard: View {
    let progress: Double
    var liters: Double = 1.2
    var isComplete = false
    var action: (() -> Void)?
    var removeAction: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrinking = false
    @State private var isSubtracting = false
    @State private var sipRaised = false
    @State private var celebrating = false
    var body: some View {
        HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) { Image(systemName: isComplete ? "checkmark.seal.fill" : "safari.fill").foregroundStyle(isComplete ? HJColor.teal : HJColor.coral); Text(isComplete ? "Quest complete" : "Daily quest").font(.headline) }
                    Text("Drink 2 liters of water").font(.subheadline)
                    HStack(spacing: 8) { ProgressView(value: progress).tint(HJColor.teal).animation(.spring(response: 0.42, dampingFraction: 0.8), value: progress); Text("\(liters.formatted(.number.precision(.fractionLength(1)))) / 2 L").font(.caption.bold()).foregroundStyle(HJColor.slate).fixedSize().contentTransition(.numericText()) }
                    Text(statusText).font(.caption2.weight(.semibold)).foregroundStyle(HJColor.teal)
                }
                hydrationOtter
        }
        .padding(13)
        .background(isComplete ? HJColor.teal.opacity(0.12) : HJColor.mist)
        .clipShape(RoundedRectangle(cornerRadius: HJRadius.large, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: HJRadius.large, style: .continuous))
        .gesture(
            TapGesture(count: 2).onEnded { subtractWater() }
                .exclusively(before: TapGesture(count: 1).onEnded { drink() })
        )
        .sensoryFeedback(.impact(weight: .light, intensity: 0.55), trigger: liters) { _, newValue in newValue < 2 }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Daily quest, drink 2 liters of water, \(liters.formatted()) of 2 liters\(isComplete ? ", complete" : isDrinking ? ", otter is drinking" : isSubtracting ? ", removing water" : "")")
        .accessibilityHint(isDrinking || isSubtracting ? "Updating" : "Activate to add 200 milliliters. Use the Remove water action to subtract.")
        .accessibilityAction(named: "Add 200 milliliters") { drink() }
        .accessibilityAction(named: "Remove 200 milliliters") { subtractWater() }
        .accessibilityIdentifier("today.waterQuest")
    }

    private var statusText: String {
        if isDrinking { return "Sip in progress…" }
        if isSubtracting { return "Removing 200 ml…" }
        if isComplete { return "Complete · Double-tap to subtract" }
        return "Tap +200 ml · Double-tap −200 ml"
    }

    private var hydrationOtter: some View {
        ZStack {
            HJBundleImage(name: "HydrationOtter-v1")
                .scaledToFit()
                .rotationEffect(.degrees(reduceMotion ? 0 : isSubtracting ? 4 : sipRaised ? -5 : celebrating ? 3 : 0), anchor: .bottom)
                .offset(y: reduceMotion ? 0 : isSubtracting ? 3 : sipRaised ? -4 : celebrating ? -6 : 0)
                .scaleEffect(reduceMotion ? 1 : celebrating ? 1.06 : 1, anchor: .bottom)
            if !reduceMotion && isDrinking {
                Image(systemName: "drop.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.cyan)
                    .shadow(color: .white, radius: 1)
                    .offset(x: sipRaised ? -9 : -16, y: sipRaised ? -22 : 5)
                    .opacity(sipRaised ? 1 : 0)
            }
            if !reduceMotion && celebrating {
                Image(systemName: "sparkles")
                    .font(.headline.bold())
                    .foregroundStyle(HJColor.yellow)
                    .offset(x: 28, y: -27)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 88, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func drink() {
        guard let action, !isDrinking, !isSubtracting, !isComplete else { return }
        if reduceMotion { action(); return }
        let completesQuest = liters >= 1.8
        isDrinking = true
        withAnimation(.easeInOut(duration: 0.32)) { sipRaised = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(460))
            action()
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.38, dampingFraction: 0.66)) {
                sipRaised = false
                celebrating = completesQuest
            }
            try? await Task.sleep(for: .milliseconds(completesQuest ? 520 : 300))
            withAnimation(.easeOut(duration: 0.2)) { celebrating = false }
            isDrinking = false
        }
    }

    private func subtractWater() {
        guard let removeAction, !isDrinking, !isSubtracting, liters > 0 else { return }
        if reduceMotion { removeAction(); return }
        withAnimation(.easeInOut(duration: 0.2)) { isSubtracting = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(240))
            removeAction()
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) { isSubtracting = false }
        }
    }
}

struct HJQuestButtonStyle: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? 0.985 : 1).opacity(configuration.isPressed ? 0.9 : 1).animation(.easeOut(duration: 0.12), value: configuration.isPressed) } }
