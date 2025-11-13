import Foundation

/// Handles CGI environment variables and request parsing
struct CGIEnvironment: Sendable {
    let queryString: String
    let requestMethod: String
    let remoteAddr: String
    
    init() {
        self.queryString = ProcessInfo.processInfo.environment["QUERY_STRING"] ?? ""
        self.requestMethod = ProcessInfo.processInfo.environment["REQUEST_METHOD"] ?? "GET"
        self.remoteAddr = ProcessInfo.processInfo.environment["REMOTE_ADDR"] ?? ""
    }
    
    /// Parse query parameters from QUERY_STRING
    func parseQueryParameters() -> [String: String] {
        var params: [String: String] = [:]
        
        let pairs = queryString.split(separator: "&")
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0])
                let value = String(keyValue[1])
                    .replacingOccurrences(of: "+", with: " ")
                    .removingPercentEncoding ?? String(keyValue[1])
                params[key] = value
            }
        }
        
        return params
    }
    
    /// Extract Basic Auth credentials from environment
    func getBasicAuth() -> (username: String, password: String)? {
        guard let authHeader = ProcessInfo.processInfo.environment["HTTP_AUTHORIZATION"] else {
            return nil
        }
        
        // Format: "Basic base64(username:password)"
        let components = authHeader.split(separator: " ", maxSplits: 1)
        guard components.count == 2,
              components[0].lowercased() == "basic",
              let decoded = Data(base64Encoded: String(components[1])),
              let credentials = String(data: decoded, encoding: .utf8) else {
            return nil
        }
        
        let parts = credentials.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else {
            return nil
        }
        
        return (username: String(parts[0]), password: String(parts[1]))
    }
}

