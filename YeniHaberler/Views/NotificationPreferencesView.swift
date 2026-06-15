import SwiftUI

// MARK: - Notification Preferences

struct NotificationPreferencesView: View {
    @StateObject private var prefs = UserPreferences.shared
    @StateObject private var categoryStore = NotificationCategoryStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                masterSection
                categoriesSection
                quietHoursSection
                dailyLimitSection
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.groupedBackground.ignoresSafeArea())
        .navigationTitle("Bildirim Tercihleri")
        .navigationBarTitleDisplayMode(.inline)
        .task { await categoryStore.loadCategories() }
    }

    // MARK: - Master

    private var masterSection: some View {
        SettingsSection(title: "Genel", icon: "bell.fill", iconColor: Theme.Colors.warning) {
            SettingsToggleRow(
                title: "Bildirimleri Aç",
                subtitle: "Push bildirimleri al",
                icon: "bell.badge.fill",
                iconColor: Theme.Colors.warning,
                isOn: $prefs.notificationsEnabled
            )

            Divider().padding(.leading, 56)

            SettingsToggleRow(
                title: "Son Dakika Uyarıları",
                subtitle: "Önemli haberler için anlık bildirim",
                icon: "bolt.fill",
                iconColor: Theme.Colors.danger,
                isOn: $prefs.breakingNewsAlerts
            )
            .disabled(!prefs.notificationsEnabled)
            .opacity(prefs.notificationsEnabled ? 1 : 0.5)
        }
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        SettingsSection(title: "Kategoriler", icon: "square.grid.2x2.fill", iconColor: Theme.Brand.primary) {
            if categoryStore.categories.isEmpty {
                HStack(spacing: Theme.Spacing.md) {
                    if categoryStore.isLoading {
                        ProgressView()
                        Text("Kategoriler yükleniyor…")
                            .scaledFont(size: 14)
                            .foregroundColor(Theme.Colors.textSecondary)
                    } else {
                        Text("Kategori bulunamadı.")
                            .scaledFont(size: 14)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            } else {
                ForEach(Array(categoryStore.categories.enumerated()), id: \.element.id) { index, category in
                    CategoryToggleRow(
                        name: category.name,
                        color: Theme.categoryColor(for: String(category.id)),
                        isOn: Binding(
                            get: { categoryStore.isEnabled(category.id) },
                            set: { categoryStore.setEnabled(category.id, $0) }
                        )
                    )
                    .disabled(!prefs.notificationsEnabled)
                    .opacity(prefs.notificationsEnabled ? 1 : 0.5)

                    if index < categoryStore.categories.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
    }

    // MARK: - Quiet hours

    private var quietHoursSection: some View {
        SettingsSection(title: "Sessiz Saatler", icon: "moon.fill", iconColor: Theme.Colors.categoryPurple) {
            SettingsToggleRow(
                title: "Sessiz Saatler",
                subtitle: "Belirlenen aralıkta bildirim göstermez",
                icon: "moon.fill",
                iconColor: Theme.Colors.categoryPurple,
                isOn: $prefs.quietHoursEnabled
            )
            .disabled(!prefs.notificationsEnabled)
            .opacity(prefs.notificationsEnabled ? 1 : 0.5)

            if prefs.quietHoursEnabled {
                Divider().padding(.leading, 56)

                HStack {
                    Image(systemName: "sunset.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.warning)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.Colors.warning.opacity(0.14)))
                    Text("Başlangıç")
                        .scaledFont(size: 15)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $prefs.quietHoursStart,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm + 2)

                Divider().padding(.leading, 56)

                HStack {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Brand.gold)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.Brand.gold.opacity(0.14)))
                    Text("Bitiş")
                        .scaledFont(size: 15)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $prefs.quietHoursEnd,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm + 2)
            }
        }
    }

    // MARK: - Daily limit

    private var dailyLimitSection: some View {
        SettingsSection(title: "Günlük Limit", icon: "number.circle.fill", iconColor: Theme.Colors.info) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.info)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.Colors.info.opacity(0.14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Günlük Limit")
                        .scaledFont(size: 15, weight: .medium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(prefs.dailyNotificationLimit == 0
                         ? "Sınırsız"
                         : "Günde en fazla \(prefs.dailyNotificationLimit) bildirim")
                        .scaledFont(size: 12)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()

                Stepper(
                    value: $prefs.dailyNotificationLimit,
                    in: 0...50,
                    step: 1
                ) {
                    EmptyView()
                }
                .labelsHidden()
                .disabled(!prefs.notificationsEnabled)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 2)
            .opacity(prefs.notificationsEnabled ? 1 : 0.5)
        }
    }
}

// MARK: - Category Toggle Row

private struct CategoryToggleRow: View {
    let name: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "tag.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color.opacity(0.14)))

            Text(name)
                .scaledFont(size: 15, weight: .medium)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.Brand.primary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 2)
    }
}
