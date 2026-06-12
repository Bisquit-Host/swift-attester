import Fluent
import Foundation

enum AppAttestKeyStatus: String, Codable {
    case active, revoked
}

final class AppAttestKey: Model, @unchecked Sendable {
    static let schema = "app_attest_keys"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "key_id")
    var keyID: String
    
    @OptionalField(key: "user_id")
    var userID: String?
    
    @Field(key: "public_key")
    var publicKey: String
    
    @Field(key: "receipt")
    var receipt: String
    
    @Field(key: "app_id")
    var appID: String
    
    @OptionalField(key: "environment")
    var environment: String?
    
    @OptionalField(key: "bundle_version")
    var bundleVersion: String?
    
    @OptionalField(key: "launch_validation_category")
    var launchValidationCategory: String?
    
    @OptionalField(key: "last_counter")
    var lastCounter: Int?
    
    @Field(key: "status")
    var status: String
    
    @OptionalField(key: "last_seen_at")
    var lastSeenAt: Date?
    
    @Field(key: "created_at")
    var createdAt: Date
    
    @Field(key: "updated_at")
    var updatedAt: Date
    
    init() {}
    
    init(
        keyID: String,
        userID: String?,
        publicKey: String,
        receipt: String,
        appID: String,
        environment: String?,
        createdAt: Date = Date()
    ) {
        self.keyID = keyID
        self.userID = userID
        self.publicKey = publicKey
        self.receipt = receipt
        self.appID = appID
        self.environment = environment
        self.status = AppAttestKeyStatus.active.rawValue
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

struct CreateAppAttestKey: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(AppAttestKey.schema)
            .id()
            .field("key_id", .string, .required)
            .field("user_id", .string)
            .field("public_key", .string, .required)
            .field("receipt", .string, .required)
            .field("app_id", .string, .required)
            .field("environment", .string)
            .field("bundle_version", .string)
            .field("launch_validation_category", .string)
            .field("last_counter", .int)
            .field("status", .string, .required)
            .field("last_seen_at", .datetime)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "key_id")
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema(AppAttestKey.schema).delete()
    }
}
