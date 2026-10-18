//
//  FlatCodableMacro.swift
//  FlatBin
//
//  Created by Artem Shimanski on 17.05.2026.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

let knownRawValueTypes: Set<String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "String",
]

let knownBitwiseCopyableTypes: Set<String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Float", "Float16", "Float32", "Float64", "CGFloat", "Double"
]


struct Attributes {
    struct Flags: OptionSet {
        let rawValue: UInt32
        static let raw = Flags(rawValue: 1 << 0)
        static let shared = Flags(rawValue: 1 << 1)
    }
    var flags: Flags = []
        
    init() {}
    
    init(_ attributes: AttributeListSyntax) {
        flags = []
        for i in attributes {
            guard let attribute = i.as(AttributeSyntax.self) else {continue}
            let attributeName = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text
            if attributeName == "FlatRaw" {
                flags.insert(.raw)
            }
            else if attributeName == "FlatShared" {
                flags.insert(.shared)
            }
        }
    }
}

struct Property {
    enum PropertyType {
        case type(String)
        case array(element: String)
        case dictionary(key: String, value: String)
        case optional(String)
    }
    var type: PropertyType
    var name: String
    var typeName: String {
        switch type {
        case let .type(type):
            return type
        case let .array(element: element):
            return "[\(element)]"
        case let .dictionary(key: key, value: value):
            return "[\(key): \(value)]"
        case let .optional(type):
            return "\(type)?"
        }
    }
    
    var storageType: String {
        if isShared {
            switch type {
            case let .type(type):
                return "FlatReference<\(type).Storage>"
            case let .array(element: element):
                return "FlatSharedArray<\(element)>.Storage"
            case let .dictionary(key: key, value: value):
                return "FlatSharedDictionary<\(key), \(value)>.Storage"
            case let .optional(type):
                return "FlatReference<\(type)?.Storage>"
            }
        }
        return "\(typeName).Storage"
    }
    
    var viewType: String {
        if isShared {
            switch type {
            case .type, .optional:
                break
            case let .array(element: element):
                return "FlatSharedArray<\(element)>.View"
            case let .dictionary(key: key, value: value):
                return "FlatSharedDictionary<\(key), \(value)>.View"
            }
        }
        return "\(typeName).View"
    }
    
    var getterType: String {
        switch type {
        case let .optional(type):
            return "\(type).View?"
        default:
            return viewType
        }
    }
    
    var attributes = Attributes()
    
    var isBitwiseCodable: Bool {
        knownBitwiseCopyableTypes.contains(typeName) || attributes.flags.contains(.raw)
    }
    var isShared: Bool {
        attributes.flags.contains(.shared)
    }
    var isArray: Bool {
        if case .array = type {return true}
        return false
    }
    var isDictionary: Bool {
        if case .dictionary = type {return true}
        return false
    }
    var isOptional: Bool {
        if case .optional = type {return true}
        return false
    }

}


public struct FlatCodableMacro: MemberMacro, ExtensionMacro {
    
