import SwiftUI
import UIKit

enum HJColor {
    static let canvas = Color(hex: 0xFAFCFB)
    static let card = Color.white
    static let navy = Color(hex: 0x123047)
    static let slate = Color(hex: 0x496274)
    static let teal = Color(hex: 0x0C9F9A)
    static let tealPressed = Color(hex: 0x087C79)
    static let mist = Color(hex: 0xE8F5F4)
    static let coral = Color(hex: 0xFF6B52)
    static let yellow = Color(hex: 0xF4C84A)
    static let green = Color(hex: 0x5DAA68)
    static let line = Color(hex: 0xDCE9E7)
}

enum HJSpace { static let xs: CGFloat = 4; static let sm: CGFloat = 8; static let md: CGFloat = 12; static let lg: CGFloat = 16; static let xl: CGFloat = 20; static let xxl: CGFloat = 24 }
enum HJRadius { static let small: CGFloat = 8; static let medium: CGFloat = 12; static let large: CGFloat = 20 }

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: alpha)
    }
}

extension View {
    func hjCard() -> some View {
        padding(HJSpace.lg)
            .background(HJColor.card)
            .clipShape(RoundedRectangle(cornerRadius: HJRadius.large, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HJRadius.large, style: .continuous).stroke(HJColor.line, lineWidth: 1))
            .shadow(color: HJColor.navy.opacity(0.06), radius: 10, y: 4)
    }
}

struct HJBundleImage: View {
    let name: String
    var body: some View {
        if let path = Bundle.main.path(forResource: name, ofType: "png"), let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image).resizable()
        } else {
            Rectangle().fill(HJColor.mist)
        }
    }
}
