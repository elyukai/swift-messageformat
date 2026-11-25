//
//  Types.swift
//  MessageFormatCST
//
//  Created by Lukas Obermann on 23.11.26.
//

public typealias Root = Message

public protocol Node: CustomStringConvertible {
    var start: String.Index { get }
    var end: String.Index { get }
}

public enum Message: CustomStringConvertible {
    case simple(SimpleMessage)
    case complex(ComplexMessage)
    case select(SelectMessage)
    
    public var description: String {
        switch self {
        case .simple(let simpleMessage): simpleMessage.description
        case .complex(let complexMessage): complexMessage.description
        case .select(let selectMessage): selectMessage.description
        }
    }
    
    public var declarations: [Declaration] {
        switch self {
        case .simple(_): []
        case .complex(let complexMessage): complexMessage.declarations
        case .select(let selectMessage): selectMessage.declarations
        }
    }
    
    public var errors: [MessageSyntaxError] {
        switch self {
        case .simple(let simpleMessage): simpleMessage.errors
        case .complex(let complexMessage): complexMessage.errors
        case .select(let selectMessage): selectMessage.errors
        }
    }
}

public struct SimpleMessage: Node {
    public let pattern: Pattern
    public let errors: [MessageSyntaxError]
    
    public var description: String {
        pattern.description
    }
    
    public var start: String.Index { pattern.start }
    public var end: String.Index { pattern.end }
}

public struct ComplexMessage: Node {
    public let declarations: [Declaration]
    public let pattern: Pattern
    public let errors: [MessageSyntaxError]
    
    public var description: String {
        declarations.map({ $0.description + "\n" }).joined() +
        pattern.bracedDescription
    }
    
    public var start: String.Index {
        declarations.first?.start ?? pattern.start
    }
    
    public var end: String.Index {
        pattern.end
    }
}

public struct SelectMessage: Node {
    public let declarations: [Declaration]
    public let match: Syntax
    public let selectors: [VariableRef]
    public let variants: [Variant]
    public let errors: [MessageSyntaxError]
    
    public var description: String {
        declarations.map({ $0.description + "\n" }).joined() +
        match.description +
        selectors.map({ " " + $0.description }).joined() +
        variants.map({ "\n" + $0.description }).joined()
    }
    
    public var start: String.Index {
        declarations.first?.start ?? match.start
    }
    
    public var end: String.Index {
        variants.last?.end ?? selectors.last?.end ?? match.end
    }
}

public enum Declaration: Node {
    case input(InputDeclaration)
    case local(LocalDeclaration)
    case junk(Junk)
    
    public var description: String {
        switch self {
        case .input(let wrappedNode): wrappedNode.description
        case .local(let wrappedNode): wrappedNode.description
        case .junk(let wrappedNode): wrappedNode.description
        }
    }
    
    public var start: String.Index {
        switch self {
        case .input(let wrappedNode): wrappedNode.start
        case .local(let wrappedNode): wrappedNode.start
        case .junk(let wrappedNode): wrappedNode.start
        }
    }
    
    public var end: String.Index {
        switch self {
        case .input(let wrappedNode): wrappedNode.end
        case .local(let wrappedNode): wrappedNode.end
        case .junk(let wrappedNode): wrappedNode.end
        }
    }
    
    public enum Value: Node {
        case expression(Expression)
        case junk(Junk)
        
        public var description: String {
            switch self {
            case .expression(let wrappedNode): wrappedNode.description
            case .junk(let wrappedNode): wrappedNode.description
            }
        }
        
        public var start: String.Index {
            switch self {
            case .expression(let wrappedNode): wrappedNode.start
            case .junk(let wrappedNode): wrappedNode.start
            }
        }
        
        public var end: String.Index {
            switch self {
            case .expression(let wrappedNode): wrappedNode.end
            case .junk(let wrappedNode): wrappedNode.end
            }
        }
    }
}

public struct InputDeclaration: Node {
    public let start: String.Index
    public let end: String.Index
    public let keyword: Syntax
    public let value: Declaration.Value
    
    public var description: String {
        "\(keyword.description) \(value.description)"
    }
}

public struct LocalDeclaration: Node {
    public let start: String.Index
    public let end: String.Index
    public let keyword: Syntax
    public let target: Target
    public let equals: Syntax?
    public let value: Declaration.Value
    
    public var description: String {
        "\(keyword.description) \(target.description) \(equals?.description ?? "=") \(value.description)"
    }

    public enum Target: Node {
        case variableRef(VariableRef)
        case junk(Junk)
        
