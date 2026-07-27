//
//  FirestoreTransactionRepository.swift
//  PayReview
//
//  Created by 廖為 on 2026/7/27.
//

import FirebaseFirestore

final class FirestoreTransactionRepository: TransactionRepository {
    private let collection: CollectionReference
    
    init(uid: String) {
        collection = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("transactions")
    }
    
    func newTransactionID() -> String {
        collection.document().documentID
    }
    
    func observeTransactions() async -> AsyncStream<[TransactionRecord]> {
        AsyncStream<[TransactionRecord]> { continuation in
            let listener = collection.addSnapshotListener { snapshot, error in
                if let error {
                    print("Firestore listener error: \(error)")
                    continuation.finish()
                    return
                }
                
                let records = snapshot?.documents.compactMap { document -> TransactionRecord? in
                    try? document.data(as: TransactionRecord.self)
                } ?? []
                continuation.yield(records)
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    func addTransaction(_ transaction: TransactionRecord) async throws {
        try collection.document(transaction.id).setData(from: transaction)
    }

    func updateTransaction(_ transaction: TransactionRecord) async throws {
        try collection.document(transaction.id).setData(from: transaction)
    }
}
