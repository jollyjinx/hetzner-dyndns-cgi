import HetznerDynDNS

let cgiEnvironment = CGIEnvironment()
let handler = DynDNSHandler()

let response: DynDNSResponse
switch cgiEnvironment.makeRequest()
{
    case let .success(request):
        response = await handler.handle(request)
    case let .failure(errorResponse):
        response = errorResponse
}

response.writeAsCGI()
