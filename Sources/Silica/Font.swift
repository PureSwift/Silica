//
//  Font.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import CCairo
import CFontConfig

/// Silica's `Font` type.
public final class Font {
    
    // MARK: - Properties
    
    public let name: String
    
    // MARK: - Internal Properties
    
    
    
    // MARK: - Initialization
    
    public init?(name: String) {
        
        // check if font name exists
        
        guard let pattern = FcPattern(name: name)
            else { return nil }
        
        
        
        self.name = name
    }
}

private func FcPattern(name: String) -> OpaquePointer? {
    
    guard let pattern = FcPatternCreate()
        else { return nil }
    
    var error: Bool = false
    
    defer { if error { FcPatternDestroy(pattern) } }
    
    let separator = "-".withCString { (pointer) in return pointer[0] }
    
    let traits: String?
    
    if var traitsCString = strchr(name, CInt(separator)) {
        
        let trimmedCString = traitsCString.advanced(by: 1)
        
        free(traitsCString)
        
        traits = String(utf8String: trimmedCString)
        
    } else {
        
        traits = nil
    }
    
    return pattern
}
