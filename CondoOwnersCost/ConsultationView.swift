//
//  ConsultationView.swift
//  CondoOwnersCost
//

import SwiftUI

enum ConsultationLayout {
    /// Inner display of iPhone Duo, and iPad, are large enough for two people to share.
    /// A closed iPhone stays on the single-column layout.
    static func fits(_ size: CGSize) -> Bool {
        min(size.width, size.height) >= 520
    }

    static func book(_ size: CGSize) -> Bool {
        size.width >= size.height
    }
}

struct ConsultationView: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    let propertyID: UUID
    var onClose: () -> Void
    @State private var selectedYear = CalendarYear.current

    var body: some View {
        GeometryReader { proxy in
            let book = ConsultationLayout.book(proxy.size)
            Group {
                if book {
                    HStack(spacing: 0) {
                        agentPane
                        foldGap(vertical: false)
                        clientPane
                    }
                } else {
                    VStack(spacing: 0) {
                        clientPane
                        foldGap(vertical: true)
                        agentPane
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Theme.paper)
        .navigationTitle(store.property(propertyID)?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Label(lang.t("nav.title"), systemImage: "chevron.backward")
                }
            }
        }
    }

    private var agentPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(lang.t("duo.agent"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            WorkspaceView(propertyID: propertyID, role: .agent, sharedYear: $selectedYear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
    }

    private var clientPane: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lang.t("duo.client"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
            Text(lang.t("duo.client.note"))
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
            ResultsPane(propertyID: propertyID, selectedYear: $selectedYear)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.card)
    }

    private func foldGap(vertical: Bool) -> some View {
        Rectangle()
            .fill(Theme.line)
            .frame(width: vertical ? nil : 28, height: vertical ? 28 : nil)
    }
}
