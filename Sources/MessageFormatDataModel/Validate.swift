//
//  Validate.swift
//  MessageFormat
//
//  Created by Lukas Obermann on 24.11.26.
//

import MessageFormatCST



/// Ensure that the `msg` data model is _valid_, throwing a ``MessageDataModelError`` on errors.
///
/// Detects the following errors:
//
/// - ``MessageDataModelError/Kind/keyMismatch``: The number of keys on a _variant_ does not equal
///   the number of _selectors_.
/// - ``MessageDataModelError/Kind/missingFallback``:  The message does not include a _variant_ with
///   only catch-all keys.
/// - ``MessageDataModelError/Kind/missingSelectorAnnotation``: A _selector_ does not contains a
///   _variable_ that directly or indirectly reference a _declaration_ with a _function_.
/// - ``MessageDataModelError/Kind/duplicateDeclaration``: A _variable_ appears in two
///   _declarations_.
/// - ``MessageDataModelError/Kind/duplicateVariant``: The same list of _keys_ is used for more than
///   one _variant_.
///
/// - Returns: The sets of runtime `functions` and `variables` used by the message.
public func validate(msg: Message) throws -> (functions: Set<String>, variables: Set<String>) {
    try validate(msg: msg) { type, node in
        throw MessageDataModelError(type: type, node: node)
    }
}

/// Ensure that the `msg` data model is _valid_, calling `onError` on errors.
///
/// If `onError` is not defined, a ``MessageDataModelError`` will be thrown on error.
///
/// Detects the following errors:
//
/// - ``MessageDataModelError/Kind/keyMismatch``: The number of keys on a _variant_ does not equal
///   the number of _selectors_.
/// - ``MessageDataModelError/Kind/missingFallback``:  The message does not include a _variant_ with
///   only catch-all keys.
/// - ``MessageDataModelError/Kind/missingSelectorAnnotation``: A _selector_ does not contains a
///   _variable_ that directly or indirectly reference a _declaration_ with a _function_.
/// - ``MessageDataModelError/Kind/duplicateDeclaration``: A _variable_ appears in two
///   _declarations_.
/// - ``MessageDataModelError/Kind/duplicateVariant``: The same list of _keys_ is used for more than
///   one _variant_.
///
/// - Returns: The sets of runtime `functions` and `variables` used by the message.
public func validate<Err>(msg: Message, onError: @escaping (MessageDataModelError.Kind, Node) throws(Err) -> Void) throws(Err) -> (functions: Set<String>, variables: Set<String>) {
    let state = ValidationState()
    
    try msg.visit(by: ValidationVisitor(state: state, onError: onError))
    
    if let missingFallback = state.missingFallback {
        try onError(.missingFallback, missingFallback)
    }
    
    for lv in state.localVars {
        state.variables.remove(lv)
    }
    
    return (functions: state.functions, variables: state.variables)
}

fileprivate class ValidationState {
    var selectorCount = 0
    var missingFallback: Node? = nil
    
    // Tracks directly & indirectly annotated variables for `missingSelectorAnnotation`
    var annotated: Set<String> = []
    
    // Tracks declared variables for `duplicateDeclaration`
    var declared: Set<String> = []
    
    var functions: Set<String> = []
    var localVars: Set<String> = []
    var variables: Set<String> = []
    var variants: Set<String> = []
    
    var setArgAsDeclared = true
}

fileprivate class ValidationVisitor<E: Error>: MessageVisitor {
    typealias Err = E
    
    let state: ValidationState
    let onError: (MessageDataModelError.Kind, Node) throws(Err) -> Void
    
    fileprivate init(state: ValidationState, onError: @escaping (MessageDataModelError.Kind, Node) throws(Err) -> Void) {
        self.state = state
        self.onError = onError
    }
    
    fileprivate func visitDeclaration(_ decl: Declaration) throws(Err) -> End<Err> {
        if decl.name.isEmpty { return nil }
        
        let addAnnotated = if decl.value.ref != nil {
            true
        } else if case .local(let local) = decl,
                  case .variableRef(let variable) = local.value.arg,
                  state.annotated.contains(variable.name) {
            true
        } else { false }
        if addAnnotated { state.annotated.insert(decl.name) }
        
        if case .local(let local) = decl { state.localVars.insert(local.name) }
        
        state.setArgAsDeclared = decl.isLocal
        return { () throws(Err) in
            if self.state.declared.contains(decl.name) {
                try self.onError(.duplicateDeclaration, decl.asNode())
            } else {
                self.state.declared.insert(decl.name)
            }
        }
    }
    
    fileprivate func visitExpression(_ exp: Expression, in context: VisitContext) throws(Err) -> End<Err> {
        if let ref = exp.ref {
            state.functions.insert(ref.name)
        }
        return nil
    }
    
    fileprivate func visitValue(_ value: SimpleValue,
                    in context: VisitValueContext,
                    at position: VisitValuePosition) throws(Err) -> End<Err> {
        switch value {
        case .literal(_): break
        case .variableRef(let variable):
            state.variables.insert(variable.name)
            switch context {
            case .declaration:
                switch position {
                case .arg: break
                case .attribute, .option:
                    if state.setArgAsDeclared {
                        state.declared.insert(variable.name)
                    }
                }
            case .selector:
                state.selectorCount += 1
                state.missingFallback = variable.asNode()
                if !state.annotated.contains(variable.name) {
                    try onError(.missingSelectorAnnotation, variable.asNode())
                }
            case .placeholder: break
            }
        }
        return nil
    }
    
    fileprivate func visitVariant(_ variant: Variant) throws(Err) -> End<Err> {
        let keys = variant.keys
        if keys.count != state.selectorCount { try onError(.keyMismatch, variant.asNode()) }
        let strKeys = keys.map({
            switch $0 {
            case .catchAll(_): "0"
            case .literal(let literal): literal.value
            }
        }).joined(separator: ",")
        if state.variants.contains(strKeys) { try onError(.duplicateVariant, variant.asNode()) }
        else { state.variants.insert(strKeys) }
        if state.missingFallback != nil,
            keys.allSatisfy({ if case .catchAll(_) = $0 { true } else { false } }) {
            state.missingFallback = nil
        } else {
            state.missingFallback = variant.asNode()
        }
        return nil
    }
}
