//
//  Names.swift
//  MessageFormatCST
//
//  Created by Lukas Obermann on 23.11.26.
//

nonisolated(unsafe) fileprivate let bidiChars: Regex = /^[\u061c\u200e\u200f\u2066-\u2069]+/

nonisolated(unsafe) fileprivate let nameChars: Regex =
    /^[-.+0-9A-Z_a-z\u{a1}-\u{61b}\u{61d}-\u{167f}\u{1681}-\u{1fff}\u{200b}-\u{200d}\u{2010}-\u{2027}\u{2030}-\u{205e}\u{2060}-\u{2065}\u{206a}-\u{2fff}\u{3001}-\u{d7ff}\u{e000}-\u{fdcf}\u{fdf0}-\u{fffd}\u{10000}-\u{1fffd}\u{20000}-\u{2fffd}\u{30000}-\u{3fffd}\u{40000}-\u{4fffd}\u{50000}-\u{5fffd}\u{60000}-\u{6fffd}\u{70000}-\u{7fffd}\u{80000}-\u{8fffd}\u{90000}-\u{9fffd}\u{a0000}-\u{afffd}\u{b0000}-\u{bfffd}\u{c0000}-\u{cfffd}\u{d0000}-\u{dfffd}\u{e0000}-\u{efffd}\u{f0000}-\u{ffffd}\u{100000}-\u{10fffd}]+/

nonisolated(unsafe) fileprivate let notNameStart: Regex = /^[-.0-9]/

func parseNameValue(source: String, start: String.Index) -> (value: String, end: String.Index)? {
    var pos = start
    let startString: Substring = source.suffix(from: pos)
    if let startBidi = startString.firstMatch(of: bidiChars) {
        pos = startBidi.range.upperBound
    }

    let match = source.suffix(from: pos).firstMatch(of: nameChars)
    guard let match else { return nil }
    let name = match.output
    guard name.firstMatch(of: notNameStart) == nil else { return nil }
    pos = match.range.upperBound

    let endBidi = source.suffix(from: pos).firstMatch(of: bidiChars)
    if let endBidi {
        pos = endBidi.endIndex
    }

    return (value: String(name), end: pos)
}

public func isValidUnquotedLiteral(str: String) -> Bool {
    if let match = str.prefixMatch(of: nameChars) {
        match.count == str.count
    } else {
        false
    }
}

func parseUnquotedLiteralValue(source: String, start: String.Index) -> Substring? {
    source.suffix(from: start).prefixMatch(of: nameChars)?.output
}
