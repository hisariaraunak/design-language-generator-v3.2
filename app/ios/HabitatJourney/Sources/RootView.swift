import SwiftUI

enum AppTab: Hashable { case today, log, progress, habitat }

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: AppTab
    @State private var path = NavigationPath()

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let requested = arguments.firstIndex(of: "--screen").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        _selection = State(initialValue: ["log": .log, "progress": .progress, "habitat": .habitat][requested ?? ""] ?? .today)
    }

    var body: some View {
        @Bindable var store = store
        TabView(selection: $selection) {
            NavigationStack(path: $path) { TodayView(selection: $selection).navigationDestination(for: Food.self) { FoodDetailView(food: $0, selection: $selection) }.navigationDestination(for: MealKind.self) { MealDetailView(meal: $0) } }.tag(AppTab.today).tabItem { Label("Today", systemImage: "house.fill") }
            NavigationStack { FoodLogView(selection: $selection) }.tag(AppTab.log).tabItem { Label("Log", systemImage: "plus.circle.fill") }
            NavigationStack { ProgressScreen() }.tag(AppTab.progress).tabItem { Label("Progress", systemImage: "chart.bar.fill") }
            NavigationStack { HabitatScreen(selection: $selection) }.tag(AppTab.habitat).tabItem { Label("Habitat", systemImage: "leaf.fill") }
        }
        .tint(HJColor.teal)
        .overlay(alignment: .bottom) { if store.showXPReceipt { XPReceipt(title: store.xpReceiptTitle, amount: store.xpReceiptAmount).padding(.bottom, 74).transition(.move(edge: .bottom).combined(with: .opacity)) } }
        .onChange(of: store.showXPReceipt) { _, isShowing in if isShowing { Task { try? await Task.sleep(for: .seconds(1.6)); store.dismissXPReceipt() } } }
        .sheet(isPresented: $store.showUnlock) { UnlockScreen { store.showUnlock = false; selection = .progress } }
        .alert("Something went wrong", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) { Button("OK") {} } message: { Text(store.lastError ?? "") }
    }
}

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: AppTab
    @State private var showCalendar = false
    @State private var heroReaction: HJHeroReaction = .opening
    @State private var heroReactionTrigger = 0
    @State private var heroSuccessFeedback = 0
    @State private var heroSupportFeedback = 0
    private var title: String {
        if Calendar.current.isDateInToday(store.selectedDate) { return "Today" }
        if Calendar.current.isDateInYesterday(store.selectedDate) { return "Yesterday" }
        return store.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
    var body: some View {
        @Bindable var store = store
        ScrollView { VStack(spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) { Text(title).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(HJColor.navy).lineLimit(1).minimumScaleFactor(0.75); if !store.isSelectedDateToday { Text(store.selectedDate.formatted(date: .long, time: .omitted)).font(.caption).foregroundStyle(HJColor.slate) } }
                Spacer()
                Button { store.moveSelectedDate(by: -1) } label: { Image(systemName: "chevron.left").frame(width: 38, height: 38).background(.white).clipShape(Circle()) }.accessibilityLabel("Previous day")
                Button { showCalendar = true } label: { Image(systemName: "calendar").frame(width: 44, height: 44).background(.white).clipShape(Circle()).overlay(Circle().stroke(HJColor.line)).shadow(color: HJColor.navy.opacity(0.08), radius: 8, y: 3) }.accessibilityLabel("Choose date")
                Button { store.moveSelectedDate(by: 1) } label: { Image(systemName: "chevron.right").frame(width: 38, height: 38).background(.white).clipShape(Circle()) }.accessibilityLabel("Next day")
            }
            if store.isOffline { Label("Offline — changes stay safely on this device", systemImage: "wifi.slash").font(.caption.weight(.semibold)).foregroundStyle(HJColor.slate).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 7).background(HJColor.yellow.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius: 10)) }
            ZStack(alignment: .leading) {
                HJAnimatedHero(reaction: heroReaction, trigger: heroReactionTrigger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                LinearGradient(colors: [.white.opacity(0.52), .white.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing)
                HJCalorieRing(remaining: store.calorieBalance, goal: store.state.goals.calories, consumed: store.consumedCalories)
                    .frame(width: 138, height: 138)
                    .padding(.leading, 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 176)
            .clipShape(RoundedRectangle(cornerRadius: HJRadius.large, style: .continuous))
            let macros = store.consumedMacros
            LazyVGrid(columns: [.init(.flexible(), spacing: 8), .init(.flexible())], spacing: 8) { HJMacroCard(title: "Protein", iconAsset: "MacroProtein", consumed: macros.protein, goal: store.state.goals.protein, color: HJColor.green); HJMacroCard(title: "Carbs", iconAsset: "MacroCarbs", consumed: macros.carbs, goal: store.state.goals.carbs, color: HJColor.yellow); HJMacroCard(title: "Fat", iconAsset: "MacroFat", consumed: macros.fat, goal: store.state.goals.fat, color: HJColor.coral); HJMacroCard(title: "Fiber", iconAsset: "MacroFiber", consumed: macros.fiber, goal: store.state.goals.fiber, color: HJColor.green) }
            if store.todayEntries.isEmpty {
                TodayEmptyState(isFuture: store.isSelectedDateFuture) { selection = .log }
            } else {
                VStack(spacing: 0) { HStack { Text("Meals").font(.title3.bold()); Spacer() }; ForEach(MealKind.allCases) { meal in Divider(); NavigationLink(value: meal) { HJMealRow(meal: meal, calories: store.calories(for: meal)) }.buttonStyle(HJMealButtonStyle()) } }.hjCard()
            }
            if store.isSelectedDateToday { HJDailyQuestCard(progress: store.questProgress, liters: store.waterLiters, isComplete: store.isQuestComplete, action: { store.addWater() }, removeAction: { store.removeWater() }) }
        }.padding(.horizontal, 16).padding(.bottom, 26) }
        .refreshable { await store.refreshToday() }
        .overlay { if store.isRefreshing { ProgressView().padding(16).background(.ultraThinMaterial).clipShape(Circle()) } }
        .background(HJColor.canvas).navigationBarHidden(true)
        .animation(.snappy(duration: 0.35), value: store.selectedDate)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: store.isQuestComplete)
        .sensoryFeedback(.selection, trigger: store.selectedDate)
        .sensoryFeedback(.success, trigger: store.isQuestComplete)
        .sensoryFeedback(.success, trigger: heroSuccessFeedback)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.45), trigger: heroSupportFeedback)
        .onAppear { playHeroReaction(.opening) }
        .onChange(of: selection) { _, tab in if tab == .today { playHeroReaction(.opening) } }
        .onChange(of: store.showXPReceipt) { _, isShowing in
            guard isShowing, store.xpReceiptAmount == 10 else { return }
            if store.calorieBalance == 0 { playHeroReaction(.goalReached) }
            else if store.calorieBalance < 0 { playHeroReaction(.supportive) }
            else { playHeroReaction(.logged) }
        }
        .sheet(isPresented: $showCalendar) { NavigationStack { DatePicker("Choose a day", selection: $store.selectedDate, in: ...Calendar.current.date(byAdding: .year, value: 1, to: Date())!, displayedComponents: .date).datePickerStyle(.graphical).padding().navigationTitle("Choose date").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showCalendar = false } } } }.presentationDetents([.medium]) }
    }

    private func playHeroReaction(_ reaction: HJHeroReaction) {
        heroReaction = HJHeroReaction.launchPreview ?? reaction
        heroReactionTrigger += 1
        if HJHeroReaction.launchPreview == nil {
            switch reaction {
            case .logged, .goalReached: heroSuccessFeedback += 1
            case .supportive: heroSupportFeedback += 1
            case .opening: break
            }
        }
    }
}

