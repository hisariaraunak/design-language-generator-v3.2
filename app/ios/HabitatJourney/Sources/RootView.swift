import SwiftUI

enum AppTab: Hashable { case today, log, progress, habitat }

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: AppTab
    @State private var path = NavigationPath()
    @State private var logPath: [Food]

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let requested = arguments.firstIndex(of: "--screen").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let foodPreview = arguments.firstIndex(of: "--food-preview").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let mealPreview = arguments.firstIndex(of: "--meal-preview").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let previewFood = SeedData.foods.first { $0.name.caseInsensitiveCompare(foodPreview ?? "") == .orderedSame }
        let previewMeal = MealKind.allCases.first { $0.rawValue.caseInsensitiveCompare(mealPreview ?? "") == .orderedSame || $0.displayName.caseInsensitiveCompare(mealPreview ?? "") == .orderedSame }
        var initialTodayPath = NavigationPath()
        if let previewMeal { initialTodayPath.append(previewMeal) }
        _selection = State(initialValue: ["log": .log, "progress": .progress, "habitat": .habitat][requested ?? ""] ?? .today)
        _path = State(initialValue: initialTodayPath)
        _logPath = State(initialValue: previewFood.map { [$0] } ?? [])
    }

    var body: some View {
        @Bindable var store = store
        TabView(selection: $selection) {
            NavigationStack(path: $path) {
                TodayView(selection: $selection)
                    .navigationDestination(for: Food.self) { FoodDetailView(food: $0, selection: $selection) }
                    .navigationDestination(for: MealKind.self) { MealDetailView(meal: $0, selection: $selection) }
                    .navigationDestination(for: FoodEntry.self) { FoodEntryEditView(entry: $0) }
            }
            .tag(AppTab.today)
            .tabItem { Label("Today", systemImage: "house.fill") }
            NavigationStack(path: $logPath) { FoodLogView(selection: $selection) }.tag(AppTab.log).tabItem { Label("Log", systemImage: "plus.circle.fill") }
            NavigationStack { ProgressScreen() }.tag(AppTab.progress).tabItem { Label("Progress", systemImage: "chart.bar.fill") }
            NavigationStack { HabitatScreen(selection: $selection) }.tag(AppTab.habitat).tabItem { Label("Habitat", systemImage: "leaf.fill") }
        }
        .tint(HJColor.teal)
        .overlay(alignment: .bottom) { if store.showXPReceipt { XPReceipt(title: store.xpReceiptTitle, amount: store.xpReceiptAmount).padding(.bottom, 74).transition(.move(edge: .bottom).combined(with: .opacity)) } }
        .onChange(of: store.showXPReceipt) { _, isShowing in if isShowing { Task { try? await Task.sleep(for: .seconds(2.4)); store.dismissXPReceipt() } } }
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
                    .padding(.leading, 22)
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
        .onChange(of: selection) { _, tab in if tab == .today, !store.showXPReceipt { playHeroReaction(.opening) } }
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
    @Binding var selection: AppTab
    @State private var deletedEntry: DeletedFoodEntry?
    @State private var undoDismissTask: Task<Void, Never>?

    private var entries: [FoodEntry] { store.entries(for: meal) }

    var body: some View {
        List {
            Section {
                HJMealSummaryCard(meal: meal, calories: store.calories(for: meal), macros: store.macros(for: meal), foodCount: entries.count)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                if entries.isEmpty {
                    VStack(spacing: 10) {
                        HJBundleImage(name: meal.iconAsset).scaledToFit().frame(width: 72, height: 72)
                        Text("No foods in \(meal.displayName.lowercased()) yet").font(.headline).foregroundStyle(HJColor.navy)
                        Text("Add something when you’re ready. Ollie will keep this spot open for you.")
                            .font(.subheadline)
                            .foregroundStyle(HJColor.slate)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("meal.empty")
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(entries) { entry in
                        NavigationLink(value: entry) { HJMealEntryRow(entry: entry) }
                            .accessibilityIdentifier("meal.entry.\(entry.food.name)")
                            .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                            .listRowBackground(HJColor.card)
                            .listRowSeparatorTint(HJColor.line)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { delete(entry) } label: { Label("Delete", systemImage: "trash") }
                                    .accessibilityIdentifier("meal.delete.\(entry.food.name)")
                            }
                    }
                }
            } header: {
                if !entries.isEmpty {
                    HStack {
                        Text("Logged foods")
                        Spacer()
                        Text("Swipe to delete").font(.caption2).textCase(nil)
                    }
                    .foregroundStyle(HJColor.slate)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(HJColor.canvas)
        .navigationTitle(meal.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button {
                    store.selectedMeal = meal
                    selection = .log
                } label: {
                    Label("Log another food", systemImage: "plus")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.plain)
                .background(HJColor.teal)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityIdentifier("meal.logAnother")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(.ultraThinMaterial)
        }
        .overlay(alignment: .bottom) {
            if let deletedEntry {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill").foregroundStyle(HJColor.coral)
                    Text("\(deletedEntry.entry.food.name) removed").font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Undo") { undoDelete() }.font(.subheadline.bold()).foregroundStyle(HJColor.teal)
                        .accessibilityIdentifier("meal.undoDelete")
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(HJColor.navy)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: HJColor.navy.opacity(0.18), radius: 12, y: 5)
                .padding(.horizontal, 16)
                .padding(.bottom, 82)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("meal.deleteConfirmation")
            }
        }
        .animation(.snappy(duration: 0.3), value: deletedEntry)
        .onDisappear {
            undoDismissTask?.cancel()
            deletedEntry = nil
        }
    }

    private func delete(_ entry: FoodEntry) {
        undoDismissTask?.cancel()
        guard let deleted = store.deleteEntry(id: entry.id) else { return }
        deletedEntry = deleted
        undoDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            deletedEntry = nil
        }
    }

    private func undoDelete() {
        undoDismissTask?.cancel()
        guard let deletedEntry else { return }
        store.restore(deletedEntry)
        self.deletedEntry = nil
    }
}

struct FoodEntryEditView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: FoodEntry
    @State private var servings: Double
    @State private var meal: MealKind
    @State private var didSave = false

    private var calories: Int { Int(Double(entry.food.calories) * servings) }
    private var macros: MacroNutrients { entry.food.macros.scaled(by: servings) }
    private var hasChanges: Bool { servings != entry.servings || meal != entry.meal }

    init(entry: FoodEntry) {
        self.entry = entry
        _servings = State(initialValue: entry.servings)
        _meal = State(initialValue: entry.meal)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 15) {
                    Text(entry.food.emoji).font(.system(size: 52)).frame(width: 82, height: 82).background(HJColor.mist).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.food.name).font(.title2.bold()).foregroundStyle(HJColor.navy)
                        Text(entry.food.detail).font(.subheadline).foregroundStyle(HJColor.slate)
                        Text("Logged in \(entry.meal.displayName.lowercased())").font(.caption.weight(.semibold)).foregroundStyle(HJColor.green)
                    }
                    Spacer()
                }

                VStack(spacing: 14) {
                    HJServingStepper(servings: $servings)
                    Divider()
                    HStack { Text("Updated calories").foregroundStyle(HJColor.slate); Spacer(); Text("\(calories) kcal").fontWeight(.bold).foregroundStyle(HJColor.navy).contentTransition(.numericText()) }
                }
                .hjCard()

                HJMealSummaryCard(meal: meal, calories: calories, macros: macros, foodCount: 1, title: "Updated nutrition")

                VStack(alignment: .leading, spacing: 11) {
                    Text("Move to meal").font(.headline).foregroundStyle(HJColor.navy)
                    HJMealSelector(selection: $meal, compact: true)
                    if meal != entry.meal {
                        Label("This food will move to \(meal.displayName.lowercased()).", systemImage: "arrow.right.circle.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(HJColor.tealPressed)
                            .accessibilityIdentifier("entry.moveNotice")
                    }
                }
                .hjCard()
            }
            .padding(16)
            .padding(.bottom, 90)
        }
        .background(HJColor.canvas)
        .navigationTitle("Edit food")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button { save() } label: {
                    Label(didSave ? "Saved" : "Save changes", systemImage: didSave ? "checkmark" : "square.and.arrow.down")
                        .fontWeight(.bold).frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.plain)
                .background(hasChanges || didSave ? HJColor.teal : HJColor.line)
                .foregroundStyle(hasChanges || didSave ? .white : HJColor.slate)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .disabled(!hasChanges || didSave)
                .accessibilityIdentifier("entry.saveChanges")
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6).background(.ultraThinMaterial)
        }
        .sensoryFeedback(.success, trigger: didSave)
    }

    private func save() {
        guard store.updateEntry(id: entry.id, servings: servings, meal: meal) else { return }
        withAnimation(.snappy) { didSave = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
            dismiss()
        }
    }
}

