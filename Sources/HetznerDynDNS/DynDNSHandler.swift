import Foundation
import AsyncHTTPClient

/// Handles DynDNS update requests
struct DynDNSHandler: Sendable {
    let cgiEnv: CGIEnvironment
    
    /// Process the DynDNS update request
    func handleRequest() async -> CGIResponse {
        // Extract authentication (zoneId as username, API token as password)
        guard let auth = cgiEnv.getBasicAuth() else {
            return CGIResponse(
                status: .unauthorized,
                body: "badauth"
            )
        }
        
        let zoneId = auth.username
        let apiToken = auth.password
        
        // Parse query parameters
        let params = cgiEnv.parseQueryParameters()
        
        // Get hostname to update (common DynDNS parameter names)
        guard let hostname = params["hostname"] ?? params["host"] ?? params["domain"] else {
            return CGIResponse(
                status: .badRequest,
                body: "notfqdn"
            )
        }
        
        // Get IP address (myip parameter or use remote address)
        let ipAddress = params["myip"] ?? params["ip"] ?? cgiEnv.remoteAddr
        
        // Validate IP address
        guard !ipAddress.isEmpty, isValidIP(ipAddress) else {
            return CGIResponse(
                status: .badRequest,
                body: "dnserr"
            )
        }
        
        // Update DNS record
        do {
            let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
            
            let apiClient = HetznerAPIClient(apiToken: apiToken, httpClient: httpClient)
            
            // Get all records for the zone
            let records = try await apiClient.getRecords(zoneId: zoneId)
            
            // Determine record type based on IP version
            let recordType = ipAddress.contains(":") ? "AAAA" : "A"
            
            // Find the record to update
            guard let record = records.first(where: { 
                $0.name == hostname && $0.type == recordType 
            }) else {
                return CGIResponse(
                    status: .notFound,
                    body: "nohost"
                )
            }
            
            // Check if update is needed
            if record.value == ipAddress {
                return CGIResponse(
                    status: .ok,
                    body: "nochg \(ipAddress)"
                )
            }
            
            // Update the record
            try await apiClient.updateRecord(
                recordId: record.id,
                name: hostname,
                type: recordType,
                value: ipAddress,
                ttl: 60,
                zoneId: zoneId
            )
            
            // Cleanup HTTP client
            try? await httpClient.shutdown()
            
            return CGIResponse(
                status: .ok,
                body: "good \(ipAddress)"
            )
            
        } catch {
            return CGIResponse(
                status: .internalServerError,
                body: "911"
            )
        }
    }
    
    /// Validate IP address format
    private func isValidIP(_ ip: String) -> Bool {
        // Simple validation for IPv4 and IPv6
        if ip.contains(":") {
            // IPv6 - basic check
            return ip.split(separator: ":").count >= 3
        } else {
            // IPv4
            let octets = ip.split(separator: ".")
            guard octets.count == 4 else { return false }
            return octets.allSatisfy { octet in
                guard let num = Int(octet) else { return false }
                return num >= 0 && num <= 255
            }
        }
    }
}

// MARK: - CGI Response

struct CGIResponse: Sendable {
    enum Status: Sendable {
        case ok
        case badRequest
        case unauthorized
        case notFound
        case internalServerError
        
        var code: Int {
            switch self {
            case .ok: return 200
            case .badRequest: return 400
            case .unauthorized: return 401
            case .notFound: return 404
            case .internalServerError: return 500
            }
        }
        
        var message: String {
            switch self {
            case .ok: return "OK"
            case .badRequest: return "Bad Request"
            case .unauthorized: return "Unauthorized"
            case .notFound: return "Not Found"
            case .internalServerError: return "Internal Server Error"
            }
        }
    }
    
    let status: Status
    let body: String
    
    func write() {
        print("Status: \(status.code) \(status.message)")
        print("Content-Type: text/plain")
        print("Cache-Control: no-cache")
        print("")
        print(body)
    }
}

