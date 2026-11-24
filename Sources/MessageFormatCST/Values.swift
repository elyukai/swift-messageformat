//
//  Values.swift
//  MessageFormatCST
//
//  Created by Lukas Obermann on 23.11.26.
//

nonisolated(unsafe) fileprivate let hexValue: Regex = /^[0-9A-Fa-f]+$/

// Text ::= (TextChar | TextEscape)+
// TextChar ::= AnyChar - ('{' | '}' | Esc)
// AnyChar ::= [#x0-#x10FFFF]
// Esc ::= '\'
// TextEscape ::= Esc Esc | Esc '{' | Esc '}'
func parseText(ctx: ParseContext, start: String.Index) -> Text {
    var value = ""
    var pos = start
    var i = start
    loop: while i < ctx.source.endIndex {
        switch ctx.source[i] {
        case "\\":
            if let esc = parseEscape(ctx: ctx, start: i) {
                value += ctx.source[pos..<i] + String(esc.value)
                i = ctx.source.index(i, offsetBy: esc.length)
                pos = ctx.source.index(after: i)
            }
        case "{", "}":
            break loop
        case "\n":
            if ctx.resource {
                let nl = i
                var next = ctx.source[ctx.source.index(after: i)]
                while next == " " || next == "\t" {
                    i = ctx.source.index(after: i)
                    next = ctx.source[ctx.source.index(after: i)]
                }
                if i > nl {
                    value += ctx.source[pos...nl]
                    pos = ctx.source.index(after: i)
                }
            }
        default:
            break
        }
        i = ctx.source.index(after: i)
    }
    value += ctx.source[pos..<i]
    return Text(start: start, end: i, value: value)
}

func parseLiteral(ctx: ParseContext, start: String.Index) -> Literal? {
    guard ctx.source[start] != "|" else { return parseQuotedLiteral(ctx: ctx, start: start) }
    guard let value = parseUnquotedLiteralValue(source: ctx.source, start: start) else {
        return nil
    }
    return Literal(quoted: false, start: start, end: value.endIndex, value: String(value))
}

func parseRequiredLiteral(ctx: ParseContext, start: String.Index) -> Literal {
    guard let literal = parseLiteral(ctx: ctx, start: start) else {
        ctx.onError(type: .emptyToken, start: start, end: start)
        return Literal(quoted: false, start: start, end: start, value: "")
    }
    return literal
}

func parseQuotedLiteral(ctx: ParseContext, start: String.Index) -> Literal {
    var value = ""
    var pos = ctx.source.index(after: start)
    let open = Syntax(value: .verticalBar, start: start, end: pos)
    var i = pos
    while i < ctx.source.endIndex {
        switch ctx.source[i] {
        case "\\":
            if let esc = parseEscape(ctx: ctx, start: i) {
                value += ctx.source[pos..<i] + String(esc.value)
                i = ctx.source.index(i, offsetBy: esc.length)
                pos = ctx.source.index(after: i)
            }
        case "|":
            value += ctx.source[pos..<i]
            let end = ctx.source.index(after: i)
            return Literal(
                quoted: true,
                start: start,
                end: end,
                open: open,
                value: value,
                close: .init(value: .verticalBar, start: i, end: end)
            )
        case "\n":
            if ctx.resource {
                let nl = i
                var next = ctx.source[ctx.source.index(after: i)]
                while next == " " || next == "\t" {
                    i = ctx.source.index(after: i)
                    next = ctx.source[ctx.source.index(after: i)]
                }
                if i > nl {
                    value += ctx.source[pos...nl]
                    pos = ctx.source.index(after: i)
                }
            }
        default:
            break
        }
        i = ctx.source.index(after: i)
    }
    value += ctx.source.suffix(from: pos)
    ctx.onError(type: .missingSyntax, start: ctx.source.endIndex, expected: "|")
    return Literal(
        quoted: true,
        start: start,
        end: ctx.source.endIndex,
        open: open,
        value: value,
        close: nil
    )
}

func parseVariable(ctx: ParseContext, start: String.Index) -> VariableRef {
    let pos = ctx.source.index(after: start)
    let open = Syntax(value: .dollar, start: start, end: pos)
    
    guard let name = parseNameValue(source: ctx.source, start: pos) else {
        ctx.onError(type: .emptyToken, start: pos, end: ctx.source.index(after: pos))
        return VariableRef(start: start, end: pos, open: open, name: "")
    }
    
    return VariableRef(start: start, end: name.end, open: open, name: name.value)
}

func parseEscape(ctx: ParseContext, start: String.Index) -> (value: Character, length: Int)? {
    let raw = ctx.source[ctx.source.index(after: start)]
    if "\\{|}".contains(raw) {
        return (value: raw, length: 1)
    }
    if ctx.resource {
        var hexLen = 0
        
        switch raw {
        case "\t", " ":
            return (value: raw, length: 1)
        case "n":
            return (value: "\n", length: 1)
        case "r":
            return (value: "\r", length: 1)
        case "t":
            return (value: "\t", length: 1)
        case "u":
            hexLen = 4
            break
        case "U":
            hexLen = 6
            break
        case "x":
            hexLen = 2
            break
        default:
            break
        }
        
        if hexLen > 0 {
            let h0 = ctx.source.index(start, offsetBy: 2)
            let hend = ctx.source.index(h0, offsetBy: hexLen)
            let raw = ctx.source[h0..<hend]
            if raw.count == hexLen && raw.wholeMatch(of: hexValue) != nil {
                return (
                    value: Character(UnicodeScalar(UInt8(raw, radix: 16)!)),
                    length: 1 + hexLen
                )
            }
        }
    }
    ctx.onError(type: .badEscape, start: start, end: ctx.source.index(start, offsetBy: 2))
    return nil
}
