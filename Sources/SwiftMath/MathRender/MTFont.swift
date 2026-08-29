
import Foundation
import CoreText

//
//  Created by Mike Griebling on 2022-12-31.
//  Translated from an Objective-C implementation by Kostub Deshmukh.
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

public class MTFont {

    var defaultCGFont: CGFont!
    var ctFont: CTFont!
    var mathTable: MTFontMathTable?
    var rawMathTable: NSDictionary?

    /// Fallback font for characters not supported by the main math font.
    /// Defaults to the system font at the same size. This is particularly useful
    /// for rendering text in \text{} commands with characters outside the math font's coverage
    /// (e.g., Chinese, Japanese, Korean, emoji, etc.)
    public var fallbackFont: CTFont?

    init() {}
    
    /// `MTFont(fontWithName:)` does not load the complete math font, it only has about half the glyphs of the full math font.
    /// In particular it does not have the math italic characters which breaks our variable rendering.
    /// So we first load a CGFont from the file and then convert it to a CTFont.
    convenience init(fontWithName name: String, size:CGFloat) {
        self.init()
        //print("Loading font \(name)")
        let bundle = MTFont.fontBundle
        let fontPath = bundle.path(forResource: name, ofType: "otf")
        let fontDataProvider = CGDataProvider(filename: fontPath!)
        self.defaultCGFont = CGFont(fontDataProvider!)!
        //print("Num glyphs: \(self.defaultCGFont.numberOfGlyphs)")
        
        self.ctFont = CTFontCreateWithGraphicsFont(self.defaultCGFont, size, nil, nil);
        
        //print("Loading associated .plist")
        let mathTablePlist = bundle.url(forResource:name, withExtension:"plist")
        self.rawMathTable = NSDictionary(contentsOf: mathTablePlist!)
        self.mathTable = MTFontMathTable(withFont:self, mathTable:rawMathTable!)
    }
    
    static var fontBundle:Bundle {
        // Uses bundle for class so that this can be access by the unit tests.
        Bundle(url: Bundle.module.url(forResource: "mathFonts", withExtension: "bundle")!)!
    }
    
    /** Returns a copy of this font but with a different size. */
    public func copy(withSize size: CGFloat) -> MTFont {
        let newFont = MTFont()
        newFont.defaultCGFont = self.defaultCGFont
        newFont.ctFont = CTFontCreateWithGraphicsFont(self.defaultCGFont, size, nil, nil)
        newFont.rawMathTable = self.rawMathTable
        newFont.mathTable = MTFontMathTable(withFont: newFont, mathTable: newFont.rawMathTable!)
        if let fallbackFont {
            newFont.fallbackFont = CTFontCreateCopyWithAttributes(fallbackFont, size, nil, nil)
        }
        return newFont
    }

    /// Builds a text run using the math font where possible and Core Text's
    /// cascade from the configured fallback font for characters it does not
    /// contain. Measurement and drawing share this attributed string so text
    /// such as `\text{中文}` cannot be measured with one font and drawn with
    /// another.
    public func attributedStringWithFallback(for text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        guard !text.isEmpty else { return attributed }
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(
            kCTFontAttributeName as NSAttributedString.Key,
            value: ctFont as Any,
            range: fullRange
        )

        guard let fallbackFont else { return attributed }
        let source = text as NSString
        var location = 0
        while location < source.length {
            let characterRange = source.rangeOfComposedCharacterSequence(at: location)
            let characters = Array(source.substring(with: characterRange).utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            var mutableCharacters = characters
            let primaryContainsCharacter = CTFontGetGlyphsForCharacters(
                self.ctFont,
                &mutableCharacters,
                &glyphs,
                mutableCharacters.count
            ) && glyphs.allSatisfy { $0 != 0 }
            if !primaryContainsCharacter {
                let resolved = CTFontCreateForString(
                    fallbackFont,
                    text as CFString,
                    CFRange(location: characterRange.location, length: characterRange.length)
                )
                attributed.addAttribute(
                    kCTFontAttributeName as NSAttributedString.Key,
                    value: resolved,
                    range: characterRange
                )
            }
            location = NSMaxRange(characterRange)
        }
        return attributed
    }
    
    func get(nameForGlyph glyph:CGGlyph) -> String {
        let name = defaultCGFont.name(for: glyph) as? String
        return name ?? ""
    }
    
    func get(glyphWithName name:String) -> CGGlyph {
        defaultCGFont.getGlyphWithGlyphName(name: name as CFString)
    }
    
    /** The size of this font in points. */
    public var fontSize:CGFloat { CTFontGetSize(self.ctFont) }
    
    deinit {
        self.ctFont = nil
        self.defaultCGFont = nil
    }
    
}
