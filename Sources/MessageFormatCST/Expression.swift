//
//  Expression.swift
//  MessageFormatCST
//
//  Created by Lukas Obermann on 23.11.26.
//

func parseExpression(ctx: ParseContext, start: String.Index) -> Expression {
    let source = ctx.source
    var pos = source.index(after: start) // "{"
    pos = whitespaces(src: source, start: pos).end
    
    let arg: SimpleValue? =
        source[pos] == "$"
            ? .variableRef(parseVariable(ctx: ctx, start: pos))
            : parseLiteral(ctx: ctx, start: pos).map { .literal($0) }
    if let arg {
        pos = arg.end
        let ws = whitespaces(src: source, start: pos)
        if !ws.hasWS && source[pos] != "}" {
            ctx.onError(type: .missingSyntax, start: pos, expected: " ")
        }
        pos = ws.end
    }
    
    var functionRefOrMarkup: Expression.FuncRefOrMarkup? = nil
    var junkError: MessageSyntaxError? = nil
    switch source[pos] {
    case ":":
        let ref = parseFunctionRef(ctx: ctx, start: pos)
        functionRefOrMarkup = .funcRef(.function(ref))
        pos = ref.end
    case "#", "/":
        if let arg { ctx.onError(type: .extraContent, start: arg.start, end: arg.end) }
        let m = parseMarkup(ctx: ctx, start: pos)
        functionRefOrMarkup = .markup(m)
        pos = m.end
    case "@", "}":
        if arg == nil { ctx.onError(type: .emptyToken, start: start, end: pos) }
    default:
        if arg == nil {
            let end = source.index(after: pos)
            functionRefOrMarkup =
                .funcRef(.junk(.init(start: pos, end: end, source: String(source[pos]))))
            let error =
                MessageSyntaxError(type: .parseError, start: start, end: end)
            junkError = error
            ctx.errors.append(error)
        }
    }
    
    var attributes: [Attribute] = []
    var reqWS = functionRefOrMarkup != nil
    var ws = whitespaces(src: source, start: pos)
    while source[ws.end] == "@" {
        if reqWS && !ws.hasWS { ctx.onError(type: .missingSyntax, start: pos, expected: " ") }
        pos = ws.end
        let attr = parseAttribute(ctx: ctx, start: pos)
        attributes.append(attr)
        pos = attr.end
        reqWS = true
        ws = whitespaces(src: source, start: pos)
    }
    pos = ws.end
    
    let open = Syntax(value: .leftSingleBrace, start: start, end: source.index(after: start))
    var close: Syntax? = nil
    if pos >= source.endIndex {
        ctx.onError(type: .missingSyntax, start: pos, expected: "}")
    } else {
        if source[pos] != "}" {
            let errStart = pos
            while pos < source.endIndex && source[pos] != "}" { pos = source.index(after: pos) }
            switch functionRefOrMarkup {
            case .funcRef(.junk(let junk)):
                let newStart = junk.start
                functionRefOrMarkup =
                    .funcRef(.junk(.init(start: newStart, end: pos, source: String(source[newStart..<pos]))))
                if let err = junkError {
                    junkError = MessageSyntaxError(type: err.type, start: err.start, end: pos)
                }
            case .funcRef(.function(_)), .markup(_), nil:
                ctx.onError(type: .extraContent, start: errStart, end: pos)
            }
        }
        if source[pos] == "}" {
            close = Syntax(value: .rightSingleBrace, start: pos, end: source.index(after: pos))
            pos = source.index(after: pos)
        }
    }
    let braces: (opening: Syntax, closing: Syntax?) = (opening: open, closing: close)
    let end = pos
    switch functionRefOrMarkup {
    case .markup(let markup):
        return Expression(
            start: start,
            end: end,
            braces: braces,
            arg: nil,
            functionRef: nil,
            markup: markup,
            attributes: attributes
        )
    case .funcRef(let functionRef):
        return Expression(
            start: start,
            end: end,
            braces: braces,
            arg: arg,
            functionRef: functionRef,
            markup: nil,
            attributes: attributes
        )
    case nil:
        return Expression(
            start: start,
            end: end,
            braces: braces,
            arg: arg,
            functionRef: nil,
            markup: nil,
            attributes: attributes
        )
    }
}

