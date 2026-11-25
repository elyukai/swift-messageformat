//
//  ParseCST.swift
//  MessageFormatCST
//
//  Created by Lukas Obermann on 23.11.26.
//

public class ParseContext {
    var errors: [MessageSyntaxError] = []
    let resource: Bool
    let source: String
    
    init(source: String, resource: Bool? = nil) {
        self.resource = resource ?? false
        self.source = source
    }
    
    func onError(type: MessageSyntaxError.Kind, start: String.Index, end: String.Index) {
        errors.append(
            MessageSyntaxError(
                type: type,
                start: start,
                end: end
            )
        )
    }
    
    func onError(type: MessageSyntaxError.Kind, start: String.Index, expected: String) {
        errors.append(
            MessageSyntaxError(
                type: type,
                start: start,
                end: source.index(start, offsetBy: expected.count),
                expected: expected
            )
        )
    }
}

/// Parse the string syntax representation of a message into its corresponding ``Message``
/// representation.
public func parseCST(source: String, resource: Bool? = nil) -> Root {
    let ctx = ParseContext(source: source, resource: resource)
    
    let pos = whitespaces(src: source, start: source.startIndex).end
    if source.suffix(from: pos).hasPrefix(".") {
        let (declarations, end) = parseDeclarations(ctx: ctx, start: pos)
        return source.suffix(from: end).hasPrefix(".match")
            ? parseSelectMessage(ctx: ctx, start: end, declarations: declarations)
            : parsePatternMessage(ctx: ctx, start: end, declarations: declarations, complex: true)
    } else {
        return source.suffix(from: pos).hasPrefix("{{")
            ? parsePatternMessage(ctx: ctx, start: pos, declarations: [], complex: true)
            : parsePatternMessage(ctx: ctx, start: source.startIndex, declarations: [], complex: false)
    }
}

func parsePatternMessage(ctx: ParseContext, start: String.Index, declarations: [Declaration], complex: Bool) -> Message {
    let pattern = parsePattern(ctx: ctx, start: start, quoted: complex)
    let pos = whitespaces(src: ctx.source, start: pattern.end).end
    
    if pos < ctx.source.endIndex {
        ctx.onError(type: .extraContent, start: pos, end: ctx.source.endIndex)
    }
    
    return complex
        ? .complex(.init(declarations: declarations, pattern: pattern, errors: ctx.errors))
        : .simple(.init(pattern: pattern, errors: ctx.errors))
}

func parseSelectMessage(ctx: ParseContext, start: String.Index, declarations: [Declaration]) -> Message {
    var pos = ctx.source.index(start, offsetBy: 6) // '.match'
    let match = Syntax(value: .keyword(.match), start: start, end: pos)
    var ws = whitespaces(src: ctx.source, start: pos)
    if !ws.hasWS { ctx.onError(type: .missingSyntax, start: pos, expected: "' '") }
    pos = ws.end
    
    var selectors: [VariableRef] = []
    while ctx.source[pos] == "$" {
        let sel = parseVariable(ctx: ctx, start: pos)
        selectors.append(sel)
        pos = sel.end
        ws = whitespaces(src: ctx.source, start: pos)
        if !ws.hasWS { ctx.onError(type: .missingSyntax, start: pos, expected: "' '") }
        pos = ws.end
    }
    if selectors.isEmpty {
        ctx.onError(type: .emptyToken, start: pos, end: ctx.source.index(after: pos))
    }
    
    var variants: [Variant] = []
    while pos < ctx.source.endIndex {
        let variant = parseVariant(ctx: ctx, start: start)
        if variant.end > pos {
            variants.append(variant)
            pos = variant.end
        } else {
            pos = ctx.source.index(after: pos)
        }
        pos = whitespaces(src: ctx.source, start: pos).end
    }
    
    if pos < ctx.source.endIndex {
        ctx.onError(type: .extraContent, start: pos, end: ctx.source.endIndex)
    }
    
    return .select(.init(
        declarations: declarations,
        match: match,
        selectors: selectors,
        variants: variants,
        errors: ctx.errors
    ))
}

func parseVariant(ctx: ParseContext, start: String.Index) -> Variant {
    var pos = start
    var keys: [Variant.Key] = []
    while pos < ctx.source.endIndex {
        let ws = whitespaces(src: ctx.source, start: pos)
        pos = ws.end
        let ch = ctx.source[pos]
        if ch == "{" { break }
        
        if pos > start && !ws.hasWS {
            ctx.onError(type: .missingSyntax, start: pos, expected: "' '")
        }
        
        var key: Variant.Key
        if ch == "*" {
            key = .catchall(.init(start: pos, end: ctx.source.index(after: pos)))
        } else {
            let literal = parseRequiredLiteral(ctx: ctx, start: pos)
            // TODO: No normalization support in Swift (https://forums.swift.org/t/pitch-unicode-normalization/73240)
            // literal.value = literal.value.normalize()
            key = .literal(literal)
        }
        if key.end == pos { break }
        keys.append(key)
        pos = key.end
    }
    
    let value = parsePattern(ctx: ctx, start: pos, quoted: true)
    return Variant(start: start, end: value.end, keys: keys, value: value)
}

func parsePattern(ctx: ParseContext, start: String.Index, quoted: Bool) -> Pattern {
    var pos = start
    if quoted {
        if ctx.source.suffix(from: start).hasPrefix("{{") {
            pos = ctx.source.index(start, offsetBy: 2)
        } else {
            ctx.onError(type: .missingSyntax, start: start, expected: "{{")
            return Pattern(start: start, end: start, body: [], braces: nil)
        }
    }
    
    var body: [Pattern.BodyElement] = []
    loop: while pos < ctx.source.endIndex {
        switch ctx.source[pos] {
        case "{":
            let ph = parseExpression(ctx: ctx, start: pos)
            body.append(.expression(ph))
            pos = ph.end
        case "}":
            break loop
        default:
            let tx = parseText(ctx: ctx, start: pos)
            body.append(.text(tx))
            pos = tx.end
        }
    }
    
    if quoted {
        let q0 = Syntax(
            value: .leftDoubleBrace,
            start: start,
            end: ctx.source.index(start, offsetBy: 2)
        )
        var braces: Braces? = nil
        if ctx.source.suffix(from: pos).hasPrefix("}}") {
            braces = (
                opening: q0,
                closing: Syntax(
                    value: .rightDoubleBrace,
                    start: pos,
                    end: ctx.source.index(pos, offsetBy: 2)
                )
            )
            pos = ctx.source.index(pos, offsetBy: 2)
        } else {
            braces = (opening: q0, closing: nil)
            ctx.onError(type: .missingSyntax, start: pos, expected: "}}")
        }
        return Pattern(start: start, end: pos, body: body, braces: braces)
    }
    
    return Pattern(start: start, end: pos, body: body, braces: nil)
}
