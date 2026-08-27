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

struct ProgressScreen: View {
    @Environment(AppStore.self) private var store
    let weeklyCalories = [1620, 1740, 1680, 1560, 1820, 1710, 1650]
    var body: some View { ScrollView { VStack(spacing: 14) {
        HStack { Text("Progress").font(.system(size: 32, weight: .bold, design: .serif)); Spacer(); Image(systemName: "calendar").foregroundStyle(HJColor.teal).frame(width: 44, height: 44).background(.white).clipShape(Circle()) }
        HStack(spacing: 14) { ZStack { Circle().stroke(HJColor.teal.opacity(0.2), lineWidth: 9); Circle().trim(from: 0, to: 0.88).stroke(HJColor.teal, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90)); Image(systemName: "flame.fill").foregroundStyle(HJColor.coral) }.frame(width: 62, height: 62); VStack(alignment: .leading) { Text("\(store.state.streak) day streak").font(.title3.bold()); Text("Great consistency!").foregroundStyle(HJColor.slate); HStack { ForEach(0..<7) { _ in Image(systemName: "checkmark.circle.fill").foregroundStyle(HJColor.teal) } } } }.hjCard()
        VStack(alignment: .leading, spacing: 12) { HStack { VStack(alignment: .leading) { Text("Calories (kcal)").font(.headline); Text("Weekly average").font(.caption).foregroundStyle(HJColor.slate) }; Spacer(); Text("1,683").font(.title2.bold()).foregroundStyle(HJColor.teal) }; HStack(alignment: .bottom, spacing: 12) { ForEach(Array(weeklyCalories.enumerated()), id: \.offset) { index, value in VStack { Text("\(value)").font(.system(size: 8)); RoundedRectangle(cornerRadius: 5).fill(LinearGradient(colors: [HJColor.teal, HJColor.teal.opacity(0.75)], startPoint: .top, endPoint: .bottom)).frame(height: CGFloat(value) / 12); Text(["M","T","W","T","F","S","S"][index]).font(.caption2) }.frame(maxWidth: .infinity) } }.frame(height: 190) }.hjCard()
        VStack(alignment: .leading, spacing: 14) { Text("Macro averages").font(.headline); HStack { MacroAverage(value: "45%", label: "Carbs", color: HJColor.teal); Divider(); MacroAverage(value: "30%", label: "Protein", color: HJColor.yellow); Divider(); MacroAverage(value: "25%", label: "Fat", color: HJColor.coral) } }.hjCard()
        HStack(spacing: 10) { VStack(alignment: .leading) { Text("Weight trend").font(.headline); Spacer(); Text("70.4 kg").font(.title2.bold()).foregroundStyle(HJColor.teal); Text("−0.6 kg this month").font(.caption).foregroundStyle(HJColor.slate) }.frame(maxWidth: .infinity, minHeight: 110).hjCard(); VStack { Image(systemName: "star.circle.fill").font(.largeTitle).foregroundStyle(HJColor.teal); Text("+\(store.state.habitat.xp) XP").font(.title2.bold()).foregroundStyle(HJColor.teal); Text("This week").font(.caption) }.frame(maxWidth: .infinity, minHeight: 110).hjCard() }
    }.padding(16) }.background(HJColor.canvas).navigationBarHidden(true) }
}

struct MacroAverage: View { let value: String; let label: String; let color: Color; var body: some View { VStack { Text(value).font(.title2.bold()).foregroundStyle(color); Text(label).font(.caption); Text(label == "Protein" ? "126 g" : label == "Carbs" ? "189 g" : "47 g").font(.caption.bold()) }.frame(maxWidth: .infinity) } }

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
