import Vapor
import SwiftSoup
import Fluent


struct ZTScraper {
    let client: Client
    let baseURL = "https://www.zone-telechargement.irish"

    struct SearchResult: Content {
        let id: String
        let title: String
        let type: String
        let quality: String
        let language: String
        let poster: String
        let links: [String]
    }

    struct Episode: Content {
        let episode: String
        let link: String
    }

    // MARK: - Search
    func search(query: String) async throws -> [SearchResult] {
        // Search films
        let films = try await searchCategory(category: "films", query: query)
        // Search series
        let series = try await searchCategory(category: "series", query: query)

        let allResults = films.map { $0.toSearchResult(type: "movie", baseURL: baseURL) } +
                         series.map { $0.toSearchResult(type: "series", baseURL: baseURL) }
        
        return allResults
    }

    private func searchCategory(category: String, query: String) async throws -> [ZTMovieData] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "\(baseURL)/?p=\(category)&search=\(encodedQuery)&page=1"
        
        print("[ZTScraper] Searching \(category) with URL: \(url)")
        
        print("[ZTScraper] Searching \(category) with URL: \(url)")
        
        var headers = HTTPHeaders()
        headers.add(name: "User-Agent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        
        let response = try await client.get(URI(string: url), headers: headers)
        
        guard let body = response.body else {
            print("[ZTScraper] Empty body for \(url)")
            return []
        }
        
        let html = String(buffer: body)
        // print("[ZTScraper] HTML Length: \(html.count)")
        
        let doc = try SwiftSoup.parse(html)
        
        let elements = try doc.select("#dle-content .cover_global")
        print("[ZTScraper] Found \(elements.size()) elements for \(category)")
        
        var results: [ZTMovieData] = []
        
        for element in elements {
            let titleAnchor = try element.select(".cover_infos_title a").first()
            let title = try titleAnchor?.text() ?? "Unknown"
            let href = try titleAnchor?.attr("href") ?? ""
            let fullUrl = href.starts(with: "http") ? href : baseURL + href
            
            let img = try element.select("img").first()
            let imgSrc = try img?.attr("src") ?? ""
            let fullImg = imgSrc.starts(with: "http") ? imgSrc : baseURL + imgSrc
            
            let detailRelease = try element.select(".cover_infos_global .detail_release")
            let quality = try detailRelease.select("span").get(0).text()
            let language = try detailRelease.select("span").get(1).text()
            
            results.append(ZTMovieData(
                title: title,
                url: fullUrl,
                image: fullImg,
                quality: quality,
                language: language
            ))
        }
        
        return results
    }