    public static func expansion(of node: SwiftSyntax.AttributeSyntax, providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax, conformingTo protocols: [SwiftSyntax.TypeSyntax], in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
        let isFrozen = declaration.attributes.contains{$0.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "frozen"}

        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return try expandStruct(structDecl, isFrozen: isFrozen)
        }
        else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            if let rawType = detectRawValueType(enumDecl) {
                return try expandRawEnum(enumDecl, type: rawType)
            }
            else {
                return try expandEnum(enumDecl, isFrozen: isFrozen)
            }
        }
        else {
            fatalError("FlatCodable error")
        }
    }
        
    private static func detectRawValueType(_ decl: EnumDeclSyntax) -> String? {
        
        guard let inheritance = decl.inheritanceClause else {
            return nil
        }
        for inherited in inheritance.inheritedTypes {
            let typeName = inherited.type.trimmedDescription
            if knownRawValueTypes.contains(typeName) {
                return typeName
            }
        }
        return nil
    }
    
    public static func expansion(of node: AttributeSyntax,
                                 attachedTo declaration: some DeclGroupSyntax,
                                 providingExtensionsOf type: some TypeSyntaxProtocol,
                                 conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        
        let extensionDecl = try ExtensionDeclSyntax("extension \(type.trimmed): FlatCodable {}")
        return [extensionDecl]
    }
    
    private static func expandStruct(_ decl: StructDeclSyntax, isFrozen: Bool) throws -> [DeclSyntax] {
        
        let properties = decl.memberBlock.members.compactMap { member -> Property? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmedDescription,
                  let typeAnnotation = binding.typeAnnotation
            else { return nil }
            
            if let accessor = binding.accessorBlock {
                if accessor.description.contains("get") { return nil }
            }
            let attributes = Attributes(varDecl.attributes)
            let isStatic = varDecl.modifiers.contains {
                $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class)
            }
            if isStatic { return nil }

            let type: Property.PropertyType
            
            if let arrayType = typeAnnotation.type.as(ArrayTypeSyntax.self) {
                type = .array(element: arrayType.element.trimmedDescription)
            }
            else if let identifierType = typeAnnotation.type.as(IdentifierTypeSyntax.self),
                    identifierType.name.text == "Array",
                    let element = identifierType.genericArgumentClause?.arguments.first {
                type = .array(element: element.argument.trimmedDescription)
            }
            else if let dicType = typeAnnotation.type.as(DictionaryTypeSyntax.self) {
                type = .dictionary(key: dicType.key.trimmedDescription, value: dicType.value.trimmedDescription)
            }
            else if let identifierType = typeAnnotation.type.as(IdentifierTypeSyntax.self),
                    identifierType.name.text == "Dictionary",
                    let genericArgs = identifierType.genericArgumentClause?.arguments,
                    let key = genericArgs.first,
                    let value = genericArgs.dropFirst().first {
                
                type = .dictionary(key: key.trimmedDescription, value: value.trimmedDescription)
            }
            else if let optional = typeAnnotation.type.as(OptionalTypeSyntax.self) {
                type = .optional(optional.wrappedType.trimmedDescription)
            }

            else {
                type = .type(typeAnnotation.type.trimmedDescription)
            }
            
            return Property(type: type, name: name, attributes: attributes)
        }
        return expandStruct(name: decl.name.trimmedDescription, properties: properties, isFrozen: isFrozen)
    }
    
    private static func expandStruct(name: String, properties: [Property], isFrozen: Bool) -> [DeclSyntax] {
        [storageDecl(properties, isFrozen: isFrozen), encodeDecl(properties), viewDecl(properties, typeName: name), initDecl(properties)]
    }

    private static func storageDecl(_ properties: [Property], isFrozen: Bool) -> DeclSyntax {
        let lines = properties
            .map {
                "public var \($0.name): \($0.storageType)"
            }
            .joined(separator: "\n")
        
        return """
        \(raw: isFrozen ? "@frozen " : "")public struct Storage: BitwiseCopyable {
        \(raw: lines)
    }
"""
    }
    
    private static func encodeDecl(_ properties: [Property]) -> DeclSyntax {
        let lines = properties
            .map {
                $0.isShared ?
                (
                    $0.isArray ? "FlatSharedArray(elements: \($0.name)).encode(to: &storage.\($0.name), with: encoder)" :
                    $0.isDictionary ? "FlatSharedDictionary(elements: \($0.name)).encode(to: &storage.\($0.name), with: encoder)" :
                """
                storage.\($0.name) = encoder.writeIndirect(of: \($0.typeName).self) { [\($0.name)] indirect in
                    var indirect = indirect
                    indirect.write(\($0.name))
                }
                """) :
                $0.isBitwiseCodable ?
                "storage.\($0.name) = \($0.name)" :
                "\($0.name).encode(to: &storage.\($0.name), with: encoder)"
            }
            .joined(separator: "\n")
        
        return """
    @inlinable
    @inline(always)
    borrowing public func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
        \(raw: lines)
    }
"""
    }
    
    private static func viewDecl(_ properties: [Property], typeName: String) -> DeclSyntax {
        let varLines = properties
            .map {
                $0.isBitwiseCodable ?
"""
        public var \($0.name): \($0.typeName) {
            @inlinable
            @inline(always)
            get {
                pointer[\\.\($0.name)]\($0.isShared ? ".resolved()" : "").pointee
            }
        }
""" :
"""
        public var \($0.name): \($0.getterType) {
            @inlinable
            @inline(always)
            @_lifetime(copy self)
            get {
                _overrideLifetime(\($0.viewType)(pointer: pointer[\\.\($0.name)]\($0.isShared && !$0.isArray && !$0.isDictionary ? ".resolved()" : ""))\($0.isOptional ? ".value" : ""), copying: self)
            }
        }        
"""
            }.joined(separator: "\n")
        
        return """
    public struct View: FlatView<\(raw: typeName)>, ~Escapable {
        public let pointer: FlatPointer<Storage>
     
        @inlinable
        @inline(always)
        @_lifetime(copy pointer)
        public init(pointer: FlatPointer<Storage>) {
            self.pointer = pointer
        }

\(raw: varLines)
    }
"""
    }
    
    private static func initDecl(_ properties: [Property]) -> DeclSyntax {
        let initLines = properties
            .map {
                if $0.isBitwiseCodable {
                    return "\($0.name) = pointer[\\.\($0.name)]\($0.isShared ? ".resolved()" : "").pointee"
                }
                else if $0.isArray && $0.isShared {
                    return "\($0.name) = FlatSharedArray(pointer: pointer[\\.\($0.name)]).elements"
                }
                else if $0.isDictionary && $0.isShared {
                    return "\($0.name) = FlatSharedDictionary(pointer: pointer[\\.\($0.name)]).elements"
                }
                else {
                    return "\($0.name) = .init(pointer: pointer[\\.\($0.name)]\($0.isShared ? ".resolved()" : ""))"
                }
                
            }.joined(separator: "\n")
        return """
             @inlinable
             @inline(always)
             public init(pointer: FlatPointer<Storage>) {
                 \(raw: initLines)
             }
            """
    }
    
    struct CaseInfo {
        var name: String
        var index: Int
        var params: [(name: String?, type: String)]
        var attributes: Attributes
    }
    
    private static func expandRawEnum(_ decl: EnumDeclSyntax, type: String) throws -> [DeclSyntax] {
        let storageDecl: DeclSyntax = "typealias Storage = RawValue"
        let encodeDecl: DeclSyntax = """
        func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
            storage = rawValue
        }
        """
        
        let initDecl: DeclSyntax = """
        init(pointer: FlatPointer<Storage>) {
            self = .init(rawValue: pointer.pointee)!
        }
        """
        return [storageDecl, encodeDecl, initDecl]
    }

    private static func expandEnum(_ decl: EnumDeclSyntax, isFrozen: Bool) throws -> [DeclSyntax] {
        var cases: [CaseInfo] = []
        
        for member in decl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                continue
            }
            for element in caseDecl.elements {
                
                var caseInfo = CaseInfo(name: element.name.trimmedDescription, index: cases.endIndex, params: [], attributes: Attributes(caseDecl.attributes))
                
                if let paramClause = element.parameterClause {
                    for param in paramClause.parameters {
                        let typeName = param.type.trimmedDescription
                        let label = param.firstName?.trimmedDescription
                        caseInfo.params.append((label, typeName))
                    }
                }
                cases.append(caseInfo)
            }
        }
        let storage: DeclSyntax = "typealias Storage = EnumStorage"

        return try [storage, casePayload(cases, isFrozen: isFrozen), caseInit(cases), caseEncode(cases)].map{$0.formatted().as(DeclSyntax.self)!}
    }
    
    private static func casePayload(_ cases: [CaseInfo], isFrozen: Bool) throws -> DeclSyntax {
        var structs: [StructDeclSyntax] = []
        for caseInfo in cases where !caseInfo.params.isEmpty {
            let properties = caseInfo.params.enumerated().map { (offset, element) in
                Property(type: .type(element.type), name: element.name ?? "v\(offset)")
            }
            
            let decls = caseInfo.attributes.flags.contains(.raw) ? [] : expandStruct(name: caseInfo.name, properties: properties, isFrozen: isFrozen)
            let proto = caseInfo.attributes.flags.contains(.raw) ? "FlatRawCodable" : "FlatCodable"
            
            let structDecl = try StructDeclSyntax("\(raw: isFrozen ? "@frozen " : "")public struct \(raw: caseInfo.name): \(raw: proto)" ) {
                for property in properties {
                    "public var \(raw: property.name): \(raw: property.typeName)"
                }
            """
            @inlinable
            @inline(always)
            public init (\(raw: properties.map{"\($0.name): \($0.typeName)"}.joined(separator: ", "))) {
                \(raw: properties.map{"self.\($0.name) = \($0.name)"}.joined(separator: "\n\t"))
            }
            """
                for decl in decls {
                    decl.with(\.trailingTrivia, .newline)
                }
            }
            structs.append(structDecl.with(\.trailingTrivia, .newline))
        }
        let payloadDecl = try EnumDeclSyntax("public enum Payload") {
            for decl in structs {
                decl.with(\.trailingTrivia, .newline)
            }
        }
        return DeclSyntax(payloadDecl)
    }
    
    private static func caseInit(_ cases: [CaseInfo]) throws -> DeclSyntax {
        var rows: [String] = []
        for caseInfo in cases {
            rows.append("case \(caseInfo.index):")
            if caseInfo.params.isEmpty {
                rows.append("   self = .\(caseInfo.name)")
            }
            else {
                rows.append("let payload = Payload.\(caseInfo.name)(pointer: FlatPointer(base: pointer.base, offset: Int(pointer[\\.offset].pointee)))")
                let properties = caseInfo.params.enumerated().map { (offset, element) in
                    (name: element.name ?? "v\(offset)", type: element.type, caseName: element.name)
                }
                var args: [String] = []
                for (name, _, caseName) in properties {
                    if let caseName {
                        args.append("\(caseName): payload.\(name)")
                    }
                    else {
                        args.append("payload.\(name)")
                    }
                }
                rows.append("   self = .\(caseInfo.name)(\(args.joined(separator: ", ")))")
            }
        }
        return """
            public init(pointer: FlatPointer<Storage>) {
                switch pointer[\\.caseIndex].pointee {
                \(raw: rows.joined(separator: "\n\t"))
                default:
                    fatalError("Invalid caseIndex: \\(pointer[\\.caseIndex].pointee)")
                }
            }
            """
    }

    private static func caseEncode(_ cases: [CaseInfo]) throws -> DeclSyntax {
        var rows: [String] = []
        for caseInfo in cases {
            if caseInfo.params.isEmpty {
                rows.append("""
                case .\(caseInfo.name):
                    storage.caseIndex = \(caseInfo.index)
                """)
            }
            else {
                let properties = caseInfo.params.enumerated().map { (offset, element) in
                    (name: element.name ?? "v\(offset)", type: element.type)
                }
                rows.append("")
                rows.append("""
                    case let .\(caseInfo.name)(\(properties.map{$0.name}.joined(separator: ", "))):
                        storage.caseIndex = \(caseInfo.index)
                        storage.offset = encoder.writeIndirect(of: Payload.\(caseInfo.name).self) { indirect in
                            var indirect = indirect
                            indirect.write(Payload.\(caseInfo.name)(\(properties.map{"\($0.name): \($0.name)"}.joined(separator: ", "))))
                        }.offset
                    """)
            }
        }
        
        return """
            borrowing public func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
                switch self {
                \(raw: rows.joined(separator: "\n\t"))
                }
            }
            """
    }
}

