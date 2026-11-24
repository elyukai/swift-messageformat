//
//  Errors.swift
//  MessageFormatCST
//
//  Created by Lukas Obermann on 23.11.26.
//

import Foundation

/// Errors in the message syntax.
public struct MessageSyntaxError: Error, CustomDebugStringConvertible {
    public enum Kind: String, Sendable {
        case emptyToken
        case badEscape
        case badInputExpression
        case duplicateAttribute
        case duplicateDeclaration
        case duplicateOptionName
        case duplicateVariant
        case extraContent
        case keyMismatch
        case parseError
        case missingFallback
        case missingSelectorAnnotation
        case missingSyntax
    }

    public let type: Kind
    public let start: String.Index
    public let end: String.Index
    private let message: String

    init(type: Kind, source: String, start: String.Index, end: String.Index? = nil, expected: String? = nil) {
        var message = expected.map { "Missing \($0)" } ?? type.rawValue
        if start >= source.startIndex {
            message += " at \(start)"
        }

        self.type = type
        self.message = message
        self.start = start
        self.end = end ?? source.index(after: source.startIndex)
    }

    public var debugDescription: String {
        return message
    }
}
