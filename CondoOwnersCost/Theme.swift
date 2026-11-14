//
//  Theme.swift
//  CondoOwnersCost
//

import SwiftUI
import UIKit

enum Theme {
    static let paper = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.086, blue: 0.078, alpha: 1)
            : UIColor(red: 0.957, green: 0.941, blue: 0.910, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.15, blue: 0.135, alpha: 1)
            : UIColor.white
    })
    static let ink = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.93, blue: 0.89, alpha: 1)
            : UIColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1)
    })
    static let muted = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.68, blue: 0.60, alpha: 1)
            : UIColor(red: 0.42, green: 0.38, blue: 0.32, alpha: 1)
    })
    static let line = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.27, blue: 0.22, alpha: 1)
            : UIColor(red: 0.86, green: 0.82, blue: 0.74, alpha: 1)
    })
    static let teal = Color(red: 0.07, green: 0.40, blue: 0.38)
    static let copper = Color(red: 0.64, green: 0.34, blue: 0.20)
    static let good = Color(red: 0.15, green: 0.46, blue: 0.32)
}

nonisolated enum Money {
    static func format(_ value: Double, cents: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CAD"
        formatter.locale = Locale(identifier: "en_CA")
        formatter.minimumFractionDigits = cents ? 2 : 0
        formatter.maximumFractionDigits = cents ? 2 : 0
        let rounded = cents ? value : value.rounded()
        return formatter.string(from: NSNumber(value: rounded)) ?? "$0"
    }

    static func precise(_ value: Double) -> String { format(value, cents: true) }
    static func whole(_ value: Double) -> String { format(value, cents: false) }
}

struct SectionCard<Content: View>: View {
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }
}

struct Footnote: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct MoneyField: View {
    var title: String
    @Binding var value: Double
    var digits: Int = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 12)
            TextField(title, value: $value, format: .number.precision(.fractionLength(digits)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 160)
        }
    }
}

struct PercentField: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var digits: Int = 2
    var step: Double = 0.05

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.ink)
                Spacer()
                TextField(title, value: $value, format: .number.precision(.fractionLength(digits)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 76)
                Text("%")
                    .foregroundStyle(Theme.muted)
            }
            Slider(value: $value, in: range, step: step)
                .tint(Theme.teal)
        }
    }
}

func percentText(_ value: Double, digits: Int = 2) -> String {
    String(format: "%.\(digits)f%%", value)
}
