//
//  Declarations.swift
//  MessageFormatCST
//
//  Created by Lukas Obermann on 23.11.26.
//

nonisolated(unsafe) fileprivate let junkEnd: Regex = /\.[a-z]|{{/

func parseDeclarations(ctx: ParseContext, start: String.Index) -> (declarations: [Declaration], end: String.Index) {
    let source = ctx.source
    var pos = start
    var declarations: [Declaration] = []
    loop: while source[pos] == "." {
        let posPlus6 = source.index(pos, offsetBy: 6)
        let keyword = source[pos..<posPlus6]
        var decl: Declaration
        switch keyword {
        case ".match":
            break loop
        case ".input":
            decl = .input(parseInputDeclaration(ctx: ctx, start: pos))
        case ".local":
            decl = .local(parseLocalDeclaration(ctx: ctx, start: pos))
        default:
            decl = .junk(parseDeclarationJunk(ctx: ctx, start: pos))
        }
        declarations.append(decl)
        pos = whitespaces(src: source, start: decl.end).end
    }
    return (declarations: declarations, end: pos)
}

func parseInputDeclaration(ctx: ParseContext, start: String.Index) -> InputDeclaration {
    var pos = ctx.source.index(start, offsetBy: 6) // .input
    let keyword = Syntax(value: .keyword(.input), start: start, end: pos)
    pos = whitespaces(src: ctx.source, start: pos).end
    
    let value = parseDeclarationValue(ctx: ctx, start: pos)
    if case .expression(let expression) = value,
        expression.markup != nil || !(expression.arg?.isVariableRef ?? false) {
        ctx.onError(type: .badInputExpression, start: value.start, end: value.end)
    }
    
    return InputDeclaration(start: start, end: value.end, keyword: keyword, value: value)
}

func parseLocalDeclaration(ctx: ParseContext, start: String.Index) -> LocalDeclaration {
    let source = ctx.source
    
    var pos = source.index(start, offsetBy: 6) // .local
    let keyword = Syntax(value: .keyword(.local), start: start, end: pos)
    let ws = whitespaces(src: source, start: pos)
    pos = ws.end
    
    if !ws.hasWS { ctx.onError(type: .missingSyntax, start: pos, expected: " ") }
    
    var target: LocalDeclaration.Target
    
    if source[pos] == "$" {
        target = .variableRef(parseVariable(ctx: ctx, start: pos))
        pos = target.end
    } else {
        let junkStart = pos
        let junkEndIndex = source.suffix(from: pos).firstIndex { "\t\n\r ={}".contains($0) }
        pos = junkEndIndex ?? source.endIndex
        target = .junk(Junk(start: junkStart, end: pos, source: String(source[junkStart..<pos])))
        ctx.onError(type: .missingSyntax, start: junkStart, expected: "$")
    }
    
    pos = whitespaces(src: source, start: pos).end
    var equals: Syntax? = nil
    if source[pos] == "=" {
        equals = Syntax(value: .equals, start: pos, end: source.index(after: pos))
        pos = source.index(after: pos)
    } else {
        ctx.onError(type: .missingSyntax, start: pos, expected: "=")
    }
    
    pos = whitespaces(src: source, start: pos).end
    let value = parseDeclarationValue(ctx: ctx, start: pos)
    
    return LocalDeclaration(
        start: start,
        end: value.end,
        keyword: keyword,
        target: target,
        equals: equals,
        value: value
    )
}

func parseDeclarationValue(ctx: ParseContext, start: String.Index) -> Declaration.Value {
    return ctx.source[start] == "{"
        ? .expression(parseExpression(ctx: ctx, start: start))
        : .junk(parseDeclarationJunk(ctx: ctx, start: start))
}

private func getDeclarationJunkEnd(source: String, junkEnd: String.Index?) -> String.Index {
    if let junkEnd {
        var tempEnd = source.index(after: junkEnd)
        while source[source.index(before: tempEnd)].isWhitespace {
            tempEnd = source.index(before: tempEnd)
        }
        return tempEnd
    } else {
        return source.endIndex
    }
}

func parseDeclarationJunk(ctx: ParseContext, start: String.Index) -> Junk {
    let source = ctx.source
    let junkEndOffset: Regex.Match? = source.suffix(from: source.index(after: start)).firstMatch(of: junkEnd)
    let end: String.Index = getDeclarationJunkEnd(source: source, junkEnd: junkEndOffset?.endIndex)
    ctx.onError(type: .missingSyntax, start: start, expected: "{")
    return Junk(start: start, end: end, source: String(source[start..<end]))
}
