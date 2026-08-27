import Charts
import SwiftUI

struct HabitatScreen: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: AppTab
    var body: some View {
        GeometryReader { geometry in ScrollView { VStack(spacing: 14) {
            HStack { VStack(alignment: .leading) { Text("My habitat").font(.system(size: 32, weight: .bold, design: .serif)); Text("Riverbank sanctuary").font(.caption).foregroundStyle(HJColor.slate) }; Spacer(); NavigationLink { AccountScreen() } label: { Image(systemName: "gearshape.fill").frame(width: 44, height: 44).background(.white).clipShape(Circle()) } }
            ZStack(alignment: .topLeading) {
                HJBundleImage(name: "RiverHabitat").scaledToFill().frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                HStack(spacing: 12) { Text("\(store.state.habitat.level)").font(.title.bold()).foregroundStyle(.white).frame(width: 50, height: 56).background(HJColor.tealPressed).clipShape(.rect(cornerRadius: 14)); VStack(alignment: .leading) { Text("Habitat level \(store.state.habitat.level)").font(.headline); Text("\(store.state.habitat.xp) / 1,000 XP").fontWeight(.bold).foregroundStyle(HJColor.tealPressed); ProgressView(value: Double(store.state.habitat.xp), total: 1000).tint(HJColor.teal).frame(width: 140) } }.padding(14).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16)).padding(12)
            }.frame(maxWidth: .infinity).frame(height: 285).clipShape(RoundedRectangle(cornerRadius: HJRadius.large))
            HJDailyQuestCard(progress: min(1, Double(store.todayEntries.count) / 4))
            HStack { Text("Unlocked friends").font(.title3.bold()); Spacer(); Button("View all") {}.foregroundStyle(HJColor.teal) }
            HStack { FriendBadge(image: "🦦", name: "Ollie"); FriendBadge(image: "🪶", name: "Reed"); FriendBadge(image: "🦀", name: "Crabby"); Button { store.unlockShelly() } label: { FriendBadge(image: store.state.habitat.didUnlockShelly ? "🐢" : "?", name: store.state.habitat.didUnlockShelly ? "Shelly" : "Next") }.buttonStyle(.plain).disabled(store.state.habitat.didUnlockShelly) }
            HStack(spacing: 12) { HJBundleImage(name: "RiverHabitat").scaledToFill().frame(width: 116, height: 100).clipShape(RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 5) { Text("Next upgrade preview").font(.caption.bold()).foregroundStyle(HJColor.tealPressed); Text("River Lookout").font(.headline); Text("Attracts new friends and boosts XP").font(.caption).foregroundStyle(HJColor.slate).fixedSize(horizontal: false, vertical: true); ProgressView(value: Double(store.state.habitat.xp), total: 1200).tint(HJColor.teal) }; Spacer(); Image(systemName: "lock.fill").foregroundStyle(HJColor.slate) }.hjCard()
        }.frame(width: max(0, geometry.size.width - 32)).padding(16).padding(.bottom, 10) } }.background(HJColor.canvas).navigationBarHidden(true)
    }
}

struct FriendBadge: View { let image: String; let name: String; var body: some View { VStack(spacing: 5) { Text(image).font(.system(size: 38)).frame(width: 65, height: 65).background(HJColor.mist).clipShape(Circle()).overlay(Circle().stroke(HJColor.line)); Text(name).font(.caption.bold()) }.frame(maxWidth: .infinity) } }

struct UnlockScreen: View {
    let continueAction: () -> Void
    var body: some View { ZStack { HJColor.canvas.ignoresSafeArea(); VStack(spacing: 12) { Image(systemName: "pawprint.fill").font(.largeTitle).foregroundStyle(HJColor.teal).padding().background(.white).clipShape(Circle()).shadow(radius: 8); Text("New friend unlocked").font(.system(size: 30, weight: .bold, design: .serif)); Text("Shelly").font(.system(size: 44, weight: .bold, design: .serif)).foregroundStyle(HJColor.tealPressed); HJBundleImage(name: "Shelly").scaledToFit().frame(maxHeight: 360).clipShape(RoundedRectangle(cornerRadius: 26)); Text("Shelly loves calm waters and keeping the habitat balanced.").font(.body).foregroundStyle(HJColor.slate).multilineTextAlignment(.center).padding(.horizontal, 28); HJPrimaryButton(title: "Continue") { continueAction() }.padding(.horizontal, 24) }.padding(.vertical, 24) } }
}