struct FoodLogView: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: AppTab
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    private var launchState: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--log-state"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
    private var isLoading: Bool { launchState == "loading" }
    private var filtered: [Food] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else { return SeedData.foods }
        return SeedData.foods.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.detail.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(spacing: 14) {
                HJMealSelector(selection: $store.selectedMeal)

                if store.isOffline {
                    Label("Offline — you can still log foods saved on this device", systemImage: "wifi.slash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HJColor.slate)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(HJColor.yellow.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .accessibilityIdentifier("log.offline")
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(HJColor.slate)
                    TextField("Search foods", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .accessibilityIdentifier("log.search")
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(HJColor.slate.opacity(0.72)).frame(width: 30, height: 30)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(HJColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(searchFocused ? HJColor.teal : HJColor.line, lineWidth: searchFocused ? 1.5 : 1))
                .shadow(color: HJColor.navy.opacity(0.04), radius: 7, y: 3)

                HStack {
                    Text(query.isEmpty ? "Recent foods" : "Search results").font(.title3.bold()).foregroundStyle(HJColor.navy)
                    Spacer()
                    if !isLoading { Text("\(filtered.count)").font(.caption.bold()).foregroundStyle(HJColor.slate).padding(.horizontal, 9).padding(.vertical, 4).background(HJColor.mist).clipShape(Capsule()) }
                }

                if isLoading {
                    HJFoodListSkeleton()
                } else if filtered.isEmpty {
                    VStack(spacing: 9) {
                        Text("🦦").font(.system(size: 40))
                        Text("No foods found").font(.headline).foregroundStyle(HJColor.navy)
                        Text("Try another name or clear the search.").font(.subheadline).foregroundStyle(HJColor.slate).multilineTextAlignment(.center)
                        Button("Clear search") { query = ""; searchFocused = true }
                            .font(.subheadline.bold())
                            .foregroundStyle(HJColor.tealPressed)
                            .frame(minHeight: 44)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .hjCard()
                    .accessibilityIdentifier("log.empty")
                } else {
                    VStack(spacing: 0) {
                        ForEach(filtered) { food in
                            NavigationLink(value: food) { HJFoodRow(food: food) }.buttonStyle(.plain)
                            if food.id != filtered.last?.id { Divider() }
                        }
                    }
                    .hjCard()
                }

                VStack(spacing: 5) {
                    HStack {
                        Text("\(store.selectedMeal.displayName) total").fontWeight(.semibold)
                        Spacer()
                        Text("\(store.calories(for: store.selectedMeal)) kcal").fontWeight(.bold).contentTransition(.numericText())
                    }
                    Text("Choose a food to review its portion before adding it.")
                        .font(.caption)
                        .foregroundStyle(HJColor.slate)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .hjCard()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("log.mealTotal")
            }
            .padding(16)
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HJColor.canvas)
        .navigationTitle("Log meal")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Food.self) { FoodDetailView(food: $0, selection: $selection) }
    }
}

struct FoodDetailView: View {
    @Environment(AppStore.self) private var store
    let food: Food
    @Binding var selection: AppTab
    @State private var servings = 1.0
    @State private var successFeedback = 0
    private var calories: Int { Int(Double(food.calories) * servings) }
    private var canLog: Bool { servings >= 0.5 && servings <= 20 && !store.isSelectedDateFuture }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    Text(food.emoji)
                        .font(.system(size: 58))
                        .frame(width: 88, height: 88)
                        .background(HJColor.mist)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(HJColor.teal.opacity(0.14)))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).font(.title2.bold()).foregroundStyle(HJColor.navy)
                        Text(food.detail).font(.subheadline).foregroundStyle(HJColor.slate)
                        Label("Illustrated food", systemImage: "leaf.fill").font(.caption2.weight(.semibold)).foregroundStyle(HJColor.green)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                VStack(spacing: 14) {
                    HJServingStepper(servings: $servings)
                    Divider()
                    HStack {
                        Text("Portion unit").font(.subheadline.weight(.semibold)).foregroundStyle(HJColor.slate)
                        Spacer()
                        Text(food.detail).font(.subheadline.weight(.semibold)).foregroundStyle(HJColor.navy)
                    }
                }
                .hjCard()

                HStack(spacing: 16) {
                    VStack(spacing: 0) {
                        Text(calories.formatted()).font(.system(size: 42, weight: .bold, design: .rounded)).foregroundStyle(HJColor.navy).contentTransition(.numericText())
                        Text("kcal").font(.subheadline.weight(.semibold)).foregroundStyle(HJColor.slate)
                    }
                    .frame(width: 100)
                    Divider()
                    VStack(spacing: 9) {
                        NutrientLine("Carbs", value: food.macros.carbs * servings, color: HJColor.yellow)
                        NutrientLine("Protein", value: food.macros.protein * servings, color: HJColor.green)
                        NutrientLine("Fat", value: food.macros.fat * servings, color: HJColor.coral)
                        NutrientLine("Fiber", value: food.macros.fiber * servings, color: HJColor.teal)
                    }
                }
                .frame(minHeight: 130)
                .hjCard()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("food.nutritionSummary")

                VStack(alignment: .leading, spacing: 11) {
                    Text("Meal").font(.headline).foregroundStyle(HJColor.navy)
                    HJMealSelector(selection: $store.selectedMeal, compact: true)
                }
                .hjCard()

                if store.isSelectedDateFuture {
                    Label("Meals cannot be logged for a future date.", systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("food.validation")
                }
            }
            .padding(16)
            .padding(.bottom, 92)
        }
        .background(HJColor.canvas)
        .navigationTitle("Food details")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button {
                    guard store.log(food: food, servings: servings, meal: store.selectedMeal) else { return }
                    successFeedback += 1
                    selection = .today
                } label: {
                    Text("Add \(calories) kcal to \(store.selectedMeal.rawValue.lowercased())")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.plain)
                .background(canLog ? HJColor.teal : HJColor.line)
                .foregroundStyle(canLog ? Color.white : HJColor.slate)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .disabled(!canLog)
                .accessibilityIdentifier("food.addButton")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(.ultraThinMaterial)
        }
        .sensoryFeedback(.success, trigger: successFeedback)
    }
}

struct NutrientLine: View {
    let label: String; let value: Double; let color: Color
    init(_ label: String, value: Double, color: Color) { self.label = label; self.value = value; self.color = color }
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
            Spacer(minLength: 8)
            Text("\(Int(value)) g").fontWeight(.semibold).contentTransition(.numericText())
        }
        .font(.subheadline)
        .foregroundStyle(HJColor.navy)
    }
}
