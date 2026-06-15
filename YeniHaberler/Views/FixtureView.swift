import SwiftUI
import Combine
import os

// MARK: - Fixture View

struct FixtureView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = FixtureViewModel()

    var body: some View {
        ZStack {
            Theme.Colors.groupedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if !viewModel.availableLeagues.isEmpty {
                    leagueSelector
                }

                if viewModel.availableWeeks.count > 1 {
                    weekSelector
                }

                Group {
                    if viewModel.isLoading && viewModel.fixtures.isEmpty {
                        SkeletonList(count: 6)
                            .padding(.top, Theme.Spacing.lg)
                    } else if let error = viewModel.errorMessage, viewModel.fixtures.isEmpty {
                        ErrorView(message: error) {
                            Task { await viewModel.load() }
                        }
                    } else if viewModel.fixtures.isEmpty {
                        EmptyStateView(
                            icon: "calendar",
                            title: "Maç Yok",
                            message: "Bu lig için fikstür bulunamadı."
                        )
                    } else {
                        list
                    }
                }
            }
        }
        .navigationTitle("Fikstür")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel.fixtures.isEmpty {
                await viewModel.loadLeaguesAndFixtures()
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private var leagueSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(viewModel.availableLeagues) { league in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        Task { await viewModel.selectLeague(league.slug) }
                    } label: {
                        Text(league.league.name)
                            .scaledFont(size: 12, weight: viewModel.selectedLeague == league.slug ? .bold : .medium)
                            .foregroundColor(viewModel.selectedLeague == league.slug ? .white : Theme.Colors.textPrimary)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(viewModel.selectedLeague == league.slug ? Theme.Brand.primary : Theme.Colors.surface)
                            )
                            .overlay(
                                Capsule().stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
        }
    }

    private var weekSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.availableWeeks, id: \.self) { week in
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            viewModel.selectWeek(week)
                        } label: {
                            Text("\(week). Hafta")
                                .scaledFont(size: 12, weight: viewModel.selectedWeek == week ? .bold : .medium)
                                .foregroundColor(viewModel.selectedWeek == week ? .white : Theme.Colors.textPrimary)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(viewModel.selectedWeek == week ? Theme.Colors.textPrimary : Theme.Colors.surface)
                                )
                                .overlay(
                                    Capsule().stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .id(week)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.md)
            }
            .onChange(of: viewModel.selectedWeek) { newValue in
                guard let week = newValue else { return }
                withAnimation { proxy.scrollTo(week, anchor: .center) }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(viewModel.displayedFixtures) { match in
                    FixtureRow(match: match)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Fixture Row

struct FixtureRow: View {
    let match: MatchFixture

    private var isFinished: Bool {
        match.homeScore != nil && match.awayScore != nil
    }

    private var statusColor: Color {
        isFinished ? Theme.Colors.success : Theme.Colors.textSecondary
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Tarih
            VStack(spacing: 2) {
                Text(dayShort(from: match.date))
                    .scaledFont(size: 18, weight: .heavy, design: .serif)
                    .foregroundColor(Theme.Brand.primary)
                Text(monthShort(from: match.date))
                    .scaledFont(size: 9, weight: .heavy)
                    .tracking(0.8)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .frame(width: 44)

            // Takımlar + skor
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let logo = match.homeLogo {
                        ThemedAsyncImage(url: logo)
                            .frame(width: 18, height: 18)
                    }
                    Text(match.homeTeam)
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(scoreText(match.homeScore))
                        .scaledFont(size: 14, weight: .bold)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                HStack(spacing: 6) {
                    if let logo = match.awayLogo {
                        ThemedAsyncImage(url: logo)
                            .frame(width: 18, height: 18)
                    }
                    Text(match.awayTeam)
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(scoreText(match.awayScore))
                        .scaledFont(size: 14, weight: .bold)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }

            // Saat + durum
            VStack(spacing: 2) {
                Text(match.time)
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundColor(Theme.Colors.textSecondary)
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 50)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    private func scoreText(_ score: Int?) -> String {
        guard let score = score else { return "-" }
        return "\(score)"
    }

    private func dayShort(from date: String) -> String {
        // "yyyy-MM-dd" → "dd"
        let parts = date.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        if parts.count >= 3 {
            return String(format: "%02d", parts[2])
        }
        return ""
    }

    private func monthShort(from date: String) -> String {
        let months = ["OCK", "ŞUB", "MAR", "NİS", "MAY", "HAZ",
                      "TEM", "AĞU", "EYL", "EKİ", "KAS", "ARA"]
        let parts = date.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        if parts.count >= 2 {
            let monthIndex = parts[1] - 1
            if monthIndex >= 0 && monthIndex < 12 {
                return months[monthIndex]
            }
        }
        return ""
    }
}

// MARK: - ViewModel

@MainActor
final class FixtureViewModel: ObservableObject {
    @Published var fixtures: [MatchFixture] = []
    @Published var availableLeagues: [LeagueItem] = []
    @Published var selectedLeague: String = "super-lig"
    @Published var availableWeeks: [Int] = []
    @Published var selectedWeek: Int?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    /// Seçili haftaya göre filtrelenmiş maçlar. Hafta seçili değilse tümü.
    var displayedFixtures: [MatchFixture] {
        guard let week = selectedWeek else { return fixtures }
        return fixtures.filter { Int($0.week) == week }
    }

    func selectWeek(_ week: Int) {
        selectedWeek = week
    }

    func loadLeaguesAndFixtures() async {
        await loadLeagues()
        await load()
    }

    func loadLeagues() async {
        do {
            let response = try await api.fetchFixtureLeagues()
            availableLeagues = response.data.map { (slug, standingsData) in
                LeagueItem(league: standingsData.league, slug: slug)
            }
            // Süper Lig en başa
            if let superLigIndex = availableLeagues.firstIndex(where: { $0.slug == "super-lig" }) {
                let superLig = availableLeagues.remove(at: superLigIndex)
                availableLeagues.insert(superLig, at: 0)
            }
            if !availableLeagues.contains(where: { $0.slug == selectedLeague }),
               let first = availableLeagues.first {
                selectedLeague = first.slug
            }
        } catch {
            AppLogger.api.error("Fixture leagues — \(error.localizedDescription, privacy: .public)")
        }
    }

    func selectLeague(_ slug: String) async {
        selectedLeague = slug
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.fetchFixture(league: selectedLeague)
            let all = MatchFixture.flatten(response.data)
            fixtures = all
            availableWeeks = Set(all.compactMap { Int($0.week) }).sorted()
            selectedWeek = defaultWeek(in: all)
        } catch {
            errorMessage = "Fikstür yüklenemedi."
            AppLogger.api.error("Fixture load failed — \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }

    /// Varsayılan hafta: bugüne tarihçe en yakın maçın haftası (güncel/son oynanan hafta).
    private func defaultWeek(in matches: [MatchFixture]) -> Int? {
        let weeks = Set(matches.compactMap { Int($0.week) }).sorted()
        guard !weeks.isEmpty else { return nil }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let today = Date()

        var best: (week: Int, distance: TimeInterval)?
        for match in matches {
            guard let week = Int(match.week), let date = fmt.date(from: match.date) else { continue }
            let distance = abs(date.timeIntervalSince(today))
            if best == nil || distance < best!.distance {
                best = (week, distance)
            }
        }
        return best?.week ?? weeks.last
    }
}
