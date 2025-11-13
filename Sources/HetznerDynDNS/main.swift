//
//  main.swift
//

import Foundation

let cgiEnv = CGIEnvironment()
let handler = DynDNSHandler(cgiEnv: cgiEnv)

let response = await handler.handleRequest()
response.write()
