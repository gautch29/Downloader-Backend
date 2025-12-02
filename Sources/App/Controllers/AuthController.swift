import Vapor
import Fluent

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("api", "auth")
        auth.post("login", use: login)
        auth.post("logout", use: logout)
        auth.get("session", use: checkSession)
        auth.post("password", use: changePassword)
    }

    struct LoginRequest: Content {
        var username: String
        var password: String
    }

    struct LoginResponse: Content {
        var success: Bool
        var user: UserResponse
    }

    struct UserResponse: Content {
        var username: String
    }
    
    struct SessionResponse: Content {
        var authenticated: Bool
        var user: UserResponse?
    }

    func checkSession(req: Request) async throws -> SessionResponse {
        guard let sessionID = req.cookies["session_id"]?.string else {
            return SessionResponse(authenticated: false, user: nil)
        }
        
        let authService = AuthService(db: req.db)
        if let user = try await authService.getUser(from: sessionID) {
            return SessionResponse(authenticated: true, user: UserResponse(username: user.username))
        }
        
        return SessionResponse(authenticated: false, user: nil)
    }
    
    struct ChangePasswordRequest: Content {
        var currentPassword: String
        var newPassword: String
    }

    func changePassword(req: Request) async throws -> HTTPStatus {
        guard let sessionID = req.cookies["session_id"]?.string else {
            throw Abort(.unauthorized)
        }
        
        let authService = AuthService(db: req.db)
        guard let user = try await authService.getUser(from: sessionID) else {
            throw Abort(.unauthorized)
        }
        
        let changeReq = try req.content.decode(ChangePasswordRequest.self)
        
        guard try authService.verifyPassword(changeReq.currentPassword, hash: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Current password incorrect")
        }
        
        user.passwordHash = try authService.hashPassword(changeReq.newPassword)
        try await user.save(on: req.db)
        
        return .ok
    }

    func login(req: Request) async throws -> Response {
        let loginReq = try req.content.decode(LoginRequest.self)
        req.logger.info("Login attempt for user: \(loginReq.username)")
        
        let authService = AuthService(db: req.db)
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == loginReq.username)
            .first() else {
            req.logger.warning("Login failed: User not found for username: \(loginReq.username)")
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }

        guard try authService.verifyPassword(loginReq.password, hash: user.passwordHash) else {
            req.logger.warning("Login failed: Invalid password for user: \(loginReq.username)")
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        req.logger.info("Login successful for user: \(loginReq.username)")

        let session = try await authService.createSession(for: user)
        
        let response = Response()
        response.status = .ok
        
        let cookie = HTTPCookies.Value(
            string: session.id!,
            expires: session.expiresAt,
            path: "/",
            isHTTPOnly: true
        )
        response.cookies["session_id"] = cookie
        
        try response.content.encode(LoginResponse(success: true, user: UserResponse(username: user.username)))
        return response
    }

    func logout(req: Request) async throws -> Response {
        let response = Response()
        response.cookies["session_id"] = .init(string: "", path: "/", isHTTPOnly: true)
        response.status = .ok
        return response
    }
}