struct TodayEmptyState: View {
    let isFuture: Bool
    let logAction: () -> Void
    var body: some View { VStack(spacing: 8) { Text(isFuture ? "🌤️" : "🥣").font(.system(size: 42)); Text(isFuture ? "Nothing planned yet" : "Your plate is ready").font(.headline); Text(isFuture ? "Come back that day or start planning a meal." : "Log your first meal to bring today’s nutrition journey to life.").font(.subheadline).foregroundStyle(HJColor.slate).multilineTextAlignment(.center); if !isFuture { Button("Log first meal", action: logAction).fontWeight(.bold).foregroundStyle(HJColor.teal).frame(minHeight: 44) } }.frame(maxWidth: .infinity).padding(.vertical, 18).hjCard().accessibilityElement(children: .combine) }
}

struct HJMealButtonStyle: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.padding(.horizontal, configuration.isPressed ? 5 : 0).background(configuration.isPressed ? HJColor.mist : .clear).clipShape(RoundedRectangle(cornerRadius: 10)).animation(.easeOut(duration: 0.12), value: configuration.isPressed) } }

struct MealDetailView: View {
    @Environment(AppStore.self) private var store
    let meal: MealKind
    var body: some View { List { if store.entries(for: meal).isEmpty { ContentUnavailableView("No foods logged", systemImage: "fork.knife", description: Text("Foods added to \(meal.rawValue.lowercased()) will appear here.")) } else { ForEach(store.entries(for: meal)) { entry in HStack(spacing: 12) { Text(entry.food.emoji).font(.title); VStack(alignment: .leading) { Text(entry.food.name).fontWeight(.semibold); Text("\(entry.servings.formatted()) × \(entry.food.detail)").font(.caption).foregroundStyle(HJColor.slate) }; Spacer(); Text("\(Int(Double(entry.food.calories) * entry.servings)) kcal").font(.subheadline.bold()) } }.onDelete { store.deleteEntries(at: $0, meal: meal) } } } .navigationTitle(meal == .snack ? "Snacks" : meal.rawValue).navigationBarTitleDisplayMode(.inline).toolbar { EditButton() } }
}

