import SwiftUI

// MARK: - Daily Briefing ("Günün Özeti")
struct DailyBriefingView: View {
    @StateObject private var viewModel = DailyBriefingViewModel()

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.topNews.isEmpty {
                PostDetailSkeleton().padding(.top, Theme.Spacing.lg)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        masthead

                        EditorialDivider(withGlyph: true)
                            .padding(.horizontal, Theme.Spacing.xl)
                            .padding(.vertical, Theme.Spacing.lg)

                        if let weather = viewModel.weather {
                            weatherSection(weather)
                            sectionDivider
                        }

                        if let next = viewModel.nextPrayer {
                            prayerSection(next)
                            sectionDivider
                        }

                        if !viewModel.topNews.isEmpty {
                            newsSection
                            sectionDivider
                        }

                        if !viewModel.currencies.isEmpty {
                            currencySection
                            sectionDivider
                        }

                        if let article = viewModel.featuredArticle {
                            articleSection(article)
                            sectionDivider
                        }

                        if !viewModel.recentMatches.isEmpty {
                            sportsSection
                        }

                        EditorialFooter()
                            .padding(.top, Theme.Spacing.xxl)
                            .padding(.bottom, 100)
                    }
                }
                .refreshable { await viewModel.loadBriefing() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.topNews.isEmpty {
                await viewModel.loadBriefing()
            }
        }
    }

    private var sectionDivider: some View {
        EditorialDivider()
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Rectangle().fill(Theme.Brand.gold).frame(width: 24, height: 2)
                Text(Self.dateLine)
                    .scaledFont(size: 11, weight: .heavy)
                    .tracking(1.6)
                    .foregroundColor(Theme.Brand.primary)
            }

            Text("Sabah Özeti")
                .scaledFont(size: 34, weight: .heavy, design: .serif)
                .foregroundColor(Theme.Colors.textPrimary)

            Text(AppBranding.briefingTagline)
                .scaledFont(size: 14, design: .serif)
                .italic()
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.xl)
    }

    private static var dateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEEE, d MMMM yyyy"
        return "BUGÜN · " + f.string(from: Date()).uppercased()
    }

    // MARK: - Weather

    private func weatherSection(_ w: WeatherData) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.info.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: weatherSymbol(w.icon))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(Theme.Colors.info)
            }

            VStack(alignment: .leading, spacing: 4) {
                EditorialEyebrow(text: "Hava Durumu · \(w.city)")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(w.degree)°")
                        .scaledFont(size: 32, weight: .heavy, design: .serif)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(w.desc)
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Text("En düşük \(w.low)°  ·  En yüksek \(w.high)°")
                    .scaledFont(size: 12)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func weatherSymbol(_ icon: String) -> String {
        let i = icon.lowercased()
        if i.contains("rain") || i.contains("yağ") { return "cloud.rain.fill" }
        if i.contains("snow") || i.contains("kar") { return "cloud.snow.fill" }
        if i.contains("cloud") || i.contains("bulut") { return "cloud.fill" }
        if i.contains("clear") || i.contains("açık") || i.contains("güneş") { return "sun.max.fill" }
        return "cloud.sun.fill"
    }

    // MARK: - Prayer

    private func prayerSection(_ next: (name: String, remaining: String)) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.categoryPurple.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Theme.Colors.categoryPurple)
            }

            VStack(alignment: .leading, spacing: 4) {
                EditorialEyebrow(text: "Namaz Vakti")
                Text("Sıradaki: \(next.name)")
                    .scaledFont(size: 20, weight: .bold, design: .serif)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Kalan süre: \(next.remaining)")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: - News

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            EditorialSectionHeader(title: "Önemli Gelişmeler", eyebrow: "Çok okunanlar")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.topNews.enumerated()), id: \.element.id) { index, post in
                    NavigationLink(destination: PostDetailView(postId: post.id)) {
                        NumberedStoryRow(index: index + 1, post: post)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, Theme.Spacing.xl)

                    if index < viewModel.topNews.count - 1 {
                        EditorialDivider().padding(.horizontal, Theme.Spacing.xl)
                    }
                }
            }
        }
    }

    // MARK: - Currency

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            EditorialSectionHeader(title: "Döviz", eyebrow: "Hızlı bakış")

            HStack(spacing: Theme.Spacing.md) {
                ForEach(viewModel.currencies.prefix(3)) { c in
                    VStack(spacing: 6) {
                        Text(c.code.uppercased())
                            .scaledFont(size: 11, weight: .heavy)
                            .tracking(0.8)
                            .foregroundColor(Theme.Colors.textTertiary)
                        Text(c.sellingstr)
                            .scaledFont(size: 18, weight: .heavy, design: .serif)
                            .foregroundColor(Theme.Colors.textPrimary)
                        HStack(spacing: 3) {
                            Image(systemName: c.rate > 0 ? "arrow.up.right" : (c.rate < 0 ? "arrow.down.right" : "minus"))
                                .font(.system(size: 9, weight: .bold))
                            Text(String(format: "%%%.2f", abs(c.rate)))
                                .scaledFont(size: 10, weight: .semibold)
                        }
                        .foregroundColor(c.rate > 0 ? Theme.Colors.success : (c.rate < 0 ? Theme.Colors.danger : Theme.Colors.textTertiary))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(Theme.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }

    // MARK: - Article

    private func articleSection(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            EditorialSectionHeader(title: "Yazardan Bugün", eyebrow: "Köşe")

            NavigationLink(destination: ArticleDetailView(articleId: article.id, showSideMenu: .constant(false))) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    Group {
                        if let img = article.image?.cropped.medium, !img.isEmpty {
                            ThemedAsyncImage(url: img)
                        } else {
                            Rectangle()
                                .fill(Theme.Brand.gold.opacity(0.5))
                                .overlay(
                                    Image(systemName: "quote.opening")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

                    VStack(alignment: .leading, spacing: 6) {
                        if let author = article.author?.name {
                            Text(author.uppercased())
                                .scaledFont(size: 10, weight: .heavy)
                                .tracking(0.8)
                                .foregroundColor(Theme.Brand.primary)
                        }
                        Text(article.name)
                            .scaledFont(size: 16, weight: .bold, design: .serif)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Sports

    private var sportsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            EditorialSectionHeader(
                title: "Spor Özeti",
                eyebrow: viewModel.sportsWeek.map { "Süper Lig · \($0). Hafta" } ?? "Süper Lig"
            )

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(viewModel.recentMatches.prefix(4)) { match in
                    HStack(spacing: Theme.Spacing.md) {
                        Text(match.homeTeam)
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .lineLimit(1)

                        Text(scoreText(match))
                            .scaledFont(size: 13, weight: .heavy, design: .serif)
                            .foregroundColor(Theme.Brand.primary)
                            .frame(width: 54)

                        Text(match.awayTeam)
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(Theme.Colors.surface)
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }

    private func scoreText(_ m: MatchFixture) -> String {
        if let h = m.homeScore, let a = m.awayScore { return "\(h) - \(a)" }
        return m.time.isEmpty ? "vs" : m.time
    }
}
