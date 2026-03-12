import Foundation
import HetznerDynDNS

enum CGIRequestBuildResult
{
    case success(DynDNSRequest)
    case failure(DynDNSResponse)
}

/// Handles CGI environment variables and request parsing.
struct CGIEnvironment: Sendable
{
    let queryString: String
    let remoteAddr: String
    private let environment: [String: String]

    init(environment: [String: String] = ProcessInfo.processInfo.environment)
    {
        self.environment = environment
        queryString = environment["QUERY_STRING"] ?? ""
        remoteAddr = environment["REMOTE_ADDR"] ?? ""
    }

    func makeRequest() -> CGIRequestBuildResult
    {
        guard let auth = getBasicAuth()
        else
        {
            return .failure(DynDNSResponse(status: .unauthorized,
                                           body: "badauth - Missing or invalid Basic Authentication header"))
        }

        let params = parseQueryParameters()
        guard let rawHostname = params["hostname"] ?? params["host"] ?? params["domain"],
              !rawHostname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else
        {
            return .failure(DynDNSResponse(status: .badRequest,
                                           body: "notfqdn - Missing hostname parameter (use: hostname, host, or domain)"))
        }

        let ipAddress = params["myip"] ?? params["ip"] ?? remoteAddr
        return .success(DynDNSRequest(zoneIdentifier: auth.username,
                                      apiToken: auth.password,
                                      hostname: rawHostname,
                                      ipAddress: ipAddress))
    }

    private func parseQueryParameters() -> [String: String]
    {
        var params: [String: String] = [:]

        let pairs = queryString.split(separator: "&")
        for pair in pairs
        {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2
            {
                let key = String(keyValue[0])
                let value = String(keyValue[1])
                    .replacingOccurrences(of: "+", with: " ")
                    .removingPercentEncoding ?? String(keyValue[1])
                params[key] = value
            }
        }

        return params
    }

    private func getBasicAuth() -> (username: String, password: String)?
    {
        let possibleAuthVars = [
            "HTTP_AUTHORIZATION",
            "REDIRECT_HTTP_AUTHORIZATION",
            "Authorization",
            "REDIRECT_Authorization",
        ]

        var authHeader: String?
        for varName in possibleAuthVars
        {
            if let value = environment[varName]
            {
                authHeader = value
                break
            }
        }

        guard let authHeader
        else
        {
            return nil
        }

        let components = authHeader.split(separator: " ", maxSplits: 1)
        guard components.count == 2,
              components[0].lowercased() == "basic",
              let decoded = Data(base64Encoded: String(components[1])),
              let credentials = String(data: decoded, encoding: .utf8)
        else
        {
            return nil
        }

        let parts = credentials.split(separator: ":", maxSplits: 1)
        guard parts.count == 2
        else
        {
            return nil
        }

        return (username: String(parts[0]), password: String(parts[1]))
    }
}
