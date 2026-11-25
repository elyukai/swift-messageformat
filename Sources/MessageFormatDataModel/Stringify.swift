//
//  Stringify.swift
//  MessageFormat
//
//  Created by Lukas Obermann on 24.11.26.
//

/// Stringify a {@link Message} using its syntax representation. Parsing and stringifying a message
/// will not necessarily produce exactly the same syntax representation.
public func stringifyMessage(_ msg: Message) -> String {
    msg.description
}
