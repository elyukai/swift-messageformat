//
//  Types.swift
//  MessageFormat
//
//  Created by Lukas Obermann on 24.11.26.
//

import Foundation
import MessageFormatCST

/// A node in a message data model.
public enum Node {
    case declaration(Declaration)
    case variant(Variant)
    case catchAllKey(CatchAllKey)
    case expression(Expression)
    case literal(Literal)
    case variableRef(VariableRef)
    case functionRef(FunctionRef)
    case markup(Markup)
    
    var start: String.Index? {
        switch self {
        case .declaration(let node): node.cst?.start
        case .variant(let node): node.cst?.start
        case .catchAllKey(let node): node.cst?.start
        case .expression(let node): node.cst?.start
        case .literal(let node): node.cst?.start
        case .variableRef(let node): node.cst?.start
        case .functionRef(let node): node.cst?.start
        case .markup(let node): node.cst?.start
        }
    }
    
    var end: String.Index? {
        switch self {
        case .declaration(let node): node.cst?.end
        case .variant(let node): node.cst?.end
        case .catchAllKey(let node): node.cst?.end
        case .expression(let node): node.cst?.end
        case .literal(let node): node.cst?.end
        case .variableRef(let node): node.cst?.end
        case .functionRef(let node): node.cst?.end
        case .markup(let node): node.cst?.end
        }
    }
}

public protocol NodeConvertible {
    func asNode() -> Node
}

protocol CSTBacked {
    var cst: (any MessageFormatCST.Node)? { get }
}

/// The representation of a single message. See ``parseMessage``.
public enum Message: CustomStringConvertible {
    case pattern(PatternMessage)
    case select(SelectMessage)
    
    public var description: String {
        switch self {
        case .pattern(let patternMessage): patternMessage.description
        case .select(let selectMessage): selectMessage.description
        }
    }
    
    public var declarations: [Declaration] {
        switch self {
        case .pattern(let patternMessage): patternMessage.declarations
        case .select(let selectMessage): selectMessage.declarations
        }
    }
}

/// A single message with no variants.
public struct PatternMessage: CustomStringConvertible, CSTBacked {
    public let declarations: [Declaration]
    public let pattern: Pattern
    public let comment: String?
    let _cst: CSTKind?
    var cst: (any MessageFormatCST.Node)? { _cst }
    
    public init(declarations: [Declaration], pattern: Pattern, comment: String? = nil) {
        self.declarations = declarations
        self.pattern = pattern
        self.comment = comment
        self._cst = nil
    }
    
    init(declarations: [Declaration], pattern: Pattern, comment: String? = nil, cst: CSTKind) {
        self.declarations = declarations
        self.pattern = pattern
        self.comment = comment
        self._cst = cst
    }
    
    public var description: String {
        declarations.map({ $0.description }).joined() +
        pattern.description(inQuotes: !declarations.isEmpty)
    }
    
    enum CSTKind: MessageFormatCST.Node {
        
        case simple(MessageFormatCST.SimpleMessage)
        case complex(MessageFormatCST.ComplexMessage)
        
        var start: String.Index {
            switch self {
            case .simple(let simple): simple.start
            case .complex(let complex): complex.start
            }
        }
        
        var end: String.Index {
            switch self {
            case .simple(let simple): simple.end
            case .complex(let complex): complex.end
            }
        }
        
        var description: String {
            switch self {
            case .simple(let simple): simple.description
            case .complex(let complex): complex.description
            }
        }
    }
}

/// A message may declare any number of input and local variables, each with a value defined by an ``Expression``. The `name` of each declaration must be unique within the ``Message``.
public enum Declaration: CustomStringConvertible, NodeConvertible, CSTBacked {
    typealias CSTNode = any MessageFormatCST.Node
    
    case input(InputDeclaration)
    case local(LocalDeclaration)
    
    public var description: String {
        switch self {
        case .input(let input): input.description
        case .local(let local): local.description
        }
    }
    
    public func asNode() -> Node {
        .declaration(self)
    }
    
