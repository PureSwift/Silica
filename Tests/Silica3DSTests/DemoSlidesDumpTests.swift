//
//  DemoSlidesDumpTests.swift
//  Silica3DSTests
//
//  Renders every ports/3DS demo slide (Sources/Silica3DS/DemoSlides.swift)
//  through the same software renderer used on real hardware and writes each
//  one out as a PPM image for visual inspection -- a stand-in "SD card" you
//  can look at without a 3DS or emulator.
//

import XCTest
import Foundation
import Silica3DS

final class DemoSlidesDumpTests: XCTestCase {

    func testDumpAllSlides() throws {

        let outputDirectory = ProcessInfo.processInfo.environment["SILICA_3DS_DUMP_DIR"]
            ?? (NSTemporaryDirectory() + "Silica3DSDump")

        try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

        for (index, slide) in Silica3DSDemo.slides.enumerated() {

            let context = try Nintendo3DSContext(bitmap: Silica3DSDemo.screenSize, scale: 2)

            slide.draw(context)

            guard let image = context.makeImage()
                else { XCTFail("makeImage() returned nil for slide \(slide.name)"); continue }

            var ppm = Data("P6\n\(image.width) \(image.height)\n255\n".utf8)
            for y in 0 ..< image.height {
                for x in 0 ..< image.width {
                    let offset = y * image.bytesPerRow + x * 4
                    ppm.append(image.data[offset])
                    ppm.append(image.data[offset + 1])
                    ppm.append(image.data[offset + 2])
                }
            }

            let safeName = slide.name
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .filter { $0.isLetter || $0.isNumber || $0 == "_" }

            let path = outputDirectory + "/" + String(format: "%02d", index + 1) + "_" + safeName + ".ppm"
            try ppm.write(to: URL(fileURLWithPath: path))
            print("Wrote \(path)")
        }
    }
}
