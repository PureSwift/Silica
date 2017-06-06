//
//  URLRequest.swift
//  SwiftFoundation
//
//  Created by Alsey Coleman Miller on 6/29/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

import struct Foundation.URL
import typealias Foundation.TimeInterval

public protocol URLRequest {
    
    var url: URL { get }
    
    var timeoutInterval: TimeInterval { get }
}
