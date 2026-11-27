//
//  Export.swift
//  SilicaCairo
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if !SWIFT_PACKAGE || Cairo
@_exported import Silica

// Foundation has an `AffineTransform` too: in this module the name is Silica's.
typealias AffineTransform = Silica.AffineTransform
#endif
