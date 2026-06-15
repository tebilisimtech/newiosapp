import SwiftUI
import os

// MARK: - Contact Form View

struct ContactFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var subject: String = ""
    @State private var content: String = ""

    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && isValidEmail(email)
            && content.trimmingCharacters(in: .whitespaces).count >= 10
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.groupedBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        header
                        formCard
                        errorBanner
                        submitButton
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.lg)
                }
            }
            .navigationTitle("Bize Ulaşın")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .alert("Mesajınız Gönderildi", isPresented: $showSuccessAlert) {
                Button("Tamam") { dismiss() }
            } message: {
                Text("Geri bildiriminiz için teşekkür ederiz. En kısa sürede sizinle iletişime geçeceğiz.")
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Theme.Brand.primary.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "envelope.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Theme.Brand.primary)
            }

            Text("Görüş, öneri veya sorularınız için")
                .scaledFont(size: 14)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Text("formu doldurun")
                .scaledFont(size: 14)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(.top, Theme.Spacing.lg)
    }

    private var formCard: some View {
        VStack(spacing: 0) {
            field(
                label: "Ad Soyad",
                icon: "person.fill",
                placeholder: "Adınız Soyadınız",
                text: $name,
                keyboardType: .default,
                isRequired: true
            )
            Divider().padding(.leading, 56)

            field(
                label: "E-posta",
                icon: "envelope.fill",
                placeholder: "ornek@email.com",
                text: $email,
                keyboardType: .emailAddress,
                isRequired: true
            )
            Divider().padding(.leading, 56)

            field(
                label: "Telefon",
                icon: "phone.fill",
                placeholder: "+90 5XX XXX XX XX (opsiyonel)",
                text: $phone,
                keyboardType: .phonePad,
                isRequired: false
            )
            Divider().padding(.leading, 56)

            field(
                label: "Konu",
                icon: "text.cursor",
                placeholder: "Konu başlığı (opsiyonel)",
                text: $subject,
                keyboardType: .default,
                isRequired: false
            )

            Divider().padding(.leading, 56)

            // Mesaj alanı (multiline)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Brand.primary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.Brand.primary.opacity(0.12)))

                    Text("Mesaj *")
                        .scaledFont(size: 13, weight: .semibold)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Spacer()
                    Text("\(content.count)/1000")
                        .scaledFont(size: 11)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                TextEditor(text: $content)
                    .scaledFont(size: 14)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(Theme.Colors.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
                    )
                    .onChange(of: content) { newValue in
                        if newValue.count > 1000 {
                            content = String(newValue.prefix(1000))
                        }
                    }
            }
            .padding(Theme.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
    }

    @ViewBuilder
    private func field(
        label: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        isRequired: Bool
    ) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Brand.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.Brand.primary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text(label)
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundColor(Theme.Colors.textSecondary)
                    if isRequired {
                        Text("*").foregroundColor(Theme.Brand.primary).scaledFont(size: 11, weight: .bold)
                    }
                }
                TextField(placeholder, text: text)
                    .scaledFont(size: 15)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                    .autocorrectionDisabled(keyboardType == .emailAddress)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 2)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = errorMessage {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.Colors.danger)
                Text(errorMessage)
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundColor(Theme.Colors.danger)
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(Theme.Colors.danger.opacity(0.10))
            )
        }
    }

    private var submitButton: some View {
        Button(action: { Task { await submit() } }) {
            HStack(spacing: Theme.Spacing.sm) {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isSubmitting ? "Gönderiliyor..." : "Mesajı Gönder")
                    .scaledFont(size: 15, weight: .bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md + 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(isFormValid && !isSubmitting ? Theme.Brand.primary : Theme.Colors.borderSubtle)
            )
        }
        .disabled(!isFormValid || isSubmitting)
    }

    // MARK: - Actions

    private func submit() async {
        guard isFormValid else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let request = ContactRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            content: content.trimmingCharacters(in: .whitespaces),
            subject: subject.isEmpty ? nil : subject.trimmingCharacters(in: .whitespaces),
            phone: phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespaces),
            address: nil
        )

        do {
            _ = try await APIService.shared.sendContactMessage(request: request)
            showSuccessAlert = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            errorMessage = "Mesaj gönderilemedi. Lütfen tekrar deneyin."
            AppLogger.api.error("Contact submit — \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Validation

    private func isValidEmail(_ string: String) -> Bool {
        let pattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return string.range(of: pattern, options: .regularExpression) != nil
    }
}
