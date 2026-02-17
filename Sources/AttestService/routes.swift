import Vapor
import Attester
@preconcurrency import Crypto

func routes(_ app: Application) throws {
    guard let teamID = Environment.get("TEAM_ID"), !teamID.isEmpty else {
        throw Abort(.internalServerError, reason: "TEAM_ID must be set")
    }
    
    guard let bundleID = Environment.get("BUNDLE_ID"), !bundleID.isEmpty else {
        throw Abort(.internalServerError, reason: "BUNDLE_ID must be set")
    }
    
    guard let challengeSecret = Environment.get("CHALLENGE_SECRET"), !challengeSecret.isEmpty else {
        throw Abort(.internalServerError, reason: "CHALLENGE_SECRET must be set")
    }
    
    guard let bearerKey = Environment.get("BEARER_KEY"), !bearerKey.isEmpty else {
        throw Abort(.internalServerError, reason: "BEARER_KEY must be set")
    }
    
    let challengeService = ChallengeService(secretKey: challengeSecret)
    
    app.get("ping") { _ in
        "pong"
    }
    
    let protected = app.grouped(BearerKeyMiddleware(key: bearerKey))
    
    // Generate a challenge for attestation/assertion
    protected.post("challenge") { req async throws -> ChallengeResponse in
        let body = try req.content.decode(ChallengeRequest.self)
        let challenge = try challengeService.generateChallenge(userID: body.userID)
        
        return ChallengeResponse(challenge: challenge.base64EncodedString())
    }
    
    // Verify attestation from client
    protected.post("attest") { req async throws -> HTTPStatus in
        let body = try req.content.decode(AttestRequest.self)
        
        guard
            let challengeData = Data(base64Encoded: body.challenge),
            let attestationData = Data(base64Encoded: body.attestation),
            let keyIDData = Data(base64Encoded: body.keyID)
        else {
            throw Abort(.badRequest, reason: "Invalid base64 encoding")
        }
        
        // Verify challenge is valid
        _ = try challengeService.verifyChallenge(challengeData)
        
        let attestationRequest = AppAttest.AttestationRequest(
            attestation: attestationData,
            keyID: keyIDData
        )
        
        // Pass the full challenge data (not extracted nonce) since client hashed the entire blob
        _ = try AppAttest.verifyAttestation(
            challenge: challengeData,
            request: attestationRequest,
            appID: AppAttest.AppID(teamID: teamID, bundleID: bundleID)
        )
        
        return .noContent
    }
    
    // Verify assertion for subsequent requests
    // Note: Without external storage, we can't track counter for replay protection.
    // The Attester library's AssertionResult has an internal init, so we pass nil.
    // For full replay protection, store counter in Redis/DB and modify Attester.
    protected.post("assert") { req async throws -> HTTPStatus in
        let body = try req.content.decode(AssertRequest.self)
        
        guard
            let challengeData = Data(base64Encoded: body.challenge),
            let assertionData = Data(base64Encoded: body.assertion),
            let publicKeyData = Data(base64Encoded: body.publicKey),
            let clientData = Data(base64Encoded: body.clientData)
        else {
            throw Abort(.badRequest, reason: "Invalid base64 encoding")
        }
        
        // Verify challenge is valid
        _ = try challengeService.verifyChallenge(challengeData)
        let publicKey = try P256.Signing.PublicKey(x963Representation: publicKeyData)
        
        let assertionRequest = AppAttest.AssertionRequest(
            assertion: assertionData,
            clientData: clientData,
            challenge: challengeData
        )
        
        // Pass the full challenge data (not extracted nonce) since client hashed the entire blob
        _ = try AppAttest.verifyAssertion(
            challenge: challengeData,
            request: assertionRequest,
            previousResult: nil,
            publicKey: publicKey,
            appID: AppAttest.AppID(teamID: teamID, bundleID: bundleID)
        )
        
        return .noContent
    }
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
