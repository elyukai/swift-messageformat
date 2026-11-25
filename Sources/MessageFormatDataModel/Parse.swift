//
//  Parse.swift
//  MessageFormat
//
//  Created by Lukas Obermann on 24.11.26.
//

import MessageFormatCST

// TODO: Parser optimised for formatting
// See https://github.com/messageformat/messageformat/pull/418

/// Parse the `source` syntax representation of an MF2 message into its corresponding data model representation.
///
/// Throws on syntax errors, but does not check for data model errors. To check for data model errors, use ``validate``:
///
/// ```swift
/// import MessageFormat
///
/// do {
///     let msg = try parseMessage("Hello {$world}")
///     try validate(msg)
/// } catch as MessageSyntaxError {
///     // MessageDataModelError extends MessageSyntaxError
///     ...
/// } catch {
///    ...
/// }
/// ```
public func parseMessage(source: String) throws(MessageSyntaxError) -> Message {
    try Message.fromCST(parseCST(source: source))
}