private func parseFunctionRefOrMarkup(ctx: ParseContext, start: String.Index) -> (start: String.Index, end: String.Index, name: Identifier, options: [Option], close: Syntax?) {
    let source = ctx.source
    let id = parseIdentifier(ctx: ctx, start: source.index(after: start))
    var pos = id.end
    var options: [Option] = []
    var close: Syntax? = nil
    while pos < source.endIndex {
        var ws = whitespaces(src: source, start: pos)
        let next = source[ws.end]
        if next == "@" || next == "}" { break }
        if next == "/" && source[start] == "#" {
            pos = source.index(after: ws.end)
            close = Syntax(value: .slash, start: source.index(before: pos), end: pos)
            ws = whitespaces(src: source, start: pos)
            if ws.hasWS {
                ctx.onError(type: .extraContent, start: pos, end: ws.end)
                break
            }
        }
        if !ws.hasWS {
            ctx.onError(type: .missingSyntax, start: pos, expected: " ")
            pos = ws.end
            let opt = parseOption(ctx: ctx, start: pos)
            if opt.end == pos { break } // error
            options.append(opt)
            pos = opt.end
        }
    }
    return (start: start, end: pos, name: id.parts, options: options, close: close)
}

func parseFunctionRef(ctx: ParseContext, start: String.Index) -> FunctionRef {
    let (start, end, name, options, _) = parseFunctionRefOrMarkup(ctx: ctx, start: start)
    let open = Syntax(value: .colon, start: start, end: ctx.source.index(after: start))
    return FunctionRef(start: start, end: end, open: open, name: name, options: options)
}

func parseMarkup(ctx: ParseContext, start: String.Index) -> Markup {
    let (start, end, name, options, close) = parseFunctionRefOrMarkup(ctx: ctx, start: start)
    let open = Syntax(
        value: ctx.source[start] == "#" ? .doublecross : .slash,
        start: start,
        end: ctx.source.index(after: start)
    )
    return Markup(start: start, end: end, open: open, name: name, options: options, close: close)
}

func parseOption(ctx: ParseContext, start: String.Index) -> Option {
    let id = parseIdentifier(ctx: ctx, start: start)
    var pos = whitespaces(src: ctx.source, start: id.end).end
    var equals: Syntax? = nil
    if ctx.source[pos] == "=" {
        equals = Syntax(value: .equals, start: pos, end: ctx.source.index(after: pos))
        pos = ctx.source.index(after: pos)
    } else {
        ctx.onError(type: .missingSyntax, start: pos, expected: "=")
    }
    pos = whitespaces(src: ctx.source, start: pos).end
    let value: SimpleValue =
        ctx.source[pos] == "$"
            ? .variableRef(parseVariable(ctx: ctx, start: pos))
            : .literal(parseRequiredLiteral(ctx: ctx, start: pos))
    return Option(start: start, end: value.end, name: id.parts, equals: equals, value: value)
}

func parseIdentifier(ctx: ParseContext, start: String.Index) -> (parts: Identifier, end: String.Index) {
    let source = ctx.source
    guard let name0 = parseNameValue(source: source, start: start) else {
        ctx.onError(type: .emptyToken, start: start, end: source.index(after: start))
        return (parts: .name(Syntax(value: .empty, start: start, end: start)), end: start)
    }
    var pos = name0.end
    let id0 = Syntax(value: .identifier(name0.value), start: start, end: pos)
    if source[pos] != ":" {
        return (parts: .name(id0), end: pos)
    }
    
    let sep = Syntax(value: .colon, start: pos, end: source.index(after: pos))
    pos = source.index(after: pos)
    
    if let name1 = parseNameValue(source: source, start: pos) {
        let id1 = Syntax(value: .identifier(name1.value), start: pos, end: name1.end)
        return (parts: .namespacedName(namespace: id0, separator: sep, name: id1), end: name1.end)
    } else {
        ctx.onError(type: .emptyToken, start: pos, end: source.index(after: pos))
        return (parts: .namespace(id0, separator: sep), end: pos)
    }
}

func parseAttribute(ctx: ParseContext, start: String.Index) -> Attribute {
    let source = ctx.source
    let id = parseIdentifier(ctx: ctx, start: source.index(after: start))
    var pos = id.end
    let ws = whitespaces(src: source, start: pos)
    var equals: Syntax? = nil
    var value: Literal? = nil
    if source[ws.end] == "=" {
        pos = source.index(after: ws.end)
        equals = Syntax(value: .equals, start: source.index(before: pos), end: pos)
        pos = whitespaces(src: source, start: pos).end
        let lit = parseRequiredLiteral(ctx: ctx, start: pos)
        value = lit
        pos = lit.end
    }
    return Attribute(
        start: start,
        end: pos,
        open: Syntax(value: .atSign, start: start, end: source.index(after: start)),
        name: id.parts,
        equals: equals,
        value: value
    )
}
