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
struct DynDNSHandler: Sendable
{
    let cgiEnv: CGIEnvironment

    /// Process the DynDNS update request
    func handleRequest() async -> CGIResponse
    {
        guard let auth = cgiEnv.getBasicAuth()
        else
        {
            return CGIResponse(status: .unauthorized,
                               body: "badauth - Missing or invalid Basic Authentication header")
        }

        let zoneIdentifier = auth.username
        let apiToken = auth.password
        let params = cgiEnv.parseQueryParameters()

        guard let rawHostname = params["hostname"] ?? params["host"] ?? params["domain"],
              !rawHostname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else
        {
            return CGIResponse(status: .badRequest,
                               body: "notfqdn - Missing hostname parameter (use: hostname, host, or domain)")
        }

        let ipAddress = params["myip"] ?? params["ip"] ?? cgiEnv.remoteAddr

        guard !ipAddress.isEmpty
        else
        {
            return CGIResponse(status: .badRequest,
                               body: "dnserr - No IP address provided (myip parameter missing and REMOTE_ADDR not available)")
        }

        guard isValidIP(ipAddress)
        else
        {
            return CGIResponse(status: .badRequest,
                               body: "dnserr - Invalid IP address format: '\(ipAddress)'")
        }

        let apiClient = HetznerAPIClient(apiToken: apiToken)
        let recordType = ipAddress.contains(":") ? "AAAA" : "A"

        let response: CGIResponse
        do
        {
            trace("getZone start zone=\(zoneIdentifier)")
            let zone = try await apiClient.getZone(idOrName: zoneIdentifier)
            trace("getZone ok zoneName=\(zone.name)")
            let rrsetName = Self.resolveRRSetName(hostname: rawHostname, zoneName: zone.name)

            guard !rrsetName.isEmpty
            else
            {
                response = CGIResponse(status: .badRequest,
                                       body: "notfqdn - Invalid hostname: '\(rawHostname)'")
                return response
            }

            let rrset = try await apiClient.getRRSet(zoneIdOrName: zoneIdentifier,
                                                     name: rrsetName,
                                                     type: recordType)
            trace("getRRSet complete name=\(rrsetName) type=\(recordType) found=\(rrset != nil)")

            if let rrset
            {
                if rrset.records.count == 1, rrset.records[0].value == ipAddress
                {
                    trace("rrset unchanged value=\(ipAddress)")
                    response = CGIResponse(status: .ok,
                                           body: "nochg \(ipAddress)")
                }
                else
                {
                    let preservedComment = rrset.records.first?.comment
                    let desiredRecords = [DNSRRSetRecord(value: ipAddress,
                                                         comment: preservedComment)]

                    trace("setRRSetRecords start target=\(ipAddress)")
                    try await apiClient.setRRSetRecords(zoneIdOrName: zoneIdentifier,
                                                       name: rrsetName,
                                                       type: recordType,
                                                       records: desiredRecords)
                    trace("setRRSetRecords ok target=\(ipAddress)")

                    response = CGIResponse(status: .ok,
                                           body: "good \(ipAddress)")
                }
            }
            else
            {
                response = CGIResponse(status: .notFound,
                                       body: "nohost - \(rawHostname) (\(recordType)) not found in zone \(zone.name)")
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
                        response = CGIResponse(status: .unauthorized,
                                               body: "badauth - API authentication failed (HTTP \(statusCode))")
                    }
                    else if statusCode == 404
                    {
                        response = CGIResponse(status: .notFound,
                                               body: "nohost - Zone or record not found (HTTP \(statusCode))")
                    }
                    else
                    {
                        let detailSuffix = message.map { ": \($0)" } ?? ""
                        response = CGIResponse(status: .internalServerError,
                                               body: "911 - Hetzner API error (HTTP \(statusCode)\(detailSuffix))")
                    }
                case .recordNotFound:
                    response = CGIResponse(status: .notFound,
                                           body: "nohost - DNS record not found in zone")
                case let .transportError(message):
                    response = CGIResponse(status: .internalServerError,
                                           body: "911 - Transport error: \(message)")
                case .invalidResponse:
                    response = CGIResponse(status: .internalServerError,
                                           body: "911 - Invalid API response format")
            }
        }
        catch
        {
            trace("generic error \(error.localizedDescription)")
            response = CGIResponse(status: .internalServerError,
                                   body: "911 - Error: \(error.localizedDescription)")
        }

        return response
    }

    static func resolveRRSetName(hostname: String, zoneName: String) -> String
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

    static func normalizeDNSName(_ value: String) -> String
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

struct CGIResponse: Sendable
{
    enum Status: Sendable, Equatable
    {
        case ok
        case badRequest
        case unauthorized
        case notFound
        case internalServerError

        var code: Int
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

        var message: String
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

    let status: Status
    let body: String

    func write()
    {
        let emittedStatus: Status = status == .internalServerError ? .ok : status
        print("Status: \(emittedStatus.code) \(emittedStatus.message)")
        print("Content-Type: text/plain")
        print("Cache-Control: no-cache")
        if emittedStatus != status
        {
            print("X-DynDNS-Status: \(status.code)")
        }
        print("")
        print(body)
    }
}
