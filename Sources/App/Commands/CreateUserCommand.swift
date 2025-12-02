import Vapor
import Fluent
import SQLKit

struct CreateUserCommand: Command {
    struct Signature: CommandSignature {
        @Argument(name: "username")
        var username: String
        
        @Argument(name: "password")
        var password: String
    }

    var help: String {
        "Creates a new user with the provided username and password."
    }

    func run(using context: CommandContext, signature: Signature) throws {
        let passwordHash = try Bcrypt.hash(signature.password)
        let user = User(username: signature.username, passwordHash: passwordHash)
        
        try user.save(on: context.application.db).wait()
        
        context.console.print("User '\(signature.username)' created successfully! ID: \(user.id ?? -1)")
        
        // Verify count
        let count = try User.query(on: context.application.db).count().wait()
        context.console.print("Total users in DB: \(count)")
        
        // Force Checkpoint
        if let sqlDb = context.application.db as? SQLDatabase {
            context.console.print("Forcing WAL checkpoint...")
            try sqlDb.raw("PRAGMA wal_checkpoint(TRUNCATE)").run().wait()
            context.console.print("Checkpoint complete.")
        }
    }
}
