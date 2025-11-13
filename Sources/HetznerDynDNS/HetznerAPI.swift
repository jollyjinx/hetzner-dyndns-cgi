import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1

/// Hetzner DNS API client
actor HetznerAPIClient {
    private let apiToken: String
    private let httpClient: HTTPClient
    private let baseURL = "https://dns.hetzner.com/api/v1"
    
    init(apiToken: String, httpClient: HTTPClient) {
        self.apiToken = apiToken
        self.httpClient = httpClient
    }
    
    /// Get all DNS records for a zone
    func getRecords(zoneId: String) async throws -> [DNSRecord] {
        let url = "\(baseURL)/records?zone_id=\(zoneId)"
        
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Auth-API-Token", value: apiToken)
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        
        guard response.status == .ok else {
            throw HetznerAPIError.httpError(statusCode: Int(response.status.code))
        }
        
        let body = try await response.body.collect(upTo: 1024 * 1024) // 1MB max
        let data = Data(body.readableBytesView)
        
        let decoder = JSONDecoder()
        let recordsResponse = try decoder.decode(RecordsResponse.self, from: data)
        return recordsResponse.records
    }
    
    /// Update a DNS record
    func updateRecord(recordId: String, name: String, type: String, value: String, ttl: Int = 60, zoneId: String) async throws {
        let url = "\(baseURL)/records/\(recordId)"
        
        let updateData = RecordUpdate(
            name: name,
            type: type,
            value: value,
            ttl: ttl,
            zone_id: zoneId
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(updateData)
        
        var request = HTTPClientRequest(url: url)
        request.method = .PUT
        request.headers.add(name: "Auth-API-Token", value: apiToken)
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(ByteBuffer(bytes: jsonData))
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        
        guard response.status == .ok else {
            throw HetznerAPIError.httpError(statusCode: Int(response.status.code))
        }
    }
}

// MARK: - Models

struct DNSRecord: Codable, Sendable {
    let id: String
    let type: String
    let name: String
    let value: String
    let zone_id: String
    let ttl: Int?
}

struct RecordsResponse: Codable, Sendable {
    let records: [DNSRecord]
}

struct RecordUpdate: Codable, Sendable {
    let name: String
    let type: String
    let value: String
    let ttl: Int
    let zone_id: String
}

enum HetznerAPIError: Error, Sendable {
    case httpError(statusCode: Int)
    case invalidResponse
    case recordNotFound
}

