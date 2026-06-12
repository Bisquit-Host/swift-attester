@testable import AttestService
import Darwin
import Foundation
import NIOCore
import VaporTesting
import Testing

@Suite("App Tests", .serialized)
struct AttestServiceTests {
    @Test("Configure app routes without opening Postgres connection")
    func configureRoutes() async throws {
        let environment = TemporaryEnvironment([
            "TEAM_ID": "ABCDE12345",
            "BUNDLE_ID": "host.bisquit.Bisquit-host",
            "BEARER_KEY": "test-bearer"
        ])
        environment.apply()
        defer { environment.restore() }
        
        try await withApp { app in
            try routes(app)
            
            try await app.testing().test(.GET, "ping") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "pong")
            }
            
            try await app.testing().test(.POST, "challenge") { res async in
                #expect(res.status == .unauthorized)
            }
        }
    }
    
    @Test("Rejects malformed assertion client data before database access")
    func malformedAssertionClientData() async throws {
        let environment = TemporaryEnvironment([
            "TEAM_ID": "ABCDE12345",
            "BUNDLE_ID": "host.bisquit.Bisquit-host",
            "BEARER_KEY": "test-bearer"
        ])
        environment.apply()
        defer { environment.restore() }
        
        let challenge = Data("challenge".utf8).base64EncodedString()
        let clientData = Data("""
        {"challenge":"\(challenge)","action":"login","payloadHash":"not-base64"}
        """.utf8).base64EncodedString()
        let requestBody = Data("""
        {"challenge":"\(challenge)","assertion":"AA==","keyID":"AA==","clientData":"\(clientData)"}
        """.utf8)
        var body = ByteBufferAllocator().buffer(capacity: requestBody.count)
        body.writeData(requestBody)
        
        try await withApp { app in
            try routes(app)
            
            try await app.testing().test(
                .POST,
                "assert",
                headers: [
                    "Authorization": "Bearer test-bearer",
                    "Content-Type": "application/json"
                ],
                body: body
            ) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }
}

private struct TemporaryEnvironment {
    private let updates: [String: String]
    private let previous: [String: String?]
    
    init(_ updates: [String: String]) {
        self.updates = updates
        self.previous = updates.reduce(into: [:]) { previous, update in
            if let value = getenv(update.key) {
                previous[update.key] = String(cString: value)
            } else {
                previous[update.key] = nil
            }
        }
    }
    
    func apply() {
        for (key, value) in updates {
            setenv(key, value, 1)
        }
    }
    
    func restore() {
        for (key, value) in previous {
            if let value {
                setenv(key, value, 1)
            } else {
                unsetenv(key)
            }
        }
    }
}
