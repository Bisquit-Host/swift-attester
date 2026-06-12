import Fluent
import FluentPostgresDriver
import Vapor

func configureDatabase(_ app: Application) async throws {
    if let databaseURL = Environment.get("DATABASE_URL"), !databaseURL.isEmpty {
        app.databases.use(try .postgres(url: databaseURL), as: .psql)
    } else {
        let configuration = SQLPostgresConfiguration(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432,
            username: Environment.get("DATABASE_USERNAME") ?? Environment.get("DATABASE_USER") ?? "vapor",
            password: Environment.get("DATABASE_PASSWORD"),
            database: Environment.get("DATABASE_NAME") ?? "attest_service",
            tls: .disable
        )
        
        app.databases.use(
            .postgres(configuration: configuration),
            as: .psql
        )
    }
    
    app.migrations.add(CreateAppAttestChallenge())
    app.migrations.add(CreateAppAttestKey())
    
    try await app.autoMigrate()
}
