import Vapor
import Fluent

actor PlexService {
    let client: Client
    let db: Database

    init(client: Client, db: Database) {
        self.client = client
        self.db = db
    }

    func scanLibrary() async {
        do {
            guard let setting = try await Setting.query(on: db).first(),
                  let plexUrl = setting.plexUrl,
                  let plexToken = setting.plexToken,
                  !plexUrl.isEmpty,
                  !plexToken.isEmpty else {
                return
            }

            let baseUrl = plexUrl.hasSuffix("/") ? String(plexUrl.dropLast()) : plexUrl
            let url = "\(baseUrl)/library/sections/all/refresh"

            let response = try await client.get(URI(string: url)) { req in
                req.headers.add(name: "X-Plex-Token", value: plexToken)
            }

            if response.status == .ok {
                print("[Plex] Library scan triggered successfully.")
            } else {
                print("[Plex] Failed to trigger scan. Status: \(response.status)")
            }
        } catch {
            print("[Plex] Error triggering scan: \(error)")
        }
    }
}
