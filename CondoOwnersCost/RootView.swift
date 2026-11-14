//
//  RootView.swift
//  CondoOwnersCost
//

import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var selection: UUID?
    @State private var importing = false
    @State private var exporting = false
    @State private var exportFile: JSONFile?
    @State private var alertText: String?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if ConsultationLayout.fits(proxy.size) {
                    if let selection, store.property(selection) != nil {
                        NavigationStack {
                            ConsultationView(propertyID: selection) {
                                self.selection = nil
                            }
                        }
                    } else if let selection, store.house(selection) != nil {
                        NavigationStack {
                            HouseConsultationView(houseID: selection) {
                                self.selection = nil
                            }
                        }
                    } else {
                        library
                    }
                } else {
                    phoneSplit
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Theme.paper)
        .task {
            prepareScreenshotIfNeeded()
            await store.refreshMarket()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                lang.applySystemLocale()
                Task { await store.refreshMarket() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            lang.applySystemLocale()
        }
        .onChange(of: locale) { _, _ in
            lang.applySystemLocale()
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importFile(url)
            case .failure(let error):
                alertText = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportFile,
            contentType: .json,
            defaultFilename: "CondoOwnersCost"
        ) { result in
            if case .failure(let error) = result { alertText = error.localizedDescription }
        }
        .alert(lang.t("nav.alert"), isPresented: alertPresented) {
            Button(lang.t("nav.ok")) { alertText = nil; store.importMessage = nil; store.loadError = nil }
        } message: {
            Text(alertText ?? store.importMessage ?? store.loadError ?? "")
        }
        .onChange(of: store.importMessage) { _, message in
            if message != nil { alertText = message }
        }
        .onChange(of: store.loadError) { _, message in
            if message != nil { alertText = message }
        }
    }

    private var phoneSplit: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(store.entries) { entry in
                    sidebarRow(entry)
                        .tag(entry.id)
                        .contextMenu { rowMenu(entry) }
                }
                .onDelete { offsets in
                    deleteEntries(store.entries, at: offsets)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle(lang.t("nav.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) { newMenu }
                ToolbarItem(placement: .topBarLeading) { folderMenu }
            }
            .overlay {
                if store.entries.isEmpty { emptyLibrary }
            }
        } detail: {
            if let selection, store.property(selection) != nil {
                WorkspaceView(propertyID: selection)
                    .id(selection)
            } else if let selection, store.house(selection) != nil {
                HouseWorkspaceView(houseID: selection)
                    .id(selection)
            } else {
                emptyDetail
            }
        }
    }

    private var library: some View {
        NavigationStack {
            List {
                ForEach(store.entries) { entry in
                    Button {
                        selection = entry.id
                    } label: {
                        sidebarRow(entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { rowMenu(entry) }
                }
                .onDelete { offsets in
                    deleteEntries(store.entries, at: offsets)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle(lang.t("nav.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) { newMenu }
                ToolbarItem(placement: .topBarLeading) { folderMenu }
            }
            .overlay {
                if store.entries.isEmpty { emptyLibrary }
            }
        }
    }

    private var newMenu: some View {
        Menu {
            Button(lang.t("nav.new.condo")) { selection = store.addNew() }
            Button(lang.t("nav.new.detached")) { selection = store.addHouse(.detached) }
            Button(lang.t("nav.new.townhouse")) { selection = store.addHouse(.townhouse) }
        } label: {
            Label(lang.t("nav.new"), systemImage: "plus")
        }
    }

    private var folderMenu: some View {
        Menu {
            Button(lang.t("nav.import")) { importing = true }
            Button(lang.t("nav.exportAll")) { exportLibrary() }
        } label: {
            Image(systemName: "folder")
        }
    }

    @ViewBuilder
    private func rowMenu(_ entry: LibraryEntry) -> some View {
        Button(lang.t("nav.duplicate")) {
            if entry.isHouse {
                selection = store.duplicateHouse(entry.id)
            } else {
                selection = store.duplicate(entry.id)
            }
        }
        Button(lang.t("nav.delete"), role: .destructive) {
            if entry.isHouse {
                store.deleteHouse(entry.id)
            } else {
                store.delete(entry.id)
            }
            if selection == entry.id { selection = nil }
        }
    }

    private func deleteEntries(_ listed: [LibraryEntry], at offsets: IndexSet) {
        for index in offsets {
            let entry = listed[index]
            if entry.isHouse {
                store.deleteHouse(entry.id)
            } else {
                store.delete(entry.id)
            }
        }
        if let selection, !store.contains(selection) {
            self.selection = nil
        }
    }

    private var alertPresented: Binding<Bool> {
        Binding(
            get: { alertText != nil },
            set: { if !$0 { alertText = nil } }
        )
    }

    private var emptyLibrary: some View {
        VStack(spacing: 12) {
            Text(lang.t("empty.title"))
                .font(.title3.weight(.semibold))
            Text(lang.t("empty.body"))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button(lang.t("nav.new.condo")) { selection = store.addNew() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.teal)
            Button(lang.t("nav.new.detached")) { selection = store.addHouse(.detached) }
            Button(lang.t("nav.new.townhouse")) { selection = store.addHouse(.townhouse) }
            Button(lang.t("empty.example")) { selection = store.addExample() }
        }
        .padding(24)
    }

    private var emptyDetail: some View {
        ContentUnavailableView(
            lang.t("detail.empty.title"),
            systemImage: "building.2",
            description: Text(lang.t("detail.empty.body"))
        )
        .background(Theme.paper)
    }

    private func sidebarRow(_ entry: LibraryEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.name)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(entry.place)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            if !entry.figure.isEmpty {
                Text(entry.figure)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.teal)
            }
        }
        .padding(.vertical, 4)
    }

    private func prepareScreenshotIfNeeded() {
        guard let mode = ScreenshotLaunch.mode else { return }
        if store.properties.isEmpty {
            _ = store.addExample()
        }
        if !store.houses.contains(where: { $0.kind == .detached }) {
            let id = store.addHouse(.detached)
            store.mutateHouse(id) { house in
                house.estimatesAreSuggested = true
                house.purchasePrice = 2_450_000
                house.assessedValue = 2_180_000
                house.finishedSqft = 2_640
                house.lotSqft = 4_800
                house.grossIncomeAnnual = 240_000
                house.apply(place: PlaceCandidate(
                    id: UUID(),
                    title: "1288 West Georgia Street",
                    subtitle: "Vancouver",
                    latitude: 49.2884,
                    longitude: -123.1236,
                    city: "Vancouver",
                    provinceCode: "BC",
                    postalCode: "V6E 4R3",
                    address: "1288 W Georgia St, Vancouver, BC V6E 4R3"
                ))
            }
        }
        if !store.houses.contains(where: { $0.kind == .townhouse }) {
            let id = store.addHouse(.townhouse)
            store.mutateHouse(id) { house in
                house.estimatesAreSuggested = true
                house.finishedSqft = 1_680
                house.purchasePrice = 1_280_000
                house.assessedValue = 1_150_000
                house.apply(place: PlaceCandidate(
                    id: UUID(),
                    title: "18 Renaissance Walk",
                    subtitle: "Burnaby",
                    latitude: 49.2665,
                    longitude: -123.0012,
                    city: "Burnaby",
                    provinceCode: "BC",
                    postalCode: "V5A 1S6",
                    address: "18 Renaissance Walk, Burnaby, BC V5A 1S6"
                ))
            }
        }
        switch mode {
        case "library":
            selection = nil
        case "condo", "condo-results", "duo-condo":
            selection = store.properties.first?.id
        case "house", "house-cost", "duo-house":
            selection = store.houses.first { $0.kind == .detached }?.id
        default:
            break
        }
    }

    private func exportLibrary() {
        do {
            exportFile = JSONFile(data: try store.exportData(propertyIDs: nil))
            exporting = true
        } catch {
            alertText = error.localizedDescription
        }
    }

    private func importFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            try store.importData(Data(contentsOf: url))
        } catch {
            alertText = lang.t("import.fail")
        }
    }
}

struct LibraryEntry: Identifiable {
    var id: UUID
    var name: String
    var place: String
    var figure: String
    var updatedAt: Date
    var isHouse: Bool
}

extension PortfolioStore {
    func bind<Value>(_ id: UUID, _ keyPath: WritableKeyPath<CondoProperty, Value>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { self.property(id)?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                self.mutate(id) { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    func bindHouse<Value>(_ id: UUID, _ keyPath: WritableKeyPath<HouseEstimate, Value>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { self.house(id)?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                self.mutateHouse(id) { $0[keyPath: keyPath] = newValue }
            }
        )
    }
}
