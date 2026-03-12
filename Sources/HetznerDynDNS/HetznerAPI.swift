//
//  HetznerAPI.swift
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@inline(__always)
private func trace(_ message: String)
{
    guard ProcessInfo.processInfo.environment["DYNDNS_TRACE"] == "1" else { return }
    guard let data = "[dyndns] \(message)\n".data(using: .utf8) else { return }
    try? FileHandle.standardError.write(contentsOf: data)
}

/// Hetzner Console DNS API client
actor HetznerAPIClient
{
    private let apiToken: String
    private let baseURL: String

    init(apiToken: String)
    {
        self.apiToken = apiToken
        self.baseURL = ProcessInfo.processInfo.environment["HETZNER_API_BASE_URL"]
            ?? "https://api.hetzner.cloud/v1"
    }

    func getZone(idOrName: String) async throws -> DNSZone
    {
        try await send("GET",
                       path: ["zones", idOrName],
                       responseType: ZoneResponse.self).zone
    }

    func getRRSet(zoneIdOrName: String, name: String, type: String) async throws -> DNSRRSet?
    {
        let path = ["zones", zoneIdOrName, "rrsets", name, type]

        do
        {
            return try await send("GET",
                                  path: path,
                                  responseType: RRSetResponse.self).rrset
        }
        catch let error as HetznerAPIError
        {
            if case .httpError(404, _) = error
            {
                return nil
            }

            throw error
        }
    }

    func createRRSet(zoneIdOrName: String,
                     name: String,
                     type: String,
                     value: String,
                     ttl: Int = 60,
                     comment: String?) async throws
    {
        let requestBody = try Self.makeCreateRRSetBody(name: name,
                                                       type: type,
                                                       ttl: ttl,
                                                       records: [DNSRRSetRecord(value: value,
                                                                                comment: comment)])

        _ = try await send("POST",
                           path: ["zones", zoneIdOrName, "rrsets"],
                           body: requestBody,
                           responseType: ActionResponse.self)
    }

    func setRRSetRecords(zoneIdOrName: String,
                         name: String,
                         type: String,
                         records: [DNSRRSetRecord]) async throws
    {
        let requestBody = try Self.makeRRSetRecordsBody(records: records)

        _ = try await send("POST",
                           path: ["zones", zoneIdOrName, "rrsets", name, type, "actions", "set_records"],
                           body: requestBody,
                           responseType: ActionResponse.self)
    }

    private func send<ResponseType: Decodable>(_ method: String,
                                               path: [String],
                                               responseType: ResponseType.Type) async throws -> ResponseType
    {
        try await send(method,
                       path: path,
                       body: Optional<Data>.none,
                       responseType: responseType)
    }

    private func send<ResponseType: Decodable>(_ method: String,
                                               path: [String],
                                               body: Data?,
                                               responseType: ResponseType.Type) async throws -> ResponseType
    {
        let response = try await execute(method: method,
                                         path: path,
                                         body: body)

        guard (200 ... 299).contains(response.statusCode)
        else
        {
            let apiMessage = decodeErrorMessage(from: response.bodyData)
            throw HetznerAPIError.httpError(statusCode: response.statusCode,
                                            message: apiMessage)
        }

        do
        {
            return try JSONDecoder().decode(ResponseType.self, from: response.bodyData)
        }
        catch
        {
            throw HetznerAPIError.invalidResponse
        }
    }

    private func execute(method: String,
                         path: [String],
                         body: Data?) async throws -> HTTPResponse
    {
        let url = buildURL(path: path)
        trace("http execute start method=\(method) url=\(url) bodyBytes=\(body?.count ?? 0)")

        guard let requestURL = URL(string: url)
        else
        {
            throw HetznerAPIError.transportError(message: "Invalid API URL: \(url)")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("hetzner-dyndns-cgi/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        if let body
        {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        }

        do
        {
            let session = URLSession(configuration: .ephemeral)
            let (responseData, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse
            else
            {
                throw HetznerAPIError.invalidResponse
            }

            trace("http execute headers method=\(method) url=\(url) status=\(httpResponse.statusCode)")
            trace("http execute body method=\(method) url=\(url) bodyRead=\(responseData.count)")
            return HTTPResponse(statusCode: httpResponse.statusCode,
                                bodyData: responseData)
        }
        catch
        {
            trace("http execute error method=\(method) url=\(url) message=\(error.localizedDescription)")
            throw HetznerAPIError.transportError(message: error.localizedDescription)
        }
    }

    private func buildURL(path: [String]) -> String
    {
        let encodedPath = path.map(Self.encodePathComponent).joined(separator: "/")
        return "\(baseURL)/\(encodedPath)"
    }

    private static func encodePathComponent(_ value: String) -> String
    {
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove(charactersIn: "/")
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
    }

    private static func makeCreateRRSetBody(name: String,
                                            type: String,
                                            ttl: Int,
                                            records: [DNSRRSetRecord]) throws -> Data
    {
        try JSONSerialization.data(withJSONObject: [
            "name": name,
            "type": type,
            "ttl": ttl,
            "records": makeRecordObjects(records),
        ])
    }

    private static func makeRRSetRecordsBody(records: [DNSRRSetRecord]) throws -> Data
    {
        try JSONSerialization.data(withJSONObject: [
            "records": makeRecordObjects(records),
        ])
    }

    private static func makeRecordObjects(_ records: [DNSRRSetRecord]) -> [[String: Any]]
    {
        records.map
        { record in
            var object: [String: Any] = [
                "value": record.value,
            ]

            if let comment = record.comment
            {
                object["comment"] = comment
            }

            return object
        }
    }

    private func decodeErrorMessage(from bodyData: Data) -> String?
    {
        if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: bodyData)
        {
            let messageParts = [envelope.error.code, envelope.error.message]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if !messageParts.isEmpty
            {
                return messageParts.joined(separator: ": ")
            }
        }

        if let plainText = String(data: bodyData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !plainText.isEmpty
        {
            return plainText
        }

        return nil
    }
}

// MARK: - Models

struct DNSZone: Codable, Sendable
{
    let id: Int64
    let name: String
}

struct ZoneResponse: Codable, Sendable
{
    let zone: DNSZone
}

struct DNSRRSet: Codable, Sendable
{
    let id: String
    let name: String
    let type: String
    let ttl: Int?
    let records: [DNSRRSetRecord]
}

struct DNSRRSetRecord: Codable, Sendable, Equatable
{
    let value: String
    let comment: String?
}

struct RRSetResponse: Codable, Sendable
{
    let rrset: DNSRRSet
}

struct RRSetCreateRequest: Codable, Sendable
{
    let name: String
    let type: String
    let ttl: Int
    let records: [DNSRRSetRecord]
}

struct RRSetRecordsRequest: Codable, Sendable
{
    let records: [DNSRRSetRecord]
}

struct ActionResponse: Codable, Sendable
{
    let action: APIAction
}

struct APIAction: Codable, Sendable
{
    let id: Int64
}

enum HetznerAPIError: Error, Sendable
{
    case httpError(statusCode: Int, message: String?)
    case transportError(message: String)
    case invalidResponse
    case recordNotFound
}

private struct HTTPResponse
{
    let statusCode: Int
    let bodyData: Data
}

private struct APIErrorEnvelope: Decodable, Sendable
{
    let error: APIErrorDetail
}

private struct APIErrorDetail: Decodable, Sendable
{
    let code: String?
    let message: String?
}