    public var name: String {
        switch self {
        case .input(let input): input.name
        case .local(let local): local.name
        }
    }
    
    public var value: Expression {
        switch self {
        case .input(let input): input.value
        case .local(let local): local.value
        }
    }
    
    public var isLocal: Bool {
        switch self {
        case .input(_): false
        case .local(_): true
        }
    }
    
    var cst: any MessageFormatCST.Node? {
        switch self {
        case .input(let input): input.cst
        case .local(let local): local.cst
        }
    }
}

public struct InputDeclaration: CustomStringConvertible {
    public let name: String
    public let value: Expression
    let cst: MessageFormatCST.InputDeclaration?
    
    public init(name: String, value: Expression) {
        self.name = name
        self.value = value
        self.cst = nil
    }
    
    init(name: String, value: Expression, cst: MessageFormatCST.InputDeclaration?) {
        self.name = name
        self.value = value
        self.cst = cst
    }
    
    public var description: String {
        ".input \(value.description)"
    }
}

public struct LocalDeclaration: CustomStringConvertible {
    public let name: String
    public let value: Expression
    let cst: MessageFormatCST.LocalDeclaration?
    
    public init(name: String, value: Expression) {
        self.name = name
        self.value = value
        self.cst = nil
    }
    
    init(name: String, value: Expression, cst: MessageFormatCST.LocalDeclaration) {
        self.name = name
        self.value = value
        self.cst = cst
    }
    
    public var description: String {
        ".local $\(name) = \(value.description)"
    }
}

/// ``SelectMessage`` generalises the plural, selectordinal and select argument types of MessageFormat 1. Each case is defined by a key of one or more string identifiers, and selection between them is made according to the values of a corresponding number of ``SelectMessage/selectors``.
///
/// Pattern Selection picks the best match among the ``SelectMessage/variants``. The result of the selection is always a single Pattern.
public struct SelectMessage: CustomStringConvertible {
    public let declarations: [Declaration]
    public let selectors: [VariableRef]
    public let variants: [Variant]
    public let comment: String?
    let cst: MessageFormatCST.SelectMessage?
    
    public init(declarations: [Declaration], selectors: [VariableRef], variants: [Variant], comment: String? = nil) {
        self.declarations = declarations
        self.selectors = selectors
        self.variants = variants
        self.comment = comment
        self.cst = nil
    }
    
    init(declarations: [Declaration], selectors: [VariableRef], variants: [Variant], comment: String? = nil, cst: MessageFormatCST.SelectMessage) {
        self.declarations = declarations
        self.selectors = selectors
        self.variants = variants
        self.comment = comment
        self.cst = cst
    }
    
    public var description: String {
        declarations.map({ $0.description }).joined() +
        ".match\(selectors.map({ " \($0.description)" }))" +
        variants.map({ "\n\($0.description)" }).joined()
    }
}

public struct Variant: CustomStringConvertible, NodeConvertible, CSTBacked {
    public let keys: [Key]
    public let value: Pattern
    let _cst: MessageFormatCST.Variant?
    var cst: (any MessageFormatCST.Node)? { _cst }
    
    public init(keys: [Key], value: Pattern) {
        self.keys = keys
        self.value = value
        self._cst = nil
    }
    
    init(keys: [Key], value: Pattern, cst: MessageFormatCST.Variant) {
        self.keys = keys
        self.value = value
        self._cst = cst
    }
    
    public var description: String {
        keys.map({ $0.description + " " }).joined() + value.description(inQuotes: true)
    }
    
    public enum Key: CustomStringConvertible, NodeConvertible {
        case literal(Literal)
        case catchAll(CatchAllKey)
        
        public var description: String {
            switch self {
            case .literal(let literal): literal.description
            case .catchAll(_): "*"
            }
        }
        
        public func asNode() -> Node {
            switch self {
            case .literal(let literal): .literal(literal)
            case .catchAll(let catchAll): .catchAllKey(catchAll)
            }
        }
    }
    
    public func asNode() -> Node {
        .variant(self)
    }
}

/// The catch-all key matches all values.
public struct CatchAllKey: NodeConvertible {
    public let value: String?
    let cst: MessageFormatCST.CatchAllKey?
    
