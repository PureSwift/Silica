//
//  ImageSourcePNG.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import struct Foundation.Data

public final class CGImageSourcePNG: CGImageSource {

    // MARK: - Class Properties

    public static var typeIdentifier: String { "public.png" }

     // MARK: - Properties

    internal let image: CGImage

    // MARK: - Initialization

    public init?(data: Data) {

        guard let backend = SilicaBackend.default,
            let image = backend.decodePNG(data)
            else { return nil }

        self.image = image
    }

    // MARK: - Methods

    public func createImage(at index: Int) -> CGImage? {
        return image
    }
}
