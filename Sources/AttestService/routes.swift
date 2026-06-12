import Vapor
import Attester
@preconcurrency import Crypto
import Foundation

func routes(_ app: Application) throws {
    guard let teamID = Environment.get("TEAM_ID"), !teamID.isEmpty else {
        throw Abort(.internalServerError, reason: "TEAM_ID must be set")
    }
    
    guard let bundleID = Environment.get("BUNDLE_ID"), !bundleID.isEmpty else {
        throw Abort(.internalServerError, reason: "BUNDLE_ID must be set")
    }
    
    guard let bearerKey = Environment.get("BEARER_KEY"), !bearerKey.isEmpty else {
        throw Abort(.internalServerError, reason: "BEARER_KEY must be set")
    }
    
    let appIDString = "\(teamID).\(bundleID)"
    let environment = Environment.get("APP_ATTEST_ENVIRONMENT")
    let challengeLifetime = Environment.get("CHALLENGE_TTL_SECONDS")
        .flatMap(TimeInterval.init) ?? 300
    
    app.get("ping") { _ in
        "pong"
    }
    
    let protected = app.grouped(BearerKeyMiddleware(key: bearerKey))
    
    // Generate a challenge for attestation/assertion
    protected.post("challenge") { req async throws -> ChallengeResponse in
        let body = try req.content.decode(ChallengeRequest.self)
        let store = AppAttestStore(database: req.db, challengeLifetime: challengeLifetime)
        let challenge = try await store.createChallenge(
            userID: body.userID,
            purpose: body.purpose ?? .attestation
        )
        
        return ChallengeResponse(challenge: challenge.base64EncodedString())
    }
    
    // Verify attestation from client
    protected.post("attest") { req async throws -> AttestResponse in
        let body = try req.content.decode(AttestRequest.self)
        
        guard
            let challengeData = Data(base64Encoded: body.challenge),
            let attestationData = Data(base64Encoded: body.attestation),
            let keyIDData = Data(base64Encoded: body.keyID)
        else {
            throw Abort(.badRequest, reason: "Invalid base64 encoding")
        }
        
        let store = AppAttestStore(database: req.db, challengeLifetime: challengeLifetime)
        let consumedChallenge = try await store.consumeChallenge(
            challengeData,
            expectedPurpose: .attestation
        )
        
        let attestationRequest = AppAttest.AttestationRequest(
            attestation: attestationData,
            keyID: keyIDData
        )
        
        let result = try AppAttest.verifyAttestation(
            challenge: challengeData,
            request: attestationRequest,
            appID: AppAttest.AppID(teamID: teamID, bundleID: bundleID)
        )
        
        _ = try await store.saveAttestation(
            keyID: body.keyID,
            userID: consumedChallenge.userID,
            result: result,
            appID: appIDString,
            environment: environment
        )
        
        return AttestResponse(
            success: true,
            userID: consumedChallenge.userID,
            keyID: body.keyID,
            publicKey: result.publicKey.x963Representation.base64EncodedString()
        )
    }
    
    // Verify assertion for subsequent requests
    protected.post("assert") { req async throws -> AssertResponse in
        let body = try req.content.decode(AssertRequest.self)
        
        guard
            let challengeData = Data(base64Encoded: body.challenge),
            let assertionData = Data(base64Encoded: body.assertion),
            let clientData = Data(base64Encoded: body.clientData)
        else {
            throw Abort(.badRequest, reason: "Invalid base64 encoding")
        }
        
        let signedClientData = try validateAssertionClientData(
            clientData,
            challenge: challengeData,
            encodedChallenge: body.challenge
        )
        
        let store = AppAttestStore(database: req.db, challengeLifetime: challengeLifetime)
        let consumedChallenge = try await store.consumeChallenge(
            challengeData,
            expectedPurpose: .assertion
        )
        let storedKey = try await store.activeKey(keyID: body.keyID)
        
        guard let publicKeyData = Data(base64Encoded: storedKey.publicKey) else {
            throw Abort(.internalServerError, reason: "Stored public key is invalid")
        }
        
        let publicKey = try P256.Signing.PublicKey(x963Representation: publicKeyData)
        
        let assertionRequest = AppAttest.AssertionRequest(
            assertion: assertionData,
            clientData: clientData,
            challenge: challengeData
        )
        
        let result = try AppAttest.verifyAssertion(
            challenge: challengeData,
            request: assertionRequest,
            previousResult: nil,
            publicKey: publicKey,
            appID: AppAttest.AppID(teamID: teamID, bundleID: bundleID)
        )
        
        try await store.advanceCounter(
            keyID: body.keyID,
            counter: result.counter
        )
        
        return AssertResponse(
            success: true,
            userID: consumedChallenge.userID ?? storedKey.userID,
            counter: result.counter,
            action: signedClientData.action,
            payloadHash: signedClientData.payloadHash
        )
    }
}

private struct AssertionClientData: Decodable {
    let challenge: String
    let action: String
    let payloadHash: String
}

private func validateAssertionClientData(
    _ clientData: Data,
    challenge: Data,
    encodedChallenge: String
) throws -> AssertionClientData {
    guard let decoded = try? JSONDecoder().decode(AssertionClientData.self, from: clientData) else {
        throw Abort(.badRequest, reason: "Client data must be JSON")
    }
    
    guard decoded.challenge == encodedChallenge || Data(base64Encoded: decoded.challenge) == challenge else {
        throw Abort(.badRequest, reason: "Client data must contain the assertion challenge")
    }
    
    guard !decoded.action.isEmpty else {
        throw Abort(.badRequest, reason: "Client data action is required")
    }
    
    guard
        let payloadHash = Data(base64Encoded: decoded.payloadHash),
        payloadHash.count == 32
    else {
        throw Abort(.badRequest, reason: "Client data payload hash must be a SHA-256 base64 digest")
    }
    
    return decoded
}

struct BearerKeyMiddleware: AsyncMiddleware {
    let key: String
    
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let bearer = req.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing bearer token")
        }
        
        guard bearer.token == key else {
            throw Abort(.unauthorized, reason: "Invalid bearer token")
        }
        
        return try await next.respond(to: req)
    }
}
