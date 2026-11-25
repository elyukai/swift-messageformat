//
//  FromCST.swift
//  MessageFormat
//
//  Created by Lukas Obermann on 24.11.26.
//

import MessageFormatCST

extension Message {
    /// Convert a CST message structure into its data model representation.
    ///
    /// In the returned ``Message``, all nodes include a reference to their source CST node as a `cst` property.
    public static func fromCST(_ msg: MessageFormatCST.Message) throws(MessageSyntaxError) -> Message {
        for error in msg.errors { throw error }
        let declarations = try msg.declarations.map { decl throws(MessageSyntaxError) in
            try decl.asDeclaration()
        }
        switch msg {
        case .select(let selectMessage):
            return .select(
                .init(
                    declarations: declarations,
                    selectors: selectMessage.selectors.map { $0.asValue() },
                    variants: try selectMessage.variants.map { variant throws(MessageSyntaxError) in
                        Variant(
                            keys: variant.keys.map { key in
                                switch key {
                                case .literal(let literal):
                                    .literal(literal.asValue())
                                case .catchall(let catchAllKey):
                                    .catchAll(.init(value: nil, cst: catchAllKey))
                                }
                            },
                            value: try variant.value.asPattern(),
                            cst: variant
                        )
                    },
                    comment: nil
                )
            )
        case .simple(let simple):
            return .pattern(
                .init(
                    declarations: declarations,
                    pattern: try simple.pattern.asPattern(),
                    cst: .simple(simple)
                )
            )
        case .complex(let complex):
            return .pattern(
                .init(
                    declarations: declarations,
                    pattern: try complex.pattern.asPattern(),
                    cst: .complex(complex)
                )
            )
        }
    }
}

extension MessageFormatCST.Declaration {
    func asDeclaration() throws(MessageSyntaxError) -> Declaration {
        switch self {
        case .input(let inputDeclaration):
            .input(try inputDeclaration.asDeclaration())
        case .local(let localDeclaration):
            .local(try localDeclaration.asDeclaration())
        case .junk(let junk):
            throw MessageSyntaxError(type: .parseError, start: junk.start, end: junk.end)
        }
    }
}

extension MessageFormatCST.InputDeclaration {
    func asDeclaration() throws(MessageSyntaxError) -> InputDeclaration {
        let value = try self.value.asExpression()
        guard case .variableRef(let varArg) = value.arg else {
            throw MessageSyntaxError(type: .parseError, start: self.start, end: self.end)
        }
        return .init(name: varArg.name, value: value, cst: self)
    }
}

extension MessageFormatCST.LocalDeclaration {
    func asDeclaration() throws(MessageSyntaxError) -> LocalDeclaration {
        .init(name: try target.asValue().name, value: try value.asExpression(), cst: self)
    }
}

extension MessageFormatCST.LocalDeclaration.Target {
    func asValue() throws(MessageSyntaxError) -> VariableRef {
        switch self {
        case .variableRef(let variableRef): variableRef.asValue()
        case .junk(let junk):
            throw MessageSyntaxError(type: .parseError, start: junk.start, end: junk.end)
        }
    }
}

extension MessageFormatCST.Pattern {
    func asPattern() throws(MessageSyntaxError) -> Pattern {
        try body.map { bodyPart throws(MessageSyntaxError) in
            switch bodyPart {
            case .text(let text): .text(text.value)
            case .expression(let exp): try exp.asPatternPart()
            }
        }
    }
}

extension MessageFormatCST.Expression {
    func asExpression() throws(MessageSyntaxError) -> Expression {
        let arg = arg?.asValue()
        var functionRef: FunctionRef? = nil
        
        if let ca = self.functionRef {
            switch ca {
            case .function(let ref):
                functionRef = try ref.asFunctionRef()
            case .junk(let junk):
                throw MessageSyntaxError(type: .parseError, start: junk.start, end: junk.end)
            }
        }
        if let arg {
            if let functionRef {
                return .init(
                    attributes: try attributes.asAttributes(),
                    value: .both(arg: arg, functionRef: functionRef)
                )
            } else {
                return .init(
                    attributes: try attributes.asAttributes(),
                    value: .arg(arg)
                )
            }
        } else if let functionRef {
            return .init(
                attributes: try attributes.asAttributes(),
                value: .functionRef(functionRef)
            )
        } else {
            throw MessageSyntaxError(type: .parseError, start: start, end: end)
        }
    }
    
    func asPatternPart() throws(MessageSyntaxError) -> PatternPart {
        if let cm = markup {
            return .markup(try cm.asMarkup(withAttributes: attributes))
        } else {
            return .expression(try asExpression())
        }
    }
}

extension MessageFormatCST.Declaration.Value {
    func asExpression() throws(MessageSyntaxError) -> Expression {
        switch self {
        case .expression(let exp):
            return try exp.asExpression()
        case .junk(let junk):
            throw MessageSyntaxError(type: .parseError, start: junk.start, end: junk.end)
        }
    }
}

extension MessageFormatCST.SimpleValue {
    func asValue() -> SimpleValue {
        switch self {
        case .literal(let literal): .literal(literal.asValue())
        case .variableRef(let variableRef): .variableRef(variableRef.asValue())
        }
    }
}

extension MessageFormatCST.Markup {
    func asMarkup(withAttributes attributes: [MessageFormatCST.Attribute]) throws(MessageSyntaxError) -> Markup {
        let name = try name.asName()
        let kind: Markup.Kind =
            self.open.value == .slash ? .close : close != nil ? .standalone : .open
        return Markup(
            kind: kind,
            name: name,
            options: try options.asOptions(),
            attributes: try attributes.asAttributes(),
            cst: self
        )
    }
}

extension MessageFormatCST.FunctionRef {
    func asFunctionRef() throws(MessageSyntaxError) -> FunctionRef {
        FunctionRef(
            name: try name.asName(),
            options: try options.asOptions(),
            cst: self
        )
    }
}

extension Array where Element == MessageFormatCST.Option {
    func asOptions() throws(MessageSyntaxError) -> Options? {
        guard !isEmpty else { return nil }
        var map: Options = [:]
        for opt in self {
            let name = try opt.name.asName()
            if map.keys.contains(name) {
                throw MessageSyntaxError(type: .duplicateOptionName, start: opt.start, end: opt.end)
            }
            map[name] = opt.value.asValue()
        }
        return map
    }
}

extension Array where Element == MessageFormatCST.Attribute {
    func asAttributes() throws(MessageSyntaxError) -> Attributes? {
        guard !isEmpty else { return nil }
        var map: Attributes = [:]
        for attr in self {
            let name = try attr.name.asName()
            if map.keys.contains(name) {
                throw MessageSyntaxError(type: .duplicateAttribute, start: attr.start, end: attr.end)
            }
            let value: Attribute = if let literal = attr.value {
                .literal(literal.asValue())
            } else {
                .present
            }
            map[name] = value
        }
        return map
    }
}

extension MessageFormatCST.Identifier {
    func asName() throws(MessageSyntaxError) -> String {
        switch self {
        case .name(let syntax):
            syntax.description
        case .namespace(let syntax, let separator):
            throw MessageSyntaxError(type: .parseError, start: syntax.start, end: separator.end)
        case .namespacedName(let namespace, _, let name):
            "\(namespace.description):\(name.description)"
        }
    }
}

extension MessageFormatCST.Literal {
    func asValue() -> Literal {
        Literal(value: value, cst: self)
    }
}

extension MessageFormatCST.VariableRef {
    func asValue() -> VariableRef {
        VariableRef(name: name, cst: self)
    }
}
