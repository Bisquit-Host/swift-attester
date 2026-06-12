import Fluent
import Foundation

enum AppAttestChallengePurpose: String, Codable {
    case attestation, assertion
}

final class AppAttestChallenge: Model, @unchecked Sendable {
    static let schema = "app_attest_challenges"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "challenge_hash")
    var challengeHash: String
    
    @OptionalField(key: "user_id")
    var userID: String?
    
    @Field(key: "purpose")
    var purpose: String
    
    @Field(key: "expires_at")
    var expiresAt: Date
    
    @OptionalField(key: "consumed_at")
    var consumedAt: Date?
    
    @Field(key: "created_at")
    var createdAt: Date
    
    init() {}
    
    init(
        challengeHash: String,
        userID: String?,
        purpose: AppAttestChallengePurpose,
        expiresAt: Date,
        createdAt: Date = Date()
    ) {
        self.challengeHash = challengeHash
        self.userID = userID
        self.purpose = purpose.rawValue
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

struct CreateAppAttestChallenge: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(AppAttestChallenge.schema)
            .id()
            .field("challenge_hash", .string, .required)
            .field("user_id", .string)
            .field("purpose", .string, .required)
            .field("expires_at", .datetime, .required)
            .field("consumed_at", .datetime)
            .field("created_at", .datetime, .required)
            .unique(on: "challenge_hash")
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema(AppAttestChallenge.schema).delete()
    }
}