        public var description: String {
            switch self {
            case .variableRef(let wrappedNode): wrappedNode.description
            case .junk(let wrappedNode): wrappedNode.description
            }
        }
        
        public var start: String.Index {
            switch self {
            case .variableRef(let wrappedNode): wrappedNode.start
            case .junk(let wrappedNode): wrappedNode.start
            }
        }
        
        public var end: String.Index {
            switch self {
            case .variableRef(let wrappedNode): wrappedNode.end
            case .junk(let wrappedNode): wrappedNode.end
            }
        }
    }
}

public struct Variant: Node {
    public let start: String.Index
    public let end: String.Index
    public let keys: [Key]
    public let value: Pattern
    
    public var description: String {
        keys.map({ $0.description + " " }).joined() + value.bracedDescription
    }

    public enum Key: Node {
        case literal(Literal)
        case catchall(CatchAllKey)
        
        public var description: String {
            switch self {
            case .literal(let wrappedNode): wrappedNode.description
            case .catchall(let wrappedNode): wrappedNode.description
            }
        }
        
        public var start: String.Index {
            switch self {
            case .literal(let wrappedNode): wrappedNode.start
            case .catchall(let wrappedNode): wrappedNode.start
            }
        }
        
        public var end: String.Index {
            switch self {
            case .literal(let wrappedNode): wrappedNode.end
            case .catchall(let wrappedNode): wrappedNode.end
            }
        }
    }
}

public struct CatchAllKey: Node {
    /** position of the `*` */
    public let start: String.Index
    public let end: String.Index
    
    public var description: String {
        "*"
    }
}

public typealias Braces = (opening: Syntax, closing: Syntax?)

public struct Pattern: Node {
    public let start: String.Index
    public let end: String.Index
    public let body: [BodyElement]
    public let braces: Braces?
    
    public var description: String {
        body.map { $0.description }.joined()
    }
    
    public var bracedDescription: String {
        (braces?.opening.description ?? "{{") + description + (braces?.closing?.description ?? "}}")
    }

    public enum BodyElement: Node {
        case text(Text)
        case expression(Expression)
        
        public var description: String {
            switch self {
            case .text(let wrappedNode): wrappedNode.description
            case .expression(let wrappedNode): wrappedNode.description
            }
        }
        
        public var start: String.Index {
            switch self {
            case .text(let wrappedNode): wrappedNode.start
            case .expression(let wrappedNode): wrappedNode.start
            }
        }
        
        public var end: String.Index {
            switch self {
            case .text(let wrappedNode): wrappedNode.end
            case .expression(let wrappedNode): wrappedNode.end
            }
        }
    }
}

public struct Text: Node {
    public let start: String.Index
    public let end: String.Index
    public let value: String
    
    public var description: String {
        value.replacing(/[\\|]/, with: { "\\\($0.output)" })
    }
}

public struct Expression: Node {
    public let start: String.Index
    public let end: String.Index
    public let braces: Braces?
    public let arg: SimpleValue?
    public let functionRef: FuncRef?
    public let markup: Markup?
    public let attributes: [Attribute]
    
    public var description: String {
        var str = braces?.opening.description ?? "{"
        if let markup {
            str += markup.description
        } else {
            if let arg {
                str += arg.description
                if functionRef != nil {
                    str += " "
                }
            }
            if let functionRef {
                str += functionRef.description
            }
        }
        for attr in attributes {
            str += " " + attr.description
        }
        return str + (braces?.closing?.description ?? "}")
    }

    public enum FuncRef: Node {
        case function(FunctionRef)
        case junk(Junk)
        
        public var description: String {
            switch self {
            case .function(let wrappedNode): wrappedNode.description
            case .junk(let wrappedNode): wrappedNode.description
            }
        }
        
        public var start: String.Index {
            switch self {
            case .function(let wrappedNode): wrappedNode.start
            case .junk(let wrappedNode): wrappedNode.start
            }
        }
        
        public var end: String.Index {
            switch self {
            case .function(let wrappedNode): wrappedNode.end
            case .junk(let wrappedNode): wrappedNode.end
            }
        }
    }
    
    public enum FuncRefOrMarkup {
        case funcRef(FuncRef)
        case markup(Markup)
    }
}

public enum SimpleValue: Node {
    case literal(Literal)
    case variableRef(VariableRef)
    
    public var description: String {
        switch self {
        case .literal(let wrappedNode): wrappedNode.description
        case .variableRef(let wrappedNode): wrappedNode.description
        }
    }
    
