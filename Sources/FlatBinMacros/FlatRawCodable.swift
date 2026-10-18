//
//  FlatRawCodable.swift
//  FlatBin
//
//  Created by Artem Shimanski on 17.05.2026.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct FlatRawCodableMacro: ExtensionMacro, PeerMacro {
    
    public static func expansion(of node: AttributeSyntax,
                                 attachedTo declaration: some DeclGroupSyntax,
                                 providingExtensionsOf type: some TypeSyntaxProtocol,
                                 conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        
        let extensionDecl = try ExtensionDeclSyntax("extension \(type.trimmed): FlatRawCodable {}")
        return [extensionDecl]
    }
    
    public static func expansion(
      of node: AttributeSyntax,
      providingPeersOf declaration: some DeclSyntaxProtocol,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

public struct FlatRawMacro: PeerMacro {
    
    public static func expansion(
      of node: AttributeSyntax,
      providingPeersOf declaration: some DeclSyntaxProtocol,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

public struct FlatSharedMacro: PeerMacro {
    
    public static func expansion(
      of node: AttributeSyntax,
      providingPeersOf declaration: some DeclSyntaxProtocol,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

