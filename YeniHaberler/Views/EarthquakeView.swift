import SwiftUI
import Combine
import os

// MARK: - Earthquake List View

struct EarthquakeView: View {
    @Binding var showSideMenu: Bool
    @StateObject private var viewModel = EarthquakeViewModel()

    var body: some View {
        ZStack {
            Theme.Colors.groupedBackground.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.earthquakes.isEmpty {
                    SkeletonList(count: 6)
                        .padding(.top, Theme.Spacing.lg)
                } else if let error = viewModel.errorMessage, viewModel.earthquakes.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.earthquakes.isEmpty {
                    EmptyStateView(
                        icon: "waveform.path",
                        title: "Veri Yok",
                        message: "Şu anda son depremler servisi yanıt vermiyor."
                    )
                } else {
                    list
                }
            }
        }
        .navigationTitle("Son Depremler")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel.earthquakes.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // En son deprem büyük kart
                if let first = viewModel.earthquakes.first {
                    LatestEarthquakeHeroCard(quake: first)
                }

                // Diğer depremler
                if viewModel.earthquakes.count > 1 {
                    SectionHeader(title: "Önceki Depremler", icon: "clock.fill")
                        .padding(.top, Theme.Spacing.md)

                    ForEach(viewModel.earthquakes.dropFirst()) { quake in
                        EarthquakeRow(quake: quake)
                    }
                }

                // Bilgilendirme
                infoBanner
                    .padding(.top, Theme.Spacing.lg)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, 100)
        }
    }

    private var infoBanner: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.info)
            Text("Veriler AFAD/Kandilli tabanlı kaynaklardan canlı çekilir. Son güncelleme sayfayı yenileyerek alınabilir.")
                .scaledFont(size: 11)
                .foregroundColor(Theme.Colors.textSecondary)
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.Colors.info.opacity(0.08))
        )
    }
}

// MARK: - Latest Earthquake Hero Card

struct LatestEarthquakeHeroCard: View {
    let quake: EarthquakeData

    private var magnitudeColor: Color {
        guard let mag = quake.magnitude else { return Theme.Colors.textSecondary }
        if mag >= 5.0 { return Theme.Colors.danger }
        if mag >= 4.0 { return Theme.Colors.warning }
        return Theme.Colors.success
    }

    private var severityLabel: String {
        guard let mag = quake.magnitude else { return "—" }
        if mag >= 6.0 { return "ŞİDDETLİ" }
        if mag >= 5.0 { return "ORTA-ŞİDDETLİ" }
        if mag >= 4.0 { return "ORTA" }
        if mag >= 3.0 { return "HAFİF" }
        return "ZAYIF"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Eyebrow
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(magnitudeColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1)
                    .animation(.easeInOut(duration: 1.2).repeatForever(), value: UUID())
                Text("EN SON DEPREM")
                    .scaledFont(size: 11, weight: .heavy)
                    .tracking(1.2)
                    .foregroundColor(magnitudeColor)
                Spacer()
                Text(severityLabel)
                    .scaledFont(size: 10, weight: .bold)
                    .tracking(0.8)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(magnitudeColor))
            }

            // Magnitude büyük gösterge
            HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
                if let mag = quake.magnitude {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(format: "%.1f", mag))
                            .scaledFont(size: 56, weight: .heavy, design: .serif)
                            .foregroundColor(magnitudeColor)
                        Text("MAGNITUDE")
                            .scaledFont(size: 9, weight: .heavy)
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let depth = quake.depth {
                        labelValue(label: "DERİNLİK", value: String(format: "%.1f km", depth))
                    }
                    if !quake.displayDate.isEmpty {
                        labelValue(label: "TARİH", value: "\(quake.displayDate) \(quake.displayTime)")
                    }
                }
            }

            EditorialDivider()

            // Konum
            if let location = quake.displayLocation {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Brand.primary)
                    Text(location)
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                    Spacer()
                }
            }

            // Koordinatlar
            if let lat = quake.latitude, let lon = quake.longitude {
                HStack(spacing: Theme.Spacing.md) {
                    labelValue(label: "ENLEM", value: String(format: "%.4f°", lat))
                    labelValue(label: "BOYLAM", value: String(format: "%.4f°", lon))
                    Spacer()
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(magnitudeColor.opacity(0.3), lineWidth: 1)
        )
        .themedShadow(Theme.Shadow.small)
    }

    @ViewBuilder
    private func labelValue(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .scaledFont(size: 9, weight: .heavy)
                .tracking(0.8)
                .foregroundColor(Theme.Colors.textTertiary)
            Text(value)
                .scaledFont(size: 13, weight: .semibold)
                .foregroundColor(Theme.Colors.textPrimary)
        }
    }
}

// MARK: - Earthquake Row (mini card)

struct EarthquakeRow: View {
    let quake: EarthquakeData

    private var magnitudeColor: Color {
        guard let mag = quake.magnitude else { return Theme.Colors.textSecondary }
        if mag >= 5.0 { return Theme.Colors.danger }
        if mag >= 4.0 { return Theme.Colors.warning }
        return Theme.Colors.success
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Magnitude
            VStack(spacing: 2) {
                Text(String(format: "%.1f", quake.magnitude ?? 0))
                    .scaledFont(size: 22, weight: .heavy, design: .serif)
                    .foregroundColor(magnitudeColor)
                Text("ML")
                    .scaledFont(size: 8, weight: .heavy)
                    .tracking(0.8)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(magnitudeColor.opacity(0.10))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(quake.displayLocation ?? "Bilinmeyen konum")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: Theme.Spacing.sm) {
                    if !quake.displayDate.isEmpty {
                        Label("\(quake.displayDate) \(quake.displayTime)", systemImage: "clock")
                            .scaledFont(size: 11)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    if let depth = quake.depth {
                        Text("·").foregroundColor(Theme.Colors.textTertiary)
                        Label(String(format: "%.0f km", depth), systemImage: "arrow.down.to.line")
                            .scaledFont(size: 11)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }

            Spacer()
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
}

// MARK: - ViewModel

@MainActor
final class EarthquakeViewModel: ObservableObject {
    @Published var earthquakes: [EarthquakeData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.fetchLastEarthquakes()
            earthquakes = response.data
        } catch {
            errorMessage = "Deprem verileri yüklenemedi."
            AppLogger.api.error("Earthquake load failed — \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}
