import SwiftUI

enum HJColor { static let actionPrimary = Color(red: 0.047, green: 0.624, blue: 0.604); static let textPrimary = Color(red: 0.071, green: 0.188, blue: 0.278) }
enum HJSize { static let buttonHeight: CGFloat = 52; static let touchTarget: CGFloat = 44 }

struct HJButton: View {
    let label: LocalizedStringKey
    let action: () -> Void
    var body: some View { Button(label, action: action).fontWeight(.bold).frame(minHeight: HJSize.buttonHeight).frame(maxWidth: .infinity).background(HJColor.actionPrimary).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12)) }
}

struct HJCalorieRing: View {
    let remaining: Int; let goal: Int
    var body: some View { VStack { Text(remaining.formatted()).font(.largeTitle.bold()); Text("kcal left") }.accessibilityElement(children: .combine).accessibilityLabel("\(remaining) calories left out of \(goal)") }
}