    public var start: String.Index {
        switch self {
        case .literal(let wrappedNode): wrappedNode.start
        case .variableRef(let wrappedNode): wrappedNode.start
        }
    }
    
    public var end: String.Index {
        switch self {
        case .literal(let wrappedNode): wrappedNode.end
        case .variableRef(let wrappedNode): wrappedNode.end
        }
    }
    
    public var isVariableRef: Bool {
        switch self {
        case .literal(_): false
        case .variableRef(_): true
        }
    }
}

public struct Junk: Node {
    public let start: String.Index
    public let end: String.Index
    public let source: String
    
    public var description: String {
        source
    }
}

public struct Literal: Node {
    public let quoted: Bool
    public let start: String.Index
    public let end: String.Index
    public let open: Syntax?
    public let value: String
    public let close: Syntax?
    
    init(
        quoted: Bool,
        start: String.Index,
        end: String.Index,
        open: Syntax? = nil,
        value: String,
        close: Syntax? = nil
    ) {
        self.quoted = quoted
        self.start = start
        self.end = end
        self.open = open
        self.value = value
        self.close = close
    }
    
    public var description: String {
        if !quoted {
            value
        } else {
            (open?.description ?? "|") +
            value.replacing(/[\\|]/, with: { "\\\($0.output)" }) +
            (close?.description ?? "|")
        }
    }
}

public struct VariableRef: Node {
    public let start: String.Index
    public let end: String.Index
    public let open: Syntax
    public let name: String
    
    public var description: String {
        open.description + name
    }
}

public struct FunctionRef: Node {
    public let start: String.Index
    public let end: String.Index
    public let open: Syntax
    public let name: Identifier
    public let options: [Option]
    
    public var description: String {
        open.description +
        name.description +
        options.map({ $0.description }).joined()
    }
}

public struct Markup: Node {
    public let start: String.Index
    public let end: String.Index
    public let open: Syntax
    public let name: Identifier
    public let options: [Option]
    public let close: Syntax?
    
    public var description: String {
        let closing = if let close { " " + close.description } else { "" }
        return open.description +
            name.description +
            options.map({ $0.description }).joined() +
            closing
    }
}

public struct Option: Node {
    /// position at the start of the name
    public let start: String.Index
    public let end: String.Index
    public let name: Identifier
    public let equals: Syntax?
    public let value: SimpleValue
    
    public var description: String {
        name.description + (equals?.description ?? "=") + value.description
    }
}

public struct Attribute: Node {
    public let start: String.Index
    public let end: String.Index
    public let open: Syntax
    public let name: Identifier
    public let equals: Syntax?
    public let value: Literal?
    
    public var description: String {
        let base = "@" + name.description
        if let value {
            return base + (equals?.description ?? "=") + value.description
        } else {
            return base
        }
    }
}

public enum Identifier: CustomStringConvertible {
    case name(Syntax)
    case namespace(Syntax, separator: Syntax)
    case namespacedName(namespace: Syntax, separator: Syntax, name: Syntax)
    
    public var description: String {
        switch self {
        case .name(let syntax):
            syntax.description
        case .namespace(let syntax, let separator):
            syntax.description + separator.description
        case .namespacedName(let namespace, let separator, let name):
            namespace.description + separator.description + name.description
        }
    }
}

public struct Syntax: Node {
    public let value: SyntaxKind
    public let start: String.Index
    public let end: String.Index
    
    public var description: String {
        value.description
    }
}

public enum SyntaxKind: CustomStringConvertible, Equatable {
    case asterisk
    case leftSingleBrace
    case leftDoubleBrace
    case rightSingleBrace
    case rightDoubleBrace
    case verticalBar
    case dollar
    case colon
    case doublecross
    case slash
    case equals
    case atSign
    case identifier(String)
    case keyword(Keyword)
    case empty
    
    public var description: String {
        switch self {
        case .asterisk: "*"
        case .leftSingleBrace: "{"
        case .leftDoubleBrace: "{{"
        case .rightSingleBrace: "}"
        case .rightDoubleBrace: "}}"
        case .verticalBar: "|"
        case .dollar: "$"
        case .colon: ":"
        case .doublecross: "#"
        case .slash: "/"
        case .equals: "="
        case .atSign: "@"
        case .identifier(let string): string
        case .keyword(let keyword): keyword.description
        case .empty: ""
        }
    }
}

public enum Keyword: CustomStringConvertible {
    case match
    case input
    case local
    
    public var description: String {
        switch self {
        case .match: ".match"
        case .input: ".input"
        case .local: ".local"
        }
    }
}
