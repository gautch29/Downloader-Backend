import Vapor
import Fluent
import BCrypt

struct AuthService {
    let db: Database

    func verifyPassword(_ password: String, hash: String) throws -> Bool {
        return try Bcrypt.verify(password, created: hash)
    }

    func hashPassword(_ password: String) throws -> String {
        return try Bcrypt.hash(password)
    }

    func createSession(for user: User) async throws -> Session {
        let sessionID = UUID().uuidString
        // Expires in 7 days
        let expiresAt = Date().addingTimeInterval(60 * 60 * 24 * 7)
        
        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User has no ID")
        }

        let session = Session(id: sessionID, userID: userID, expiresAt: expiresAt)
        try await session.save(on: db)
        return session
    }

    func getUser(from sessionID: String) async throws -> User? {
        guard let session = try await Session.query(on: db)
            .filter(\.$id == sessionID)
            .filter(\.$expiresAt > Date())
            .with(\.$user)
            .first() else {
            return nil
        }
        return session.user
    }
}
