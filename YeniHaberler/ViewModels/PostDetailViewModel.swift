import Foundation
import Combine

@MainActor
class PostDetailViewModel: ObservableObject {
    @Published var post: PostDetail?
    @Published var relatedPost: Post?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var htmlContentParts: (first: String, second: String) = ("", "")

    @Published private(set) var chainPosts: [PostDetail] = []
    @Published private(set) var chainContent: [Int: (first: String, second: String)] = [:]
    @Published private(set) var chainRelated: [Int: Post] = [:]
    @Published private(set) var isLoadingNext = false
    @Published private(set) var hasMoreNext = true

    private let apiService = APIService.shared
    private var queue: [Post] = []
    private var queuePagination = PaginationState()
    private var loadedIds = Set<Int>()
    private let queuePerPage = 10

    func loadPost(id: Int) async {
        isLoading = true
        errorMessage = nil
        chainPosts = []
        chainContent = [:]
        chainRelated = [:]
        queue = []
        queuePagination.reset()
        loadedIds = [id]
        hasMoreNext = true

        do {
            let response = try await apiService.fetchPostDetail(id: id)
            post = response.data
            splitHTMLContent(response.data.content)
            await loadRelatedPost(post: response.data)
        } catch {
            errorMessage = "Haber yüklenirken bir hata oluştu. Lütfen tekrar deneyin."
        }

        isLoading = false
    }

    /// Zincirdeki bir sonraki haberi yükler. View, son haberin alt sınırına yaklaştığında çağırır.
    func loadNextInChain() async {
        guard !isLoadingNext, hasMoreNext else { return }
        isLoadingNext = true
        defer { isLoadingNext = false }

        if queue.isEmpty {
            await refillQueueIfNeeded()
        }

        guard !queue.isEmpty else {
            if !queuePagination.hasMore { hasMoreNext = false }
            return
        }

        let next = queue.removeFirst()
        loadedIds.insert(next.id)

        do {
            let response = try await apiService.fetchPostDetail(id: next.id)
            let detail = response.data
            chainContent[detail.id] = computeSplitParts(detail.content)
            chainPosts.append(detail)

            if let category = detail.categories.keys.first,
               let related = try? await apiService.fetchRelatedPosts(postId: detail.id, categoryId: category) {
                let filtered = related.data.filter { $0.id != detail.id }
                chainRelated[detail.id] = filtered.randomElement() ?? filtered.first
            }
        } catch {
            // Bu haber yüklenemediyse zinciri kırma — bir sonrakine geçilebilir.
        }

        if queue.count < 3 && queuePagination.hasMore {
            Task { await refillQueueIfNeeded() }
        }
    }

    private func splitHTMLContent(_ content: String) {
        htmlContentParts = computeSplitParts(content)
    }

    private func computeSplitParts(_ content: String) -> (first: String, second: String) {
        let paragraphs = content.components(separatedBy: "</p>")
        guard paragraphs.count > 2 else {
            return (content, "")
        }
        let midPoint = paragraphs.count / 2
        let firstPart = paragraphs[0..<midPoint].joined(separator: "</p>") + "</p>"
        let secondPart = paragraphs[midPoint..<paragraphs.count].joined(separator: "</p>")
        return (firstPart, secondPart)
    }

    private func loadRelatedPost(post: PostDetail) async {
        guard !post.categories.isEmpty else { return }
        let categoryIds = Array(post.categories.keys)
        guard let randomCategoryId = categoryIds.randomElement() else { return }

        do {
            let response = try await apiService.fetchRelatedPosts(postId: post.id, categoryId: randomCategoryId)
            let filteredPosts = response.data.filter { $0.id != post.id }
            relatedPost = filteredPosts.randomElement() ?? filteredPosts.first
        } catch {
            // sessizce yut
        }
    }

    private func refillQueueIfNeeded() async {
        guard queuePagination.hasMore, !queuePagination.isLoadingMore else { return }
        queuePagination.willLoadMore()
        do {
            let response = try await apiService.fetchLatestPosts(
                page: queuePagination.currentPage,
                limit: queuePerPage,
                excepts: Array(loadedIds)
            )
            let newItems = response.data.filter { item in
                !loadedIds.contains(item.id) && !queue.contains(where: { $0.id == item.id })
            }
            queue.append(contentsOf: newItems)
            queuePagination.didLoadPage(itemsReceived: response.data.count, expected: queuePerPage)
            if !queuePagination.hasMore && queue.isEmpty {
                hasMoreNext = false
            }
        } catch {
            queuePagination.didFail()
        }
    }
}
