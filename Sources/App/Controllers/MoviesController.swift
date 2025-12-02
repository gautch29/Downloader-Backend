import Vapor

struct MoviesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let movies = routes.grouped("api", "movies")
        movies.get("search", use: search)
        movies.post("links", use: getLinks)
        movies.post("episodes") { req async throws -> EpisodesResponse in
            return try await self.getEpisodes(req: req)
        }
    }

    struct SearchResponse: Content {
        var movies: [ZTScraper.SearchResult]
        var total: Int
    }

    func search(req: Request) async throws -> SearchResponse {
        guard let query = req.query[String.self, at: "q"] else {
            throw Abort(.badRequest, reason: "Missing query parameter")
        }
        
        let scraper = ZTScraper(client: req.client)
        let results = try await scraper.search(query: query)
        
        return SearchResponse(movies: results, total: results.count)
    }

    struct LinksRequest: Content {
        var url: String
    }
    
    struct LinksResponse: Content {
        var links: [String]
    }

    func getLinks(req: Request) async throws -> LinksResponse {
        let linksReq = try req.content.decode(LinksRequest.self)
        let scraper = ZTScraper(client: req.client)
        let links = try await scraper.getLinks(url: linksReq.url)
        
        return LinksResponse(links: links)
    }

    struct EpisodesResponse: Content {
        var episodes: [ZTScraper.Episode]
    }

    func getEpisodes(req: Request) async throws -> EpisodesResponse {
        let linksReq = try req.content.decode(LinksRequest.self)
        let scraper = ZTScraper(client: req.client)
        let episodes = try await scraper.getEpisodes(url: linksReq.url)
        
        return EpisodesResponse(episodes: episodes)
    }
}
