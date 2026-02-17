@preconcurrency import Crypto
import Foundation

struct ChallengeService: Sendable {
    private let key: SymmetricKey
    private let maxAge: TimeInterval
    
    init(secretKey: String, maxAge: TimeInterval = 300) {
        let keyData = SHA256.hash(data: Data(secretKey.utf8))
        self.key = SymmetricKey(data: keyData)
        self.maxAge = maxAge
    }
    
    func generateChallenge(userID: String?) throws -> Data {
        let nonce = Data(AES.GCM.Nonce())
        let timestamp = UInt64(Date().timeIntervalSince1970)
        let userIDData = Data((userID ?? "").utf8)
        let userIDLength = UInt16(userIDData.count)
        
        var payload = nonce
        payload.append(contentsOf: withUnsafeBytes(of: timestamp) { Data($0) })
        payload.append(contentsOf: withUnsafeBytes(of: userIDLength) { Data($0) })
        payload.append(userIDData)
        
        let sealed = try AES.GCM.seal(payload, using: key)
        
        guard let combined = sealed.combined else {
            throw ChallengeError.invalidPayload
        }
        
        return combined
    }
    
    func verifyChallenge(_ challenge: Data) throws -> (nonce: Data, userID: String?) {
        let box = try AES.GCM.SealedBox(combined: challenge)
        let payload = try AES.GCM.open(box, using: key)
        
        // nonce (12) + timestamp (8) + userIDLength (2) = 22 minimum
        guard payload.count >= 22 else {
            throw ChallengeError.invalidPayload
        }
        
        let nonce = payload.prefix(12)
        let timestamp = payload.dropFirst(12).prefix(8).withUnsafeBytes { $0.load(as: UInt64.self) }
        let userIDLength = payload.dropFirst(20).prefix(2).withUnsafeBytes { $0.load(as: UInt16.self) }
        
        guard Date().timeIntervalSince1970 - Double(timestamp) < maxAge else {
            throw ChallengeError.expired
        }
        
        let userID: String?
        
        if userIDLength > 0 {
            guard let decoded = String(data: payload.dropFirst(22).prefix(Int(userIDLength)), encoding: .utf8) else {
                throw ChallengeError.invalidPayload
            }
            
            userID = decoded
        } else {
            userID = nil
        }
        
        return (Data(nonce), userID)
    }
}
