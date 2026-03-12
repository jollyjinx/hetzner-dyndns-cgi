import HetznerDynDNS

extension DynDNSResponse
{
    func writeAsCGI()
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
