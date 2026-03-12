import Testing
@testable import HetznerDynDNS

struct DynDNSHandlerTests
{
    @Test
    func resolvesApexHostnameToAtRecord()
    {
        #expect(DynDNSHandler.resolveRRSetName(hostname: "example.com",
                                               zoneName: "example.com") == "@")
        #expect(DynDNSHandler.resolveRRSetName(hostname: "@",
                                               zoneName: "example.com") == "@")
    }

    @Test
    func resolvesFullyQualifiedHostnameToRelativeRRSetName()
    {
        #expect(DynDNSHandler.resolveRRSetName(hostname: "home.example.com",
                                               zoneName: "example.com") == "home")
        #expect(DynDNSHandler.resolveRRSetName(hostname: "vpn.gateway.example.com.",
                                               zoneName: "example.com") == "vpn.gateway")
    }

    @Test
    func keepsRelativeHostnamesUntouched()
    {
        #expect(DynDNSHandler.resolveRRSetName(hostname: "home",
                                               zoneName: "example.com") == "home")
        #expect(DynDNSHandler.resolveRRSetName(hostname: "vpn.gateway",
                                               zoneName: "example.com") == "vpn.gateway")
    }
}
