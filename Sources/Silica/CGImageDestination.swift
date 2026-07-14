//
//  ImageDestination.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/2/17.
//
//

#if canImport(Foundation)
import struct Foundation.Data
#endif

/// This object abstracts the data-writing task.
/// An image source can write image data to `Data`.
public protocol ImageDestination: AnyObject, RandomAccessCollection, MutableCollection {
    
    
}
