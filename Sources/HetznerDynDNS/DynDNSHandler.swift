//
//  DynDNSHandler.swift
//

import Foundation

@inline(__always)
private func trace(_ message: String)
{
    guard ProcessInfo.processInfo.environment["DYNDNS_TRACE"] == "1" else { return }
    guard let data = "[dyndns] \(message)\n".data(using: .utf8) else { return }
    try? FileHandle.standardError.write(contentsOf: data)
}

/// Handles DynDNS update requests
public struct DynDNSRequest: Sendable, Equatable
{
    public let zoneIdentifier: String
    public let apiToken: String
    public let hostname: String
    public let ipAddress: String

    public init(zoneIdentifier: String,
                apiToken: String,
                hostname: String,
                ipAddress: String)
    {
        self.zoneIdentifier = zoneIdentifier
        self.apiToken = apiToken
        self.hostname = hostname
        self.ipAddress = ipAddress
    }
}

/// Handles DynDNS update requests
public struct DynDNSHandler: Sendable
{
    private let apiClientFactory: @Sendable (String) -> HetznerAPIClient

    public init()
    {
        apiClientFactory = { apiToken in
            HetznerAPIClient(apiToken: apiToken)
        }
    }

    init(apiClientFactory: @escaping @Sendable (String) -> HetznerAPIClient)
    {
        self.apiClientFactory = apiClientFactory
    }

    /// Process the DynDNS update request
    public func handle(_ request: DynDNSRequest) async -> DynDNSResponse
    {
        let ipAddress = request.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ipAddress.isEmpty
        else
        {
            return DynDNSResponse(status: .badRequest,
                               body: "dnserr - No IP address provided (myip parameter missing and REMOTE_ADDR not available)")
        }

        guard isValidIP(ipAddress)
        else
        {
            return DynDNSResponse(status: .badRequest,
                               body: "dnserr - Invalid IP address format: '\(ipAddress)'")
        }

        let apiClient = apiClientFactory(request.apiToken)
        let recordType = ipAddress.contains(":") ? "AAAA" : "A"

        let response: DynDNSResponse
        do
        {
            trace("getZone start zone=\(request.zoneIdentifier)")
            let zone = try await apiClient.getZone(idOrName: request.zoneIdentifier)
            trace("getZone ok zoneName=\(zone.name)")
            let rrsetName = Self.resolveRRSetName(hostname: request.hostname, zoneName: zone.name)

            guard !rrsetName.isEmpty
            else
            {
                response = DynDNSResponse(status: .badRequest,
                                          body: "notfqdn - Invalid hostname: '\(request.hostname)'")
                return response
            }

            let rrset = try await apiClient.getRRSet(zoneIdOrName: request.zoneIdentifier,
                                                     name: rrsetName,
                                                     type: recordType)
            trace("getRRSet complete name=\(rrsetName) type=\(recordType) found=\(rrset != nil)")

            if let rrset
            {
                if rrset.records.count == 1, rrset.records[0].value == ipAddress
                {
                    trace("rrset unchanged value=\(ipAddress)")
                    response = DynDNSResponse(status: .ok,
                                              body: "nochg \(ipAddress)")
                }
                else
                {
                    let preservedComment = rrset.records.first?.comment
                    let desiredRecords = [DNSRRSetRecord(value: ipAddress,
                                                         comment: preservedComment)]

                    trace("setRRSetRecords start target=\(ipAddress)")
                    try await apiClient.setRRSetRecords(zoneIdOrName: request.zoneIdentifier,
                                                       name: rrsetName,
                                                       type: recordType,
                                                       records: desiredRecords)
                    trace("setRRSetRecords ok target=\(ipAddress)")

                    response = DynDNSResponse(status: .ok,
                                              body: "good \(ipAddress)")
                }
            }
            else
            {
                response = DynDNSResponse(status: .notFound,
                                          body: "nohost - \(request.hostname) (\(recordType)) not found in zone \(zone.name)")
            }
        }
        catch let error as HetznerAPIError
        {
            trace("HetznerAPIError \(String(describing: error))")
            switch error
            {
                case let .httpError(statusCode, message):
                    if statusCode == 401 || statusCode == 403
                    {
                        response = DynDNSResponse(status: .unauthorized,
                                                  body: "badauth - API authentication failed (HTTP \(statusCode))")
                    }
                    else if statusCode == 404
                    {
                        response = DynDNSResponse(status: .notFound,
                                                  body: "nohost - Zone or record not found (HTTP \(statusCode))")
                    }
                    else
                    {
                        let detailSuffix = message.map { ": \($0)" } ?? ""
                        response = DynDNSResponse(status: .internalServerError,
                                                  body: "911 - Hetzner API error (HTTP \(statusCode)\(detailSuffix))")
                    }
                case .recordNotFound:
                    response = DynDNSResponse(status: .notFound,
                                              body: "nohost - DNS record not found in zone")
                case let .transportError(message):
                    response = DynDNSResponse(status: .internalServerError,
                                              body: "911 - Transport error: \(message)")
                case .invalidResponse:
                    response = DynDNSResponse(status: .internalServerError,
                                              body: "911 - Invalid API response format")
            }
        }
        catch
        {
            trace("generic error \(error.localizedDescription)")
            response = DynDNSResponse(status: .internalServerError,
                                      body: "911 - Error: \(error.localizedDescription)")
        }

        return response
    }

    public static func resolveRRSetName(hostname: String, zoneName: String) -> String
    {
        let normalizedHostname = normalizeDNSName(hostname)
        let normalizedZone = normalizeDNSName(zoneName)

        guard !normalizedHostname.isEmpty
        else
        {
            return ""
        }

        if normalizedHostname == "@"
        {
            return "@"
        }

        let lowercaseHostname = normalizedHostname.lowercased()
        let lowercaseZone = normalizedZone.lowercased()

        if !lowercaseZone.isEmpty
        {
            if lowercaseHostname == lowercaseZone
            {
                return "@"
            }

            let zoneSuffix = ".\(lowercaseZone)"
            if lowercaseHostname.hasSuffix(zoneSuffix)
            {
                let relativeLength = normalizedHostname.count - zoneSuffix.count
                let relativeName = String(normalizedHostname.prefix(relativeLength))
                return relativeName.isEmpty ? "@" : relativeName
            }
        }

        return normalizedHostname
    }

    public static func normalizeDNSName(_ value: String) -> String
    {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    /// Validate IP address format
    private func isValidIP(_ ip: String) -> Bool
    {
        if ip.contains(":")
        {
            return ip.split(separator: ":").count >= 3
        }
        else
        {
            let octets = ip.split(separator: ".")
            guard octets.count == 4 else { return false }
            return octets.allSatisfy
            { octet in
                guard let num = Int(octet) else { return false }
                return num >= 0 && num <= 255
            }
        }
    }
}

// MARK: - CGI Response

public struct DynDNSResponse: Sendable, Equatable
{
    public enum Status: Sendable, Equatable
    {
        case ok
        case badRequest
        case unauthorized
        case notFound
        case internalServerError

        public var code: Int
        {
            switch self
            {
                case .ok: return 200
                case .badRequest: return 400
                case .unauthorized: return 401
                case .notFound: return 404
                case .internalServerError: return 500
            }
        }

        public var message: String
        {
            switch self
            {
                case .ok: return "OK"
                case .badRequest: return "Bad Request"
                case .unauthorized: return "Unauthorized"
                case .notFound: return "Not Found"
                case .internalServerError: return "Internal Server Error"
            }
        }
    }

    public let status: Status
    public let body: String

    public init(status: Status, body: String)
    {
        self.status = status
        self.body = body
    }
}
