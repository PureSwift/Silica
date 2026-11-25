//
//  FontAPI.swift
//  SilicaCoreGraphicsABI
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

// Apple's CoreGraphics is loaded with Foundation on Darwin, and clashes with
// these headers: libCoreGraphics is for other platforms. Fonts are FreeType's,
// through Silica's Cairo backend.
#if !canImport(Darwin) && canImport(Cairo)

import Cairo
import CCairo
import CFreeType
import CSilicaCoreGraphics
import Silica
import SilicaCairo

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

// The functions of CGFont.h.

/// What a `CGFontRef` points to: a FreeType face, through Cairo.
internal final class FontObject {

    let face: CairoFontHandle

    /// The temporary file a font made from bytes was loaded from.
    private let temporaryFile: String?

    init(face: CairoFontHandle, temporaryFile: String? = nil) {
        self.face = face
        self.temporaryFile = temporaryFile
    }

    deinit {
        if let temporaryFile {
            unlink(temporaryFile)
        }
    }

    var scaledFont: Cairo.ScaledFont { face.scaledFont }

    /// The top of a character's glyph, in font units: for metrics an older
    /// font's tables don't have.
    func top(of character: Unicode.Scalar) -> Int {
        let glyph = scaledFont[UInt(character.value)]
        guard glyph != 0, let box = scaledFont.boundingBoxes(for: [glyph]).first else { return 0 }
        return box.y + box.height
    }

    /// Runs `body` with the FreeType face, locked.
    func withFace<T>(_ body: (FT_Face) -> T) -> T {
        scaledFont.withUnsafePointer { scaled in
            let ftFace = cairo_ft_scaled_font_lock_face(scaled)!
            defer { cairo_ft_scaled_font_unlock_face(scaled) }
            return body(ftFace)
        }
    }

    /// A font from a font file's bytes, loaded from a temporary file.
    static func make(bytes: [UInt8]) -> FontObject? {
        var template = Array("/tmp/silica-font-XXXXXX".utf8CString)
        let descriptor = template.withUnsafeMutableBufferPointer { mkstemp($0.baseAddress!) }
        guard descriptor >= 0 else { return nil }
        let path = template.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        let written = bytes.withUnsafeBytes { write(descriptor, $0.baseAddress!, $0.count) }
        close(descriptor)
        guard written == bytes.count, let face = CairoFontHandle(file: path) else {
            unlink(path)
            return nil
        }
        return FontObject(face: face, temporaryFile: path)
    }
}

/// Silica's fonts by name come from the default backend: Cairo's, here.
internal func registerCairoBackend() {
    if SilicaBackend.default == nil {
        CairoBackend.register()
    }
}

internal func fontObject(_ reference: SilicaCGFontRef?) -> FontObject? {
    object(reference, as: FontObject.self)
}

@c @implementation public func CGFontGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .font)
}

@c @implementation public func CGFontCreateWithDataProvider(_ provider: SilicaCGDataProviderRef?) -> SilicaCGFontRef? {
    guard let provider = object(provider, as: DataProviderObject.self), let made = FontObject.make(bytes: provider.bytes) else { return nil }
    return makeReference(made)
}

@c @implementation public func CGFontCreateWithFontName(_ name: SilicaCFStringRef?) -> SilicaCGFontRef? {
    guard let name = string(name), let face = CairoFontHandle(named: name) else { return nil }
    return makeReference(FontObject(face: face))
}

@c @implementation public func CGFontRetain(_ font: SilicaCGFontRef?) -> SilicaCGFontRef? {
    retain(font)
    return font
}

@c @implementation public func CGFontRelease(_ font: SilicaCGFontRef?) {
    release(font)
}

@c @implementation public func CGFontCopyPostScriptName(_ font: SilicaCGFontRef?) -> SilicaCFStringRef? {
    makeCFString(fontObject(font)?.scaledFont.postScriptName)
}

@c @implementation public func CGFontCopyFullName(_ font: SilicaCGFontRef?) -> SilicaCFStringRef? {
    makeCFString(fontObject(font)?.scaledFont.fullName)
}

@c @implementation public func CGFontGetUnitsPerEm(_ font: SilicaCGFontRef?) -> Int32 {
    Int32(fontObject(font)?.scaledFont.unitsPerEm ?? 0)
}

@c @implementation public func CGFontGetNumberOfGlyphs(_ font: SilicaCGFontRef?) -> Int {
    fontObject(font)?.scaledFont.glyphCount ?? 0
}