    // MARK: - Links (Movies)
    func getLinks(url: String) async throws -> [String] {
        let fullUrl = url.starts(with: "http") ? url : baseURL + url
        
        var headers = HTTPHeaders()
        headers.add(name: "User-Agent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        
        let response = try await client.get(URI(string: fullUrl), headers: headers)
        guard let body = response.body else { return [] }
        let html = String(buffer: body)
        let doc = try SwiftSoup.parse(html)
        
        var links: [String] = []
        
        // Strategy: Find '1fichier' text in <b> tags
        let boldTags = try doc.select("b")
        for bold in boldTags {
            let text = try bold.text().lowercased()
            if text.contains("1fichier") {
                // Check next sibling
                var next = try bold.nextElementSibling()
                if let nextEl = next, try nextEl.tagName() == "br" {
                    next = try nextEl.nextElementSibling()
                }
                
                if let nextEl = next {
                    if try nextEl.tagName() == "a" {
                        let href = try nextEl.attr("href")
                        if !href.isEmpty { links.append(href) }
                    } else {
                        let nestedLink = try nextEl.select("a").first()
                        if let href = try nestedLink?.attr("href"), !href.isEmpty {
                            links.append(href)
                        }
                    }
                } else {
                    // Try parent's next element
                    if let parent = bold.parent() {
                        let parentNext = try parent.nextElementSibling()
                        if let parentLink = try parentNext?.select("a").first() {
                            let href = try parentLink.attr("href")
                            if !href.isEmpty { links.append(href) }
                        }
                    }
                }
            }
        }
        
        // Fallback
        if links.isEmpty {
            let allLinks = try doc.select("a")
            for link in allLinks {
                let href = try link.attr("href")
                let text = try link.text().lowercased()
                
                if (href.contains("1fichier.com") || href.contains("dl-protect")) &&
                   (text.contains("télécharger") || text.contains("telecharger") || text.contains("download")) {
                    links.append(href)
                }
            }
        }
        
        return Array(Set(links)) // Unique
    }

    // MARK: - Episodes (Series)
    func getEpisodes(url: String) async throws -> [Episode] {
        let fullUrl = url.starts(with: "http") ? url : baseURL + url
        
        var headers = HTTPHeaders()
        headers.add(name: "User-Agent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        
        let response = try await client.get(URI(string: fullUrl), headers: headers)
        guard let body = response.body else { return [] }
        let html = String(buffer: body)
        let doc = try SwiftSoup.parse(html)
        
        var episodes: [Episode] = []
        var oneFichierFound = false
        
        let boldTags = try doc.select("b")
        for bold in boldTags {
            let text = try bold.text().lowercased()
            if text.contains("1fichier") {
                oneFichierFound = true
                
                // Iterate siblings
                var next = try bold.parent()?.nextElementSibling()
                if next == nil { next = try bold.nextElementSibling() }
                
                while let current = next {
                    // Stop if we hit another host header (usually <b>)
                    if try current.tagName() == "b" || !current.select("b").isEmpty() {
                        let nextText = try current.text().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        // Heuristic: Hosts are short, Episodes contain "Episode"
                        if !nextText.contains("Episode") && !nextText.starts(with: "E") { // Simple check, regex is harder in SwiftSoup iteration
                            // Check if it matches E\d+ regex equivalent
                             if nextText.range(of: "^E\\d+", options: .regularExpression) == nil {
                                break
                            }
                        }
                    }
                    
                    // Check for links
                    let links = try current.select("a")
                    // If current is 'a', add it too
                    if try current.tagName() == "a" {
                        links.add(current)
                    }
                    
                    for link in links {
                        let linkText = try link.text().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        let href = try link.attr("href")
                        
                        if (href.contains("dl-protect") || href.contains("1fichier")) {
                            if linkText.range(of: "Episode\\s+\\d+", options: [.regularExpression, .caseInsensitive]) != nil ||
                               linkText.range(of: "^E\\d+", options: [.regularExpression, .caseInsensitive]) != nil {
                                episodes.append(Episode(episode: linkText, link: href))
                            }
                        }
                    }
                    
                    next = try current.nextElementSibling()
                }
            }
        }
        
        // Fallback
        if episodes.isEmpty {
            let allLinks = try doc.select("a")
            for link in allLinks {
                let text = try link.text().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                let href = try link.attr("href")
                
                if (href.contains("dl-protect") || href.contains("1fichier")) {
                     if text.range(of: "Episode\\s+\\d+", options: [.regularExpression, .caseInsensitive]) != nil ||
                        text.range(of: "^E\\d+", options: [.regularExpression, .caseInsensitive]) != nil {
                        episodes.append(Episode(episode: text, link: href))
                    }
                }
            }
        }
        
        return episodes
    }
    // MARK: - 1fichier
    struct OneFichierResponse: Decodable {
        var url: String?
        var link: String?
        var status: String?
        var message: String?
    }

    func getDownloadLink(url: String, on db: Database) async throws -> String {
        // Try env first
        var key = Environment.get("ONEFICHIER_API_KEY")
        
        // If not in env, try DB
        if key == nil {
            if let settings = try? await Setting.query(on: db).first() {
                key = settings.onefichierApiKey
            }
        }
        
        guard let rawKey = key, !rawKey.isEmpty else {
            throw Abort(.internalServerError, reason: "ONEFICHIER_API_KEY not set in env or DB")
        }
        let finalKey = rawKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let cleanUrl = url.components(separatedBy: "&")[0]
        
        // Use curl via Process for 1fichier API (Force IPv4)
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            process.arguments = [
                "-4", // Force IPv4
                "-s",
                "-X", "POST",
                "https://api.1fichier.com/v1/download/get_token.cgi",
                "-H", "Content-Type: application/json",
                "-H", "Authorization: Bearer \(finalKey)",
                "-d", "{\"url\": \"\(cleanUrl)\"}"
            ]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            // Do not capture stderr
            
            do {
                try process.run()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    do {
                        let result = try JSONDecoder().decode(OneFichierResponse.self, from: data)
                        if let link = result.url ?? result.link {
                            continuation.resume(returning: link)
                        } else {
                            continuation.resume(throwing: Abort(.badRequest, reason: "No download link: \(result.message ?? "Unknown")"))
                        }
                    } catch {
                         print("[DEBUG] Curl Output: \(String(data: data, encoding: .utf8) ?? "nil")")
                         continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: Abort(.internalServerError, reason: "Curl failed with status \(process.terminationStatus)"))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

struct ZTMovieData {
    let title: String
    let url: String
    let image: String
    let quality: String
    let language: String
    
    func toSearchResult(type: String, baseURL: String) -> ZTScraper.SearchResult {
        return ZTScraper.SearchResult(
            id: url.replacingOccurrences(of: baseURL, with: ""),
            title: title,
            type: type,
            quality: quality,
            language: language,
            poster: image,
            links: [url]
        )
    }
}
