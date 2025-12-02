import Foundation

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

struct NetworkUtils {
    static func resolveIPv4(host: String) -> String? {
        var hints = addrinfo()
        memset(&hints, 0, MemoryLayout<addrinfo>.size)
        hints.ai_family = AF_INET
        #if canImport(Glibc)
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #else
        hints.ai_socktype = SOCK_STREAM
        #endif
        
        var res: UnsafeMutablePointer<addrinfo>?
        
        let status = getaddrinfo(host, nil, &hints, &res)
        guard status == 0, let result = res else {
            return nil
        }
        
        defer {
            freeaddrinfo(res)
        }
        
        var addr = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        
        let conversionStatus = getnameinfo(
            result.pointee.ai_addr,
            result.pointee.ai_addrlen,
            &addr,
            socklen_t(addr.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        
        guard conversionStatus == 0 else {
            return nil
        }
        
        return String(cString: addr)
    }
    
    static func getIPv4URL(from urlString: String) -> (url: String, host: String)? {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        
        // If host is already an IP, return as is
        if host.range(of: "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", options: .regularExpression) != nil {
            return (urlString, host)
        }
        
        guard let ip = resolveIPv4(host: host) else {
            return nil
        }
        
        let newUrlString = urlString.replacingOccurrences(of: "://\(host)", with: "://\(ip)")
        return (newUrlString, host)
    }
}
