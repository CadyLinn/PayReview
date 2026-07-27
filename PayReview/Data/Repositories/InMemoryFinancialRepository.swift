import Foundation
actor InMemoryFinancialRepository: TransactionRepository {
    private var transactions: [TransactionRecord]
    private var continuations: [UUID: AsyncStream<[TransactionRecord]>.Continuation] = [:]

    /// `seed` lets callers (mainly SwiftUI #Preview) start this fake repository
    /// pre-populated, so a preview can show a realistic "already has data" state
    /// without going through async addTransaction() calls first.
    init(seed: [TransactionRecord] = []) {
        transactions = seed
    }

    func observeTransactions() async -> AsyncStream<[TransactionRecord]> {
        // 1. 用 AsyncStream { continuation in ... } 建立一個 stream
        // 2. continuation.yield(transactions) 先送出目前的資料
        // 3. 用一個 UUID 當 key，把 continuation 存進 continuations
        // 4. 設定 continuation.onTermination，結束時把這個 key 從 continuations 移除
        // 5. return 這個 stream
        let id = UUID()
        return AsyncStream<[TransactionRecord]> { continuation in
            continuation.yield(transactions)
            self.continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }
    
    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
    
    nonisolated func newTransactionID() -> String {
        UUID().uuidString
    }
    
    func addTransaction(_ transaction: TransactionRecord) async throws {
        transactions.append(transaction)
        for continuation in continuations.values {
            continuation.yield(transactions)
        }
    }
}
