//
//  HTTPClient.swift
//  SwiftFoundation
//
//  Created by Alsey Coleman Miller on 7/20/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//  Copyright © 2016 Shiroyagi Corporation. All rights reserved.
//

import CcURL
import Foundation

/// Loads HTTP requests
public struct HTTPClient {
    
    public struct Option {
        public var timeoutInterval: Int
        public var verbose: Bool
        public var followRedirect: Bool
        public var proxy: String?
        public init() {
            self.timeoutInterval = 30
            self.verbose = false
            self.followRedirect = true
            self.proxy = nil
        }
        public init(timeoutInterval: Int, varbose: Bool, followRedirect: Bool, proxy: String?) {
            self.timeoutInterval = timeoutInterval
            self.verbose = varbose
            self.followRedirect = followRedirect
            self.proxy = proxy
        }
    }
    
    public typealias Header = (String, String)
    public struct Response {
        public let statusCode: Int
        public let headers: [Header]
        public let body: Data
        public let effectiveURL: String
    }
    
    public static func sendRequest(method: String, url: String, headers: [Header] = [], body: [UInt8] = [], option: Option = Option()) throws -> Response {
        
        let curl = cURL()
        
        try curl.set(option: CURLOPT_VERBOSE, option.verbose)
        
        try curl.set(option: CURLOPT_URL, url)
        
        try curl.set(option: CURLOPT_TIMEOUT, cURL.Long(option.timeoutInterval))
        
        try curl.set(option: CURLOPT_FOLLOWLOCATION, option.followRedirect)
        
        if let proxy = option.proxy {
            try curl.set(option: CURLOPT_PROXY, proxy)
        }
        
        try curl.set(option: CURLOPT_USERAGENT, "curl/0.0.0")
        
        // append data
        if body.count > 0 {
            
            try curl.set(option: CURLOPT_POSTFIELDS, body)
            
            try curl.set(option: CURLOPT_POSTFIELDSIZE, body.count)
        }
        
        // set HTTP method
        switch method.uppercased() {
            
        case "HEAD":
            try curl.set(option:CURLOPT_NOBODY, true)
            try curl.set(option:CURLOPT_CUSTOMREQUEST, "HEAD")
            
        case "POST":
            try curl.set(option:CURLOPT_POST, true)
            
        case "GET": try curl.set(option:CURLOPT_HTTPGET, true)
            
        default:
            
            try curl.set(option:CURLOPT_CUSTOMREQUEST, method.uppercased())
        }
        
        // set headers
        if headers.count > 0 {
            
            var curlHeaders = [String]()
            
            for header in headers {
                
                curlHeaders.append(header.0 + ": " + header.1)
            }
            
            try curl.set(option:CURLOPT_HTTPHEADER, curlHeaders)
        }
        
        // set response data callback
        
        let responseBodyStorage = cURL.WriteFunctionStorage()
        
        try! curl.set(option:CURLOPT_WRITEDATA, Unmanaged.passUnretained(responseBodyStorage))
        
        try! curl.set(option:CURLOPT_WRITEFUNCTION, curlWriteFunction)
        
        let responseHeaderStorage = cURL.WriteFunctionStorage()
        
        try! curl.set(option:CURLOPT_HEADERDATA, Unmanaged.passUnretained(responseHeaderStorage))
        
        try! curl.set(option:CURLOPT_HEADERFUNCTION, curlWriteFunction)
        
        // connect to server
        try curl.perform()
        
        let responseCode = try curl.get(info: CURLINFO_RESPONSE_CODE) as Int
        
        responseHeaderStorage.data.append(Data([0]))
        let resHeaders = ResponseHeaderParser(responseHeaderStorage.data).parse()
        
        let resBody = responseBodyStorage.data
        
        let effectiveURLString = try curl.get(info: CURLINFO_EFFECTIVE_URL) as String

        return Response(statusCode: responseCode,
                        headers: resHeaders,
                        body: Data(referencing: resBody),
                        effectiveURL: effectiveURLString)
        
    }
}

// MARK: - Linux Support

#if LIBCURL_OLD
    
    public let CURLOPT_WRITEDATA = CURLOPT_FILE
    public let CURLOPT_HEADERDATA = CURLOPT_WRITEHEADER
    public let CURLOPT_READDATA = CURLOPT_INFILE
    public let CURLOPT_RTSPHEADER = CURLOPT_HTTPHEADER
    
#endif