private enum ProgressRoute: Hashable {
    case calories, macros, weight, achievement(String)
}

private enum WeightPeriod: String, CaseIterable, Identifiable {
    case week = "7D", month = "1M", quarter = "3M"
    var id: String { rawValue }
    var days: Int { self == .week ? 7 : self == .month ? 30 : 90 }
}

private struct DailyNutritionPoint: Identifiable, Hashable {
    let date: Date
    let calories: Int
    let macros: MacroNutrients
    var id: Date { date }
}

private struct ProgressAchievement: Identifiable, Hashable {
    let id: String
    let animal: String
    let title: String
    let detail: String
    let color: Color
}

struct ProgressScreen: View {
    @Environment(AppStore.self) private var store
    @State private var weightPeriod: WeightPeriod = .week

    private var launchState: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--progress-state"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
    private var isLoading: Bool { launchState == "loading" }
    private var isEmpty: Bool { launchState == "empty" }
    private var isInsufficient: Bool { launchState == "insufficient" }
    private var nutritionPoints: [DailyNutritionPoint] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let points = (0..<7).reversed().compactMap { offset -> DailyNutritionPoint? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            let entries = store.entries(on: date)
            return DailyNutritionPoint(
                date: date,
                calories: entries.reduce(0) { $0 + Int(Double($1.food.calories) * $1.servings) },
                macros: entries.reduce(.zero) { $0 + $1.food.macros.scaled(by: $1.servings) }
            )
        }
        return isInsufficient ? Array(points.suffix(1)) : points
    }
    private var weightPoints: [WeightRecord] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -(weightPeriod.days - 1), to: Date()) ?? .distantPast
        let records = store.state.weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        return isInsufficient ? Array(records.suffix(1)) : records
    }
    private var weeklyAverage: Int {
        guard !nutritionPoints.isEmpty else { return 0 }
        return nutritionPoints.reduce(0) { $0 + $1.calories } / nutritionPoints.count
    }
    private var averageMacros: MacroNutrients {
        guard !nutritionPoints.isEmpty else { return .zero }
        let total = nutritionPoints.reduce(.zero) { $0 + $1.macros }
        let count = Double(nutritionPoints.count)
        return .init(protein: total.protein / count, carbs: total.carbs / count, fat: total.fat / count, fiber: total.fiber / count)
    }
    private var achievements: [ProgressAchievement] {
        [
            .init(id: "steady-otter", animal: "🦦", title: "Steady Otter", detail: "Logged seven days in a row", color: HJColor.teal),
            .init(id: "balanced-turtle", animal: "🐢", title: "Balanced Turtle", detail: "Kept a calm weekly rhythm", color: HJColor.green),
            .init(id: "curious-heron", animal: "🪶", title: "Curious Heron", detail: "Reviewed every nutrition trend", color: HJColor.yellow)
        ]
    }

    var body: some View {
        Group {
            if isLoading { HJProgressSkeleton() }
            else if isEmpty { HJProgressEmptyState() }
            else { progressContent }
        }
        .background(HJColor.canvas)
        .navigationBarHidden(true)
        .navigationDestination(for: ProgressRoute.self) { route in
            ProgressDetailScreen(route: route, nutrition: nutritionPoints, weights: weightPoints, goals: store.state.goals, achievements: achievements)
        }
    }

    private var progressContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Progress").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(HJColor.navy)
                        Text("Your last seven days").font(.caption).foregroundStyle(HJColor.slate)
                    }
                    Spacer()
                    Image(systemName: "calendar").font(.headline).foregroundStyle(HJColor.teal).frame(width: 44, height: 44).background(.white).clipShape(Circle()).overlay(Circle().stroke(HJColor.line))
                }

                HJStreakCalendar(streak: store.state.streak)

                NavigationLink(value: ProgressRoute.calories) {
                    HJWeeklyCaloriesCard(points: nutritionPoints, goal: store.state.goals.calories, average: weeklyAverage, insufficient: isInsufficient)
                }
                .buttonStyle(.plain)

                NavigationLink(value: ProgressRoute.macros) {
                    HJMacroAveragesCard(macros: averageMacros, insufficient: isInsufficient)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) { Text("Weight trend").font(.headline); Text("Your measurements").font(.caption).foregroundStyle(HJColor.slate) }
                        Spacer()
                        Picker("Weight period", selection: $weightPeriod) { ForEach(WeightPeriod.allCases) { Text($0.rawValue).tag($0) } }
                            .pickerStyle(.segmented).frame(width: 158)
                    }
                    if weightPoints.count < 2 {
                        HJInsufficientDataRow(message: "Add one more weight entry to reveal a trend.")
                    } else {
                        NavigationLink(value: ProgressRoute.weight) {
                            HJWeightChart(records: weightPoints).frame(height: 126)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open weight trend details")
                        .accessibilityIdentifier("progress.weightDetail")
                    }
                }
                .hjCard()
                .accessibilityIdentifier("progress.weight")

                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("Trail badges").font(.headline); Spacer(); Text("\(achievements.count) earned").font(.caption.bold()).foregroundStyle(HJColor.tealPressed) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(achievements) { achievement in
                                NavigationLink(value: ProgressRoute.achievement(achievement.id)) { HJAchievementCard(achievement: achievement) }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                .hjCard()
                .accessibilityIdentifier("progress.achievements")
            }
            .padding(16)
            .padding(.bottom, 12)
        }
    }
}

