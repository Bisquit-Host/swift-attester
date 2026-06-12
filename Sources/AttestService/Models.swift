import Vapor

struct ChallengeRequest: Content {
    let userID: String?
    let purpose: AppAttestChallengePurpose?
}

struct ChallengeResponse: Content {
    let challenge: String
}

struct AttestRequest: Content {
    let challenge: String
    let attestation: String
    let keyID: String
}

struct AttestResponse: Content {
    let success: Bool
    let userID: String?
    let keyID: String
    let publicKey: String
}

struct AssertRequest: Content {
    let challenge: String
    let assertion: String
    let keyID: String
    let clientData: String
}

struct AssertResponse: Content {
    let success: Bool
    let userID: String?
    let counter: Int
    let action: String
    let payloadHash: String
}
