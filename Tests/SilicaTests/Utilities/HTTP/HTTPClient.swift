//
//  HTTPClient.swift
//  SwiftFoundation
//
//  Created by Alsey Coleman Miller on 9/02/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Dispatch

#if canImport(FoundationNetworking)
typealias FoundationURLRequest = FoundationNetworking.URLRequest
typealias FoundationURLResponse = FoundationNetworking.URLResponse
#else
typealias FoundationURLRequest = Foundation.URLRequest
typealias FoundationURLResponse = Foundation.URLResponse
#endif

// Dot notation syntax for class
public extension HTTP {
    
    /// Loads HTTP requests
    public final class Client {
        
        public init(session: URLSession? = nil) {
            
            if let session = session {
                
                self.session = session
                
            } else {
                
                #if os(macOS)
                    self.session = URLSession.shared
                #else
                    self.session = URLSession(configuration: URLSessionConfiguration())
                #endif
            }
        }
        
        /// The backing ```NSURLSession```.
        public let session: URLSession
        
        public func send(request: HTTP.Request) throws -> HTTP.Response {
            
            var dataTask: URLSessionDataTask?
            
            return try send(request: request, dataTask: &dataTask)
        }
        
        public func send(request: HTTP.Request, dataTask: inout URLSessionDataTask?) throws -> HTTP.Response {
            
            // build request... 
            
            guard let urlRequest = FoundationURLRequest(request: request)
                else { throw Error.BadRequest }
            
            // execute request
            
            let semaphore = DispatchSemaphore(value: 0);
            
            var error: Swift.Error?
            
            var responseData: Data?
            
            var urlResponse: HTTPURLResponse?
            
            dataTask = self.session.dataTask(with: urlRequest) { (data: Foundation.Data?, response: FoundationURLResponse?, responseError: Swift.Error?) -> () in
                
                responseData = data
                
                urlResponse = response as? HTTPURLResponse
                
                error = responseError
                
                semaphore.signal()
            }
            
            dataTask!.resume()
            
            // wait for task to finish
            
            let _ = semaphore.wait(timeout: DispatchTime.distantFuture);
            
            guard urlResponse != nil else { throw error! }
            
            var response = HTTP.Response()
            
            response.statusCode = urlResponse!.statusCode
            
            if let data = responseData, data.count > 0 {
                
                response.body = data
            }
            
            response.headers = urlResponse!.allHeaderFields as! [String: String]
            
            response.url = urlResponse!.url
            
            return response
        }
    }
}


public extension HTTP.Client {
    
    public enum Error: Swift.Error {
        
        /// The provided request was malformed.
        case BadRequest
    }
}

public extension FoundationURLRequest {
    
    init?(request: HTTP.Request) {
        
        guard request.version == HTTP.Version(1, 1) else { return nil }
        
        self.init(url: request.url, timeoutInterval: request.timeoutInterval)
        
        if request.body.isEmpty == false {
            
            self.httpBody = request.body
        }
        
        self.allHTTPHeaderFields = request.headers
        
        self.httpMethod = request.method.rawValue
    }
}

