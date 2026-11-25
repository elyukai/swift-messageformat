//
//  Errors.swift
//  MessageFormatCST
//
//  Created by Lukas Obermann on 23.11.26.
//

import Foundation

public protocol MessageErrorProtocol: Error, CustomDebugStringConvertible {}

public protocol MessageSyntaxErrorProtocol: MessageErrorProtocol {
    var start: String.Index { get }
    var end: String.Index { get }
}

/// Errors in the message syntax.
public struct MessageSyntaxError: MessageSyntaxErrorProtocol {
    public enum Kind: String, Sendable {
        case emptyToken
        case badEscape
        case badInputExpression
        case duplicateAttribute
        case duplicateOptionName
        case extraContent
        case parseError
        case missingSyntax
    }

    public let type: Kind
    public let start: String.Index
    public let end: String.Index
    private let message: String

    public init(type: Kind, start: String.Index, end: String.Index, expected: String? = nil) {
        var message = expected.map { "Missing \($0)" } ?? type.rawValue
        message += " at \(start)"

        self.type = type
        self.message = message
        self.start = start
        self.end = end
    }

    public var debugDescription: String {
        return message
    }
}