private struct HJStreakCalendar: View {
    let streak: Int
    private var dates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }
    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().stroke(HJColor.teal.opacity(0.16), lineWidth: 8)
                Circle().trim(from: 0, to: min(1, Double(streak) / 7)).stroke(HJColor.teal, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                Image(systemName: "flame.fill").foregroundStyle(HJColor.coral)
            }.frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text("\(streak) day streak").font(.title3.bold()); Spacer(); Text("On the trail").font(.caption.bold()).foregroundStyle(HJColor.green) }
                HStack {
                    ForEach(dates, id: \.self) { date in
                        VStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(HJColor.teal)
                            Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundStyle(HJColor.slate)
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .hjCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak) day streak, all seven recent days logged")
        .accessibilityIdentifier("progress.streak")
    }
}

private struct HJWeeklyCaloriesCard: View {
    let points: [DailyNutritionPoint]
    let goal: Int
    let average: Int
    let insufficient: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) { Text("Calories").font(.headline); Text("Daily totals and goal range").font(.caption).foregroundStyle(HJColor.slate) }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) { Text(average.formatted()).font(.title3.bold()).foregroundStyle(HJColor.tealPressed); Text("weekly avg").font(.caption2).foregroundStyle(HJColor.slate) }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(HJColor.slate)
            }
            if insufficient {
                HJInsufficientDataRow(message: "Keep logging to build your seven-day chart.")
            } else {
                Chart {
                    RectangleMark(yStart: .value("Lower goal", Double(goal) * 0.9), yEnd: .value("Upper goal", Double(goal) * 1.1))
                        .foregroundStyle(HJColor.green.opacity(0.10))
                    RuleMark(y: .value("Goal", goal)).foregroundStyle(HJColor.green.opacity(0.65)).lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                    ForEach(points) { point in
                        BarMark(x: .value("Day", point.date, unit: .day), y: .value("Calories", point.calories)).foregroundStyle(HJColor.teal.gradient).cornerRadius(5)
                    }
                }
                .chartYScale(domain: 0...max(2_400, goal + 300))
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)); AxisTick().foregroundStyle(.clear) } }
                .chartYAxis { AxisMarks(position: .leading, values: [0, 1000, 2000]) { value in AxisGridLine().foregroundStyle(HJColor.line); AxisValueLabel { if let number = value.as(Int.self) { Text(number.formatted()) } } } }
                .frame(height: 180)
            }
        }
        .hjCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("progress.calories")
    }
}