/// The line's ascent, as the font's horizontal header has it.
@c @implementation public func CGFontGetAscent(_ font: SilicaCGFontRef?) -> Int32 {
    fontObject(font)?.withFace { Int32($0.pointee.ascender) } ?? 0
}

/// The line's descent, negative, as the font's horizontal header has it.
@c @implementation public func CGFontGetDescent(_ font: SilicaCGFontRef?) -> Int32 {
    fontObject(font)?.withFace { Int32($0.pointee.descender) } ?? 0
}

/// The space between lines: the line height past the ascent and descent.
@c @implementation public func CGFontGetLeading(_ font: SilicaCGFontRef?) -> Int32 {
    fontObject(font)?.withFace { Int32($0.pointee.height) - Int32($0.pointee.ascender) + Int32($0.pointee.descender) } ?? 0
}

/// The cap height the font gives, or else the top of its "H".
@c @implementation public func CGFontGetCapHeight(_ font: SilicaCGFontRef?) -> Int32 {
    guard let font = fontObject(font) else { return 0 }
    let height = font.scaledFont.capHeight
    return Int32(height != 0 ? height : font.top(of: "H"))
}

/// The x-height the font gives, or else the top of its "x".
@c @implementation public func CGFontGetXHeight(_ font: SilicaCGFontRef?) -> Int32 {
    guard let font = fontObject(font) else { return 0 }
    let height = font.scaledFont.xHeight
    return Int32(height != 0 ? height : font.top(of: "x"))
}

@c @implementation public func CGFontGetFontBBox(_ font: SilicaCGFontRef?) -> CGRect {
    guard let box = fontObject(font)?.scaledFont.fontBBox else { return CGRectZero }
    return CGRect(origin: CGPoint(x: Double(box.x), y: Double(box.y)), size: CGSize(width: Double(box.width), height: Double(box.height)))
}

@c @implementation public func CGFontGetItalicAngle(_ font: SilicaCGFontRef?) -> Double {
    fontObject(font)?.scaledFont.italicAngle ?? 0
}

/// FreeType has no stem width: zero, as Apple gives for most TrueType fonts.
@c @implementation public func CGFontGetStemV(_ font: SilicaCGFontRef?) -> Double {
    0
}

@c @implementation public func CGFontGetGlyphBBoxes(_ font: SilicaCGFontRef?, _ glyphs: UnsafePointer<CGGlyph>?, _ count: Int,
                                                    _ bboxes: UnsafeMutablePointer<CGRect>?) -> Bool {
    guard let font = fontObject(font), let glyphs, let bboxes, count >= 0 else { return false }
    let boxes = font.scaledFont.boundingBoxes(for: (0 ..< count).map { glyphs[$0] })
    for (index, box) in boxes.enumerated() {
        bboxes[index] = CGRect(origin: CGPoint(x: Double(box.x), y: Double(box.y)),
                               size: CGSize(width: Double(box.width), height: Double(box.height)))
    }
    return true
}

@c @implementation public func CGFontGetGlyphAdvances(_ font: SilicaCGFontRef?, _ glyphs: UnsafePointer<CGGlyph>?, _ count: Int,
                                                      _ advances: UnsafeMutablePointer<Int32>?) -> Bool {
    guard let font = fontObject(font), let glyphs, let advances, count >= 0 else { return false }
    for (index, advance) in font.scaledFont.advances(for: (0 ..< count).map { glyphs[$0] }).enumerated() {
        advances[index] = Int32(advance)
    }
    return true
}

@c @implementation public func CGFontGetGlyphWithGlyphName(_ font: SilicaCGFontRef?, _ name: SilicaCFStringRef?) -> CGGlyph {
    guard let font = fontObject(font), let name = string(name) else { return 0 }
    return font.scaledFont[name]
}

@c @implementation public func CGFontCopyGlyphNameForGlyph(_ font: SilicaCGFontRef?, _ glyph: CGGlyph) -> SilicaCFStringRef? {
    makeCFString(fontObject(font)?.scaledFont[glyph])
}

@c @implementation public func CGFontCopyTableForTag(_ font: SilicaCGFontRef?, _ tag: UInt32) -> SilicaCFDataRef? {
    guard let font = fontObject(font) else { return nil }
    let table: [UInt8]? = font.withFace { face in
        var length: FT_ULong = 0
        guard FT_Load_Sfnt_Table(face, FT_ULong(tag), 0, nil, &length) == 0, length > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: Int(length))
        guard FT_Load_Sfnt_Table(face, FT_ULong(tag), 0, &bytes, &length) == 0 else { return nil }
        return bytes
    }
    return makeCFData(table)
}

#endif
