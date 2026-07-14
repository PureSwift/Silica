//
//  SilicaError.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

/// Backend-independent error type for Silica graphics operations.
public enum SilicaError: Error, Sendable {

    /// The graphics context is in an invalid state.
    case invalidContext

    /// An invalid restore operation, such as restoring a non-existent state.
    case invalidRestore

    /// Insufficient memory to perform the operation.
    case noMemory

    /// An error occurred while reading data.
    case readError

    /// An error occurred while writing data.
    case writeError

    /// A rendering backend specific error.
    case backend(code: Int32, description: String)
}
