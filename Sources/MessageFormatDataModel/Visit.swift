//
//  Visit.swift
//  MessageFormat
//
//  Created by Lukas Obermann on 24.11.26.
//

import MessageFormatCST

public typealias End<Err: Error> = (() throws(Err) -> Void)?

public protocol MessageVisitor {
    associatedtype Err: Error
    
    func visitAttributes(_ node: Attributes, in context: VisitContext) throws(Err) -> End<Err>
    func visitDeclaration(_ node: Declaration) throws(Err) -> End<Err>
    func visitExpression(_ node: Expression, in context: VisitContext) throws(Err) -> End<Err>
    func visitFunctionRef(_ node: FunctionRef, in context: VisitContext, withArgument arg: SimpleValue?) throws(Err) -> End<Err>
    func visitKey(_ node: Variant.Key, atIndex index: Int, allKeys: [Variant.Key]) throws(Err) -> End<Err>
    func visitMarkup(_ node: Markup, in context: VisitContext) throws(Err) -> End<Err>
    func visitNode(_ node: Node) throws(Err) -> End<Err>
    func visitOptions(_ node: Options, in context: VisitContext) throws(Err) -> End<Err>
    func visitPattern(_ node: Pattern) throws(Err) -> End<Err>
    func visitValue(_ node: SimpleValue, in context: VisitValueContext, at position: VisitValuePosition) throws(Err) -> End<Err>
    func visitVariant(_ node: Variant) throws(Err) -> End<Err>
}

extension MessageVisitor {
    public func visitAttributes(_ node: Attributes, in context: VisitContext) throws(Err) -> End<Err> {
        nil
    }
    
    public func visitDeclaration(_ node: Declaration) throws(Err) -> End<Err> {
        try visitNode(node.asNode())
    }
    
    public func visitExpression(_ node: Expression, in context: VisitContext) throws(Err) -> End<Err> {
        try visitNode(node.asNode())
    }
    
    public func visitFunctionRef(_ node: FunctionRef, in context: VisitContext, withArgument arg: SimpleValue?) throws(Err) -> End<Err> {
        try visitNode(node.asNode())
    }
    
    public func visitKey(_ node: Variant.Key, atIndex index: Int, allKeys: [Variant.Key]) throws(Err) -> End<Err> {
        try visitNode(node.asNode())
    }
    
    public func visitMarkup(_ node: Markup, in context: VisitContext) throws(Err) -> End<Err> {
        try visitNode(node.asNode())
    }
    
    public func visitNode(_ node: Node) throws(Err) -> End<Err> {
        nil
    }
    
    public func visitOptions(_ node: Options, in context: VisitContext) throws(Err) -> End<Err> {
        nil
    }
    
    public func visitPattern(_ node: Pattern) throws(Err) -> End<Err> {
        nil
    }
    
    public func visitValue(_ node: SimpleValue, in context: VisitValueContext, at position: VisitValuePosition) throws(Err) -> End<Err> {
        try visitNode(node.asNode())
    }
    
    public func visitVariant(_ node: Variant) throws(Err) -> End<Err> {
        try visitNode(node.asNode())
    }
}

public enum VisitContext {
    case declaration, placeholder
    
    public func asValueContext() -> VisitValueContext {
        switch self {
        case .declaration: .declaration
        case .placeholder: .placeholder
        }
    }
}

public enum VisitValueContext {
    case declaration, placeholder, selector
}

public enum VisitValuePosition {
    case arg, option, attribute
}

extension Message {
    func visit<Visitor: MessageVisitor>(
        by visitor: Visitor
    ) throws(Visitor.Err) {
        func handleOptions(_ opts: Options?, in context: VisitContext) throws(Visitor.Err) {
            if let opts {
                let end = try visitor.visitOptions(opts, in: context)
                for opt in opts {
                    _ = try visitor.visitValue(opt.value, in: context.asValueContext(), at: .option)
                }
                try end?()
            }
        }
        
        func handleAttributes(_ attrs: Attributes?, in context: VisitContext) throws(Visitor.Err) {
            if let attrs {
                let end = try visitor.visitAttributes(attrs, in: context)
                for attr in attrs {
                    if case .literal(let literal) = attr.value {
                        _ = try visitor.visitValue(
                            .literal(literal),
                            in: context.asValueContext(),
                            at: .attribute
                        )
                    }
                }
                try end?()
            }
        }
        
        func handleElement(_ exp: PatternPart, in context: VisitContext) throws(Visitor.Err) {
            switch exp {
            case .text(_): break
            case .expression(let expression):
                let end = try visitor.visitExpression(expression, in: context)
                if let arg = expression.arg {
                    _ = try visitor.visitValue(arg, in: context.asValueContext(), at: .arg)
                }
                if let functionRef = expression.ref {
                    let endA = try visitor.visitFunctionRef(
                        functionRef,
                        in: context,
                        withArgument: expression.arg
                    )
                    try handleOptions(functionRef.options, in: context)
                    try endA?()
                }
                try handleAttributes(expression.attributes, in: context)
                try end?()
            case .markup(let markup):
                let end = try visitor.visitMarkup(markup, in: context)
                try handleOptions(markup.options, in: context)
                try handleAttributes(markup.attributes, in: context)
                try end?()
            }
        }
        
        func handlePattern(_ pat: Pattern) throws(Visitor.Err) {
            let end = try visitor.visitPattern(pat)
            for el in pat { try handleElement(el, in: .placeholder) }
            try end?()
        }
        
        for decl in declarations {
            let end = try visitor.visitDeclaration(decl)
            try handleElement(.expression(decl.value), in: .declaration)
            try end?()
        }
        
        switch self {
        case .pattern(let patternMessage):
            try handlePattern(patternMessage.pattern)
        case .select(let selectMessage):
            for selector in selectMessage.selectors {
                _ = try visitor.visitValue(.variableRef(selector), in: .selector, at: .arg)
            }
            for variant in selectMessage.variants {
                let end = try visitor.visitVariant(variant)
                for (index, key) in variant.keys.enumerated() {
                    _ = try visitor.visitKey(key, atIndex: index, allKeys: variant.keys)
                }
                try handlePattern(variant.value)
                try end?()
            }
        }
    }
}