    public init(value: String?) {
        self.value = value
        self.cst = nil
    }
    
    init(value: String?, cst: MessageFormatCST.CatchAllKey) {
        self.value = value
        self.cst = cst
    }
    
    public func asNode() -> Node {
        .catchAllKey(self)
    }
}

/// The body of each ``Message`` is composed of a sequence of parts, some of them fixed (Text), others ``Expression`` and ``Markup`` placeholders for values depending on additional data.
public typealias Pattern = [PatternPart]

extension Array where Element == PatternPart {
    public func description(inQuotes quoted: Bool) -> String {
        let actuallyQuoted = if quoted {
            true
        } else if let first, case .text(let text) = first, text.prefixMatch(of: /\s*\./) != nil {
            true
        } else {
            false
        }
        let res = map(\.description).joined()
        return actuallyQuoted ? "{{\(res)}}" : res
    }
}

/// A part of the body of a message. Some of them are fixed (Text), others ``Expression`` and ``Markup`` placeholders for values depending on additional data.
public enum PatternPart: CustomStringConvertible {
    case text(String)
    case expression(Expression)
    case markup(Markup)
    
    public var description: String {
        switch self {
        case .text(let string):
            string.replacing(/[\\{}]/, with: { "\\\($0.output)" })
        case .expression(let expression):
            expression.description
        case .markup(let markup):
            markup.description
        }
    }
}

/// Expressions are used in declarations and as placeholders. Each must include at least an `arg` or a `functionRef`, or both.
public struct Expression: CustomStringConvertible, NodeConvertible, CSTBacked {
    public let attributes: Attributes?
    public let value: ExpressionValue
    let _cst: MessageFormatCST.Expression?
    var cst: (any MessageFormatCST.Node)? { _cst }
    
    public init(attributes: Attributes?, value: ExpressionValue) {
        self.attributes = attributes
        self.value = value
        self._cst = nil
    }
    
    init(attributes: Attributes?, value: ExpressionValue, cst: MessageFormatCST.Expression) {
        self.attributes = attributes
        self.value = value
        self._cst = cst
    }
    
    var arg: SimpleValue? {
        value.arg
    }
    
    var ref: FunctionRef? {
        value.ref
    }
    
    public var description: String {
        [value.arg?.description, value.ref?.description]
            .compactMap { $0 }
            .joined(separator: " ") + (attributes?.description ?? "")
    }
    
    public func asNode() -> Node {
        .expression(self)
    }
}

public enum ExpressionValue {
    case arg(SimpleValue)
    case functionRef(FunctionRef)
    case both(arg: SimpleValue, functionRef: FunctionRef)
    
    var arg: SimpleValue? {
        switch self {
        case .arg(let arg), .both(let arg, _): arg
        case .functionRef(_): nil
        }
    }
    
    var ref: FunctionRef? {
        switch self {
        case .functionRef(let ref), .both(_, let ref): ref
        case .arg(_): nil
        }
    }
}

public enum SimpleValue: CustomStringConvertible, NodeConvertible {
    case literal(Literal)
    case variableRef(VariableRef)
    
    public var isVariable: Bool { if case .variableRef(_) = self { true } else { false } }
    
    public var description: String {
        switch self {
        case .literal(let literal): literal.description
        case .variableRef(let variableRef): variableRef.description
        }
    }
    
    public func asNode() -> Node  {
        switch self {
        case .literal(let literal): .literal(literal)
        case .variableRef(let variableRef): .variableRef(variableRef)
        }
    }
}

/// An immediately defined literal value.
///
/// Always contains a string value. In ``FunctionRef`` arguments and options, the expected type of the value may result in the value being further parsed as a boolean or a number by the function handler.
public struct Literal: CustomStringConvertible, NodeConvertible, CSTBacked {
    public let value: String
    let _cst: MessageFormatCST.Literal?
    var cst: (any MessageFormatCST.Node)? { _cst }
    
    public init(value: String) {
        self.value = value
        self._cst = nil
    }
    
