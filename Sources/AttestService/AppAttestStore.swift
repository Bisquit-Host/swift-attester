import Attester
@preconcurrency import Crypto
import Fluent
import FluentPostgresDriver
import Foundation
import Vapor

struct ConsumedAppAttestChallenge: Sendable {
    let userID: String?
    let purpose: AppAttestChallengePurpose
}

struct AppAttestStore {
    let database: any Database
    let challengeLifetime: TimeInterval
    
    init(database: any Database, challengeLifetime: TimeInterval = 300) {
        self.database = database
        self.challengeLifetime = challengeLifetime
    }
    
    func createChallenge(userID: String?, purpose: AppAttestChallengePurpose) async throws -> Data {
        let challenge = Self.randomChallenge()
        let now = Date()
        let record = AppAttestChallenge(
            challengeHash: Self.hash(challenge),
            userID: userID?.nonEmpty,
            purpose: purpose,
            expiresAt: now.addingTimeInterval(challengeLifetime),
            createdAt: now
        )
        
        try await record.create(on: database)
        return challenge
    }
    
    func consumeChallenge(
        _ challenge: Data,
        expectedPurpose: AppAttestChallengePurpose
    ) async throws -> ConsumedAppAttestChallenge {
        guard let sql = database as? any SQLDatabase else {
            throw Abort(.internalServerError, reason: "Configured database does not support SQL")
        }
        
        let now = Date()
        let rows = try await sql.raw("""
        UPDATE \(ident: AppAttestChallenge.schema)
        SET \(ident: "consumed_at") = \(bind: now)
        WHERE \(ident: "challenge_hash") = \(bind: Self.hash(challenge))
        AND \(ident: "purpose") = \(bind: expectedPurpose.rawValue)
        AND \(ident: "consumed_at") IS NULL
        AND \(ident: "expires_at") > \(bind: now)
        RETURNING \(ident: "user_id"), \(ident: "purpose")
        """).all()
        
        guard let row = rows.first else {
            throw Abort(.badRequest, reason: "Challenge is missing, expired, already consumed, or not valid for this request")
        }
        
        let purposeRaw = try row.decode(column: "purpose", as: String.self)
        guard let purpose = AppAttestChallengePurpose(rawValue: purposeRaw) else {
            throw Abort(.internalServerError, reason: "Stored challenge purpose is invalid")
        }
        
        return try ConsumedAppAttestChallenge(
            userID: row.decode(column: "user_id", as: String?.self),
            purpose: purpose
        )
    }
    
    @discardableResult
    func saveAttestation(
        keyID: String,
        userID: String?,
        result: AppAttest.AttestationResult,
        appID: String,
        environment: String?
    ) async throws -> AppAttestKey {
        let now = Date()
        let publicKey = result.publicKey.x963Representation.base64EncodedString()
        let receipt = result.receipt.base64EncodedString()
        
        if let existing = try await AppAttestKey.query(on: database)
            .filter(\.$keyID == keyID)
            .first()
        {
            existing.userID = existing.userID ?? userID?.nonEmpty
            existing.publicKey = publicKey
            existing.receipt = receipt
            existing.appID = appID
            existing.environment = environment
            existing.status = AppAttestKeyStatus.active.rawValue
            existing.updatedAt = now
            
            try await existing.update(on: database)
            return existing
        }
        
        let record = AppAttestKey(
            keyID: keyID,
            userID: userID?.nonEmpty,
            publicKey: publicKey,
            receipt: receipt,
            appID: appID,
            environment: environment,
            createdAt: now
        )
        
        try await record.create(on: database)
        return record
    }
    
    func activeKey(keyID: String) async throws -> AppAttestKey {
        guard let key = try await AppAttestKey.query(on: database)
            .filter(\.$keyID == keyID)
            .filter(\.$status == AppAttestKeyStatus.active.rawValue)
            .first()
        else {
            throw Abort(.badRequest, reason: "Attested key is not registered")
        }
        
        return key
    }
    
    func advanceCounter(keyID: String, counter: Int) async throws {
        guard let sql = database as? any SQLDatabase else {
            throw Abort(.internalServerError, reason: "Configured database does not support SQL")
        }
        
        let now = Date()
        let rows = try await sql.raw("""
        UPDATE \(ident: AppAttestKey.schema)
        SET \(ident: "last_counter") = \(bind: counter),
            \(ident: "last_seen_at") = \(bind: now),
            \(ident: "updated_at") = \(bind: now)
        WHERE \(ident: "key_id") = \(bind: keyID)
        AND \(ident: "status") = \(bind: AppAttestKeyStatus.active.rawValue)
        AND (\(ident: "last_counter") IS NULL OR \(ident: "last_counter") < \(bind: counter))
        RETURNING \(ident: "id")
        """).all()
        
        guard rows.count == 1 else {
            throw Abort(.badRequest, reason: "Assertion counter did not increase")
        }
    }
    
    private static func randomChallenge() -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }
    
    private static func hash(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).base64EncodedString()
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
