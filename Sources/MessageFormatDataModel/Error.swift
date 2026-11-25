//
//  Error.swift
//  MessageFormat
//
//  Created by Lukas Obermann on 24.11.26.
//

import Foundation
import MessageFormatCST

/// Errors in the message data model.
public struct MessageDataModelError: MessageSyntaxErrorProtocol {
    public enum Kind: String, Sendable {
        case duplicateDeclaration
        case duplicateVariant
        case keyMismatch
        case missingFallback
        case missingSelectorAnnotation
    }

    public let type: Kind
    public let start: String.Index
    public let end: String.Index
    private let message: String
    
    init(type: Kind, node: Node) {
        self.type = type
        self.start = node.start ?? "".index(before: "".startIndex)
        self.end = node.end ?? "".index(before: "".startIndex)
        self.message = "\(type.rawValue) at \(start)"
    }

    public var debugDescription: String {
        return message
    }
}