private struct HJMacroAveragesCard: View {
    let macros: MacroNutrients
    let insufficient: Bool
    private var sectors: [(String, Double, Color)] { [("Carbs", macros.carbs * 4, HJColor.teal), ("Protein", macros.protein * 4, HJColor.yellow), ("Fat", macros.fat * 9, HJColor.coral)] }
    private var totalEnergy: Double { max(1, sectors.reduce(0) { $0 + $1.1 }) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { VStack(alignment: .leading, spacing: 1) { Text("Macro averages").font(.headline); Text("Daily grams and energy share").font(.caption).foregroundStyle(HJColor.slate) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(HJColor.slate) }
            if insufficient {
                HJInsufficientDataRow(message: "A few more logged days will make averages meaningful.")
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: 2) {
                        HJMacroAverageValue(label: "Carbs", value: macros.carbs, percentage: sectors[0].1 / totalEnergy, color: HJColor.teal)
                        HJMacroAverageValue(label: "Protein", value: macros.protein, percentage: sectors[1].1 / totalEnergy, color: HJColor.yellow)
                        HJMacroAverageValue(label: "Fat", value: macros.fat, percentage: sectors[2].1 / totalEnergy, color: HJColor.coral)
                    }
                    Chart(sectors, id: \.0) { sector in SectorMark(angle: .value("Energy", sector.1), innerRadius: .ratio(0.62), angularInset: 1.5).foregroundStyle(sector.2) }
                        .frame(width: 92, height: 92)
                        .accessibilityHidden(true)
                }
            }
        }
        .hjCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("progress.macros")
    }
}

private struct HJMacroAverageValue: View {
    let label: String; let value: Double; let percentage: Double; let color: Color
    var body: some View { VStack(spacing: 2) { Text("\(Int(percentage * 100))%").font(.headline).foregroundStyle(color); Text(label).font(.caption2).foregroundStyle(HJColor.slate); Text("\(Int(value)) g").font(.caption.bold()).foregroundStyle(HJColor.navy) }.frame(maxWidth: .infinity) }
}

private struct HJWeightChart: View {
    let records: [WeightRecord]
    private var domain: ClosedRange<Double> {
        let values = records.map(\.kilograms)
        return ((values.min() ?? 65) - 0.4)...((values.max() ?? 75) + 0.4)
    }
    var body: some View {
        Chart(records.sorted { $0.date < $1.date }) { record in
            AreaMark(x: .value("Date", record.date), yStart: .value("Baseline", domain.lowerBound), yEnd: .value("Weight", record.kilograms)).foregroundStyle(LinearGradient(colors: [HJColor.teal.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Date", record.date), y: .value("Weight", record.kilograms)).foregroundStyle(HJColor.teal).lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
            PointMark(x: .value("Date", record.date), y: .value("Weight", record.kilograms)).foregroundStyle(HJColor.teal).symbolSize(28)
        }
        .chartYScale(domain: domain)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)); AxisGridLine().foregroundStyle(HJColor.line) } }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { AxisGridLine().foregroundStyle(HJColor.line); AxisValueLabel() } }
        .accessibilityLabel("Weight trend from \(records.first?.kilograms.formatted() ?? "") to \(records.last?.kilograms.formatted() ?? "") kilograms")
    }
}