struct FoodLogView: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: AppTab
    @State private var query = ""
    var filtered: [Food] { query.isEmpty ? SeedData.foods : SeedData.foods.filter { $0.name.localizedCaseInsensitiveContains(query) } }
    var body: some View { @Bindable var store = store; ScrollView { VStack(spacing: 14) {
        Picker("Meal", selection: $store.selectedMeal) { ForEach(MealKind.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
        HStack { Image(systemName: "magnifyingglass"); TextField("Search foods", text: $query).textInputAutocapitalization(.never); Button(action: {}) { Image(systemName: "barcode.viewfinder").font(.title2) } }.padding(12).background(.white).clipShape(RoundedRectangle(cornerRadius: HJRadius.medium)).overlay(RoundedRectangle(cornerRadius: HJRadius.medium).stroke(HJColor.line))
        HStack { Text("Recent foods").font(.title3.bold()); Spacer() }
        VStack(spacing: 0) { ForEach(filtered) { food in NavigationLink(value: food) { HJFoodRow(food: food) }.buttonStyle(.plain); if food.id != filtered.last?.id { Divider() } } }.hjCard()
        HStack { Text("\(store.selectedMeal.rawValue) total"); Spacer(); Text("\(store.calories(for: store.selectedMeal)) kcal").fontWeight(.bold) }.padding()
    }.padding(16) }.background(HJColor.canvas).navigationTitle("Log meal").navigationBarTitleDisplayMode(.inline).navigationDestination(for: Food.self) { FoodDetailView(food: $0, selection: $selection) } }
}

struct FoodDetailView: View {
    @Environment(AppStore.self) private var store
    let food: Food; @Binding var selection: AppTab
    @State private var servings = 1.0
    var body: some View { @Bindable var store = store; ScrollView { VStack(spacing: 14) {
        HStack(spacing: 18) { Text(food.emoji).font(.system(size: 74)); VStack(alignment: .leading) { Text(food.name).font(.title2.bold()); Text(food.detail).foregroundStyle(HJColor.slate) }; Spacer() }.padding(.vertical)
        VStack(spacing: 15) { Text("Serving size").font(.subheadline); HStack { Button { servings = max(0.5, servings - 0.5) } label: { Image(systemName: "minus") }; Spacer(); Text(servings.formatted()).font(.title.bold()); Spacer(); Button { servings += 0.5 } label: { Image(systemName: "plus") } }.buttonStyle(.bordered).tint(HJColor.navy); Text(food.detail).foregroundStyle(HJColor.slate); Divider(); HStack { VStack { Text("\(Int(Double(food.calories) * servings))").font(.system(size: 42, weight: .bold, design: .rounded)); Text("kcal") }; Divider(); VStack(alignment: .leading, spacing: 8) { NutrientLine("Carbs", value: food.macros.carbs * servings, color: HJColor.yellow); NutrientLine("Protein", value: food.macros.protein * servings, color: HJColor.green); NutrientLine("Fat", value: food.macros.fat * servings, color: HJColor.coral); NutrientLine("Fiber", value: food.macros.fiber * servings, color: HJColor.teal) } } }.hjCard()
        VStack(alignment: .leading, spacing: 12) { Text("Meal").font(.headline); Picker("Meal", selection: $store.selectedMeal) { ForEach(MealKind.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented) }.hjCard()
        HJPrimaryButton(title: "Add to \(store.selectedMeal.rawValue.lowercased())") { store.log(food: food, servings: servings, meal: store.selectedMeal); selection = .habitat }
    }.padding(16) }.background(HJColor.canvas).navigationTitle("Food details").navigationBarTitleDisplayMode(.inline) }
}

struct NutrientLine: View { let label: String; let value: Double; let color: Color; init(_ label: String, value: Double, color: Color) { self.label = label; self.value = value; self.color = color }; var body: some View { HStack { Circle().fill(color).frame(width: 8, height: 8); Text(label); Spacer(); Text("\(Int(value)) g").fontWeight(.semibold) }.font(.subheadline).frame(width: 170) } }
