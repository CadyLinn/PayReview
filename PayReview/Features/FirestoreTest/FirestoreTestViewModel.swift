import Combine
import Foundation

@MainActor
final class FirestoreTestViewModel: ObservableObject {
    @Published private(set) var snapshot: FinancialDataSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let repository: FinancialDataRepository

    init() {
        repository = InMemoryFinancialDataRepository()
    }

    init(repository: FinancialDataRepository) {
        self.repository = repository
    }

    func dismissError() {
        errorMessage = nil
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            snapshot = try await repository.loadSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