private struct HJAchievementCard: View {
    let achievement: ProgressAchievement
    var body: some View {
        VStack(spacing: 6) {
            Text(achievement.animal).font(.system(size: 38)).frame(width: 64, height: 64).background(achievement.color.opacity(0.13)).clipShape(Circle()).overlay(Circle().stroke(achievement.color.opacity(0.35)))
            Text(achievement.title).font(.caption.bold()).foregroundStyle(HJColor.navy).lineLimit(1)
            Text("View badge").font(.caption2.weight(.semibold)).foregroundStyle(achievement.color)
        }
        .frame(width: 112, height: 116)
        .background(HJColor.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(achievement.title), \(achievement.detail)")
        .accessibilityHint("Opens achievement details")
        .accessibilityIdentifier("progress.badge.\(achievement.id)")
    }
}

private struct HJInsufficientDataRow: View {
    let message: String
    var body: some View { HStack(spacing: 10) { Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(HJColor.teal); Text(message).font(.subheadline).foregroundStyle(HJColor.slate); Spacer() }.padding(12).background(HJColor.mist.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).accessibilityIdentifier("progress.insufficient") }
}

private struct HJProgressSkeleton: View {
    var body: some View {
        ScrollView { VStack(spacing: 12) { HStack { Capsule().fill(HJColor.line).frame(width: 150, height: 34); Spacer(); Circle().fill(HJColor.line).frame(width: 44, height: 44) }; ForEach(0..<5, id: \.self) { index in RoundedRectangle(cornerRadius: 18).fill(HJColor.card).frame(height: index == 1 ? 250 : 135).overlay(alignment: .topLeading) { VStack(alignment: .leading, spacing: 10) { Capsule().fill(HJColor.line).frame(width: 130, height: 15); Capsule().fill(HJColor.line.opacity(0.7)).frame(width: 210, height: 11) }.padding(18) } } }.padding(16) }.redacted(reason: .placeholder).accessibilityLabel("Loading progress").accessibilityIdentifier("progress.loading")
    }
}

private struct HJProgressEmptyState: View {
    var body: some View {
        VStack(spacing: 18) {
            HStack { Text("Progress").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(HJColor.navy); Spacer() }
            Spacer()
            HJBundleImage(name: "TodayOtterLayer-v1").scaledToFit().frame(width: 170, height: 170).accessibilityLabel("Ollie waiting beside the trail")
            VStack(spacing: 8) { Text("Your trail starts here").font(.title2.bold()).foregroundStyle(HJColor.navy); Text("Log meals and weight to reveal weekly patterns. There’s no score to chase—just useful signals over time.").foregroundStyle(HJColor.slate).multilineTextAlignment(.center) }
            Label("Your first chart appears after two days", systemImage: "sparkles").font(.subheadline.bold()).foregroundStyle(HJColor.tealPressed).padding(12).background(HJColor.mist).clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
        .padding(20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("progress.empty")
    }
}

private struct ProgressDetailScreen: View {
    let route: ProgressRoute
    let nutrition: [DailyNutritionPoint]
    let weights: [WeightRecord]
    let goals: NutritionGoals
    let achievements: [ProgressAchievement]

    private var achievement: ProgressAchievement? {
        guard case let .achievement(id) = route else { return nil }
        return achievements.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                switch route {
                case .calories:
                    HJWeeklyCaloriesCard(points: nutrition, goal: goals.calories, average: nutrition.isEmpty ? 0 : nutrition.reduce(0) { $0 + $1.calories } / nutrition.count, insufficient: nutrition.count < 2)
                    VStack(spacing: 0) { ForEach(nutrition) { point in HStack { Text(point.date.formatted(.dateTime.weekday(.wide))); Spacer(); Text("\(point.calories) kcal").fontWeight(.bold) }.frame(minHeight: 44); if point.id != nutrition.last?.id { Divider() } } }.hjCard()
                case .macros:
                    let total = nutrition.reduce(.zero) { $0 + $1.macros }
                    let count = max(1, Double(nutrition.count))
                    HJMacroAveragesCard(macros: .init(protein: total.protein / count, carbs: total.carbs / count, fat: total.fat / count, fiber: total.fiber / count), insufficient: nutrition.count < 2)
                    VStack(alignment: .leading, spacing: 12) { Text("How to read this").font(.headline); Text("Percentages show each macro’s share of measured food energy. Gram averages help you compare days without labeling foods as good or bad.").foregroundStyle(HJColor.slate) }.hjCard()
                case .weight:
                    VStack(alignment: .leading, spacing: 12) { Text("Weight measurements").font(.headline); HJWeightChart(records: weights).frame(height: 260) }.hjCard()
                    VStack(spacing: 0) { ForEach(weights.sorted { $0.date > $1.date }) { record in HStack { Text(record.date.formatted(date: .abbreviated, time: .omitted)); Spacer(); Text("\(record.kilograms.formatted(.number.precision(.fractionLength(1)))) kg").fontWeight(.bold) }.frame(minHeight: 44); if record.id != weights.sorted(by: { $0.date > $1.date }).last?.id { Divider() } } }.hjCard()
                case .achievement:
                    if let achievement { VStack(spacing: 16) { Text(achievement.animal).font(.system(size: 100)).frame(width: 170, height: 170).background(achievement.color.opacity(0.13)).clipShape(Circle()); Text(achievement.title).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(HJColor.navy); Text(achievement.detail).font(.title3).foregroundStyle(HJColor.slate).multilineTextAlignment(.center); Label("Badge earned", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(achievement.color) }.frame(maxWidth: .infinity).padding(.vertical, 28).hjCard() }
                }
            }
            .padding(16)
        }
        .background(HJColor.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch route { case .calories: "Calories"; case .macros: "Macro averages"; case .weight: "Weight trend"; case .achievement: achievement?.title ?? "Achievement" }
    }
}

struct ProfileScreen: View {
    @Environment(AppStore.self) private var store
    var body: some View { Form { Section("Nutrition goals") { LabeledContent("Daily calories", value: "\(store.state.goals.calories) kcal"); LabeledContent("Protein", value: "\(Int(store.state.goals.protein)) g"); LabeledContent("Carbohydrates", value: "\(Int(store.state.goals.carbs)) g") }; Section("Preferences") { Toggle("Meal reminders", isOn: .constant(true)); Toggle("Habitat celebrations", isOn: .constant(true)) }; Section { Button("Reset demo data", role: .destructive) { store.resetDemo() } } }.navigationTitle("Profile") }
}

struct AccountScreen: View {
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isRegistering = false
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $isRegistering) { Text("Sign in").tag(false); Text("Create account").tag(true) }.pickerStyle(.segmented)
                if isRegistering { TextField("Display name", text: $displayName).textContentType(.name) }
                TextField("Email", text: $email).textContentType(.emailAddress).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                SecureField("Password", text: $password).textContentType(isRegistering ? .newPassword : .password)
            } header: { Text("Cloud sync") } footer: { Text("Your nutrition log remains available on this device even when sync is offline.") }
            Section {
                Button(isRegistering ? "Create account" : "Sign in") { authenticate() }.disabled(isWorking || email.isEmpty || password.isEmpty || (isRegistering && displayName.isEmpty))
                if isWorking { ProgressView().frame(maxWidth: .infinity) }
                if let message { Text(message).foregroundStyle(message == "Connected" ? HJColor.teal : HJColor.coral) }
            }
        }
        .navigationTitle("Account")
    }

    private func authenticate() {
        isWorking = true; message = nil
        Task {
            do {
                if isRegistering { try await BackendClient.shared.register(email: email, password: password, displayName: displayName) }
                else { try await BackendClient.shared.login(email: email, password: password) }
                message = "Connected"
            } catch { message = error.localizedDescription }
            isWorking = false
        }
    }
}

struct XPReceipt: View {
    let title: String
    let amount: Int
    var body: some View { HStack { Image(systemName: "checkmark.circle.fill").foregroundStyle(HJColor.teal); Text(title); Spacer(); Text("+\(amount) Habitat XP").fontWeight(.bold).foregroundStyle(HJColor.teal) }.font(.subheadline).padding().background(HJColor.navy).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 14)).shadow(radius: 12).padding(.horizontal, 20).accessibilityElement(children: .combine).accessibilityIdentifier("meal.confirmation") }
}
