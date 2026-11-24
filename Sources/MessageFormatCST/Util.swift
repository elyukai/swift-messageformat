//
//  Util.swift
//  MessageFormatCST
//
//  Created by Lukas Obermann on 23.11.26.
//

import Foundation

fileprivate let bidiChars = "\u{061C}\u{200E}\u{200F}\u{2066}\u{2067}\u{2068}\u{2069}"
fileprivate let whitespaceChars = "\t\n\r \u{3000}"

func whitespaces(src: String, start: String.Index) -> (hasWS: Bool, end: String.Index) {
    var hasWS = false
    var pos = start
    var ch = src[pos]
    while bidiChars.contains(ch) {
        pos = src.index(after: pos)
        ch = src[pos]
    }
    while whitespaceChars.contains(ch) {
        hasWS = true
        pos = src.index(after: pos)
        ch = src[pos]
    }
    while bidiChars.contains(ch) || whitespaceChars.contains(ch) {
        pos = src.index(after: pos)
        ch = src[pos]
    }
    return (hasWS: hasWS, end: pos)
}
