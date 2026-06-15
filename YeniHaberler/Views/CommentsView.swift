import SwiftUI
import os
import Combine

// MARK: - Comments View
struct CommentsView: View {
    let referenceId: Int
    let referenceType: String
    @StateObject private var viewModel = CommentsViewModel()
    @State private var commentText = ""
    @State private var userName = ""
    @State private var showAddComment = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - Sade ve Temiz
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Yorumlar")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let count = viewModel.commentCount {
                        Text("(\(count))")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Add Comment Button - Merkezde ve Sade
            VStack(spacing: 0) {
                Button(action: {
                    showAddComment.toggle()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Yorum Yap")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.8, green: 0.4, blue: 0.2)) // Kahverengi-kırmızı ton
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            
            // Comments List
            if viewModel.isLoading && viewModel.comments.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if viewModel.comments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("Henüz yorum yapılmamış")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.comments) { comment in
                        CommentRow(comment: comment, viewModel: viewModel)
                        Divider()
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showAddComment) {
            AddCommentView(
                referenceId: referenceId,
                referenceType: referenceType,
                parentId: nil,
                onCommentAdded: { message in
                    viewModel.showToast(message)
                    Task {
                        await viewModel.loadComments(referenceId: referenceId, referenceType: referenceType)
                        await viewModel.loadCommentCount(referenceId: referenceId, referenceType: referenceType)
                    }
                }
            )
        }
        .task {
            await viewModel.loadComments(referenceId: referenceId, referenceType: referenceType)
            await viewModel.loadCommentCount(referenceId: referenceId, referenceType: referenceType)
        }
        .toast($viewModel.toast)
    }
}

// MARK: - Comment Row
struct CommentRow: View {
    let comment: Comment
    let viewModel: CommentsViewModel
    @State private var showReplies = false
    @State private var showAddReply = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Comment Header - Sade Tasarım
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    // Name and Date
                    HStack(alignment: .firstTextBaseline) {
                        Text(comment.name.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(formatDate(comment.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Comment Body
                    Text(comment.body)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Like/Dislike and Reply - Sade Butonlar
            HStack(spacing: 16) {
                // Reply Button
                Button(action: {
                    showAddReply.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 12))
                        Text("Yanıtla")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Like Button
                Button(action: {
                    Task {
                        await viewModel.likeComment(commentId: comment.id, field: "like")
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 12))
                        Text("Beğen (\(comment.like))")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Dislike Button
                Button(action: {
                    Task {
                        await viewModel.likeComment(commentId: comment.id, field: "dislike")
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.system(size: 12))
                        Text("Beğenme (\(comment.dislike))")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Replies
            if let replies = comment.replies, !replies.isEmpty {
                Button(action: {
                    withAnimation {
                        showReplies.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: showReplies ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(replies.count) yanıt")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if showReplies {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(replies) { reply in
                            CommentRow(comment: reply, viewModel: viewModel)
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
            }
        }
        .background(Color(.systemGray6))
        .sheet(isPresented: $showAddReply) {
            AddCommentView(
                referenceId: comment.referenceId,
                referenceType: comment.referenceType,
                parentId: comment.id,
                onCommentAdded: { message in
                    viewModel.showToast(message)
                    Task {
                        await viewModel.loadComments(referenceId: comment.referenceId, referenceType: comment.referenceType)
                    }
                }
            )
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: dateString) {
            let now = Date()
            let timeInterval = now.timeIntervalSince(date)
            
            // Türkçe tarih formatı
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.timeZone = TimeZone.current
            
            if timeInterval < 60 {
                return "Az önce"
            } else if timeInterval < 3600 {
                let minutes = Int(timeInterval / 60)
                return "\(minutes) dakika önce"
            } else if timeInterval < 86400 {
                let hours = Int(timeInterval / 3600)
                return "\(hours) saat önce"
            } else if timeInterval < 604800 {
                let days = Int(timeInterval / 86400)
                return "\(days) gün önce"
            } else {
                formatter.dateFormat = "d MMM yyyy"
                return formatter.string(from: date)
            }
        }
        
        // Fallback: ISO format'ı parse etmeye çalış
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "d MMM yyyy"
            formatter.locale = Locale(identifier: "tr_TR")
            return formatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Add Comment View
struct AddCommentView: View {
    let referenceId: Int
    let referenceType: String
    let parentId: Int?
    /// Başarılı gönderim sonrası çağrılır; sunucudan dönen mesajı (varsa)
    /// parent view'a iletir — orada toast olarak gösterilir.
    let onCommentAdded: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var commentText = ""
    @State private var userName = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Comment Text Area - Büyük ve Sade
                    VStack(alignment: .leading, spacing: 0) {
                        TextEditor(text: $commentText)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .frame(minHeight: 150)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(
                                Group {
                                    if commentText.isEmpty {
                                        VStack {
                                            HStack {
                                                Text("Yorumlarınızı ve düşüncelerinizi bizimle paylaşın")
                                                    .foregroundColor(.secondary.opacity(0.5))
                                                    .font(.system(size: 15))
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                        .padding(12)
                                        .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    
                    // Name Input Field - Sade
                    TextField("Adınız soyadınız", text: $userName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Error Message
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Submit Button - Kahverengi-kırmızı ton
                    Button(action: {
                        Task {
                            await submitComment()
                        }
                    }) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSubmitting ? "Gönderiliyor..." : "Gönder")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            (commentText.isEmpty || userName.isEmpty || isSubmitting) ?
                                Color.gray.opacity(0.4) :
                                Color(red: 0.8, green: 0.4, blue: 0.2)
                        )
                        .cornerRadius(8)
                    }
                    .disabled(commentText.isEmpty || userName.isEmpty || isSubmitting)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(20)
            }
            .navigationTitle(parentId == nil ? "Yorum Yap" : "Yanıtla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func submitComment() async {
        guard !commentText.isEmpty, !userName.isEmpty else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        let request = AddCommentRequest(
            body: commentText,
            name: userName,
            referenceId: referenceId,
            referenceType: referenceType,
            parentId: parentId
        )
        
        do {
            let response = try await APIService.shared.addComment(request: request)
            // Sunucu mesajı tipik olarak "Yorum onaylanmak üzere site yöneticisine
            // gönderildi." — kullanıcıya bunu göstermek moderasyon beklentisini netleştirir.
            let message = response.message ?? "Yorumunuz alındı, teşekkürler."
            onCommentAdded(message)
            dismiss()
        } catch {
            errorMessage = "Yorum eklenirken bir hata oluştu: \(error.localizedDescription)"
        }

        isSubmitting = false
    }
}

// MARK: - Comments ViewModel
@MainActor
class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var commentCount: Int?
    @Published var isLoading = false
    @Published var toast: Toast?

    private let apiService = APIService.shared

    init() {}

    /// CommentsView'da .toast modifier ile bağlı; AddCommentView başarılı bir
    /// gönderim sonrası sunucu mesajını buraya yazar, banner otomatik açılır.
    func showToast(_ message: String, kind: Toast.Kind = .success) {
        toast = Toast(message: message, kind: kind)
    }
    
    func loadComments(referenceId: Int, referenceType: String, page: Int = 1) async {
        isLoading = true
        do {
            let response = try await apiService.fetchComments(
                referenceId: referenceId,
                referenceType: referenceType,
                page: page,
                perPage: 20
            )
            comments = response.data
        } catch {
            AppLogger.api.error("Comments load — \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }

    func loadCommentCount(referenceId: Int, referenceType: String) async {
        do {
            let response = try await apiService.getCommentCount(
                referenceId: referenceId,
                referenceType: referenceType
            )
            commentCount = response.data.count
        } catch {
            AppLogger.api.error("Comment count — \(error.localizedDescription, privacy: .public)")
        }
    }

    func likeComment(commentId: Int, field: String) async {
        do {
            let response = try await apiService.likeComment(commentId: commentId, field: field)
            if let updatedComment = response.data {
                if let index = comments.firstIndex(where: { $0.id == commentId }) {
                    comments[index] = updatedComment
                }
            }
        } catch {
            AppLogger.api.error("Like comment — \(error.localizedDescription, privacy: .public)")
        }
    }
}