    init(value: String, cst: MessageFormatCST.Literal) {
        self.value = value
        self._cst = cst
    }
    
    public var description: String {
        if isValidUnquotedLiteral(str: value) { return value }
        let esc = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "|", with: "\\|")
        return "|\(esc)|"
    }
    
    public func asNode() -> Node {
        .literal(self)
    }
}

/// The value of a ``VariableRef`` is defined by a declaration, or by the `msgParams` argument of a ``MessageFormat/format`` or ``MessageFormat/formatToParts`` call.
public struct VariableRef: CustomStringConvertible, NodeConvertible, CSTBacked {
    public let name: String
    let _cst: MessageFormatCST.VariableRef?
    var cst: (any MessageFormatCST.Node)? { _cst }
    
    public init(name: String) {
        self.name = name
        self._cst = nil
    }
    
    init(name: String, cst: MessageFormatCST.VariableRef) {
        self.name = name
        self._cst = cst
    }
    
    public var description: String {
        "$\(name)"
    }
    
    public func asNode() -> Node {
        .variableRef(self)
    }
}

/// To resolve a ``FunctionRef``, a ``MessageFunction`` is called.
///
/// The `name` identifies one of the ``DefaultFunctions`` or a function included in the ``MessageFormatOptions/functions``.
public struct FunctionRef: CustomStringConvertible, NodeConvertible, CSTBacked {
    public let name: String
    public let options: Options?
    let _cst: MessageFormatCST.FunctionRef?
    var cst: (any MessageFormatCST.Node)? { _cst }
    
    public init(name: String, options: Options?) {
        self.name = name
        self.options = options
        self._cst = nil
    }
    
    init(name: String, options: Options?, cst: MessageFormatCST.FunctionRef) {
        self.name = name
        self.options = options
        self._cst = cst
    }
    
    public var description: String {
        ":\(name)\(options?.description ?? "")"
    }
    
    public func asNode() -> Node {
        .functionRef(self)
    }
}

/// Markup placeholders can span ranges of other pattern elements, or represent other inline elements.
///
/// The `name` identifies the markup part, which will be included in the result along with any `options`.
///
/// When formatted to string, all markup will format as an empty string. To use markup, format to parts and post-process the formatted results.
public struct Markup: CustomStringConvertible, NodeConvertible, CSTBacked {
    public let kind: Kind
    public let name: String
    public let options: Options?
    public let attributes: Attributes?
    let _cst: MessageFormatCST.Markup?
    var cst: (any MessageFormatCST.Node)? { _cst }
    
    public enum Kind {
        case open, standalone, close
    }
    
    public init(kind: Kind, name: String, options: Options?, attributes: Attributes?) {
        self.kind = kind
        self.name = name
        self.options = options
        self.attributes = attributes
        self._cst = nil
    }
    
    init(kind: Kind, name: String, options: Options?, attributes: Attributes?, cst: MessageFormatCST.Markup) {
        self.kind = kind
        self.name = name
        self.options = options
        self.attributes = attributes
        self._cst = cst
    }
    
    public var description: String {
        (kind == .close ? "{/" : "{#") +
        name +
        (options?.description ?? "") +
        (attributes?.description ?? "") +
        (kind == .standalone ? " /}" : "}")
    }
    
    public func asNode() -> Node {
        .markup(self)
    }
}

/// The options of ``FunctionRef`` and ``Markup``.
public typealias Options = [String: SimpleValue]

extension Dictionary where Key == String, Value == SimpleValue {
    public var description: String {
        map({ " \($0.key)=\($0.value.description)" }).joined()
    }
}

/// The attributes of ``Expression`` and ``Markup``.
public typealias Attributes = [String: Attribute]

extension Dictionary where Key == String, Value == Attribute {
    public var description: String {
        map({ " @\($0.key)\($0.value.description)" }).joined()
    }
}

public enum Attribute: CustomStringConvertible {
    case literal(Literal)
    case present
    
    public var description: String {
        switch self {
        case .literal(let literal): "=" + literal.description
        case .present: ""
        }
    }
}
