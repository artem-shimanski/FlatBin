//
//  FlatBinMacros.swift
//  FlatBin
//
//  Created by Artem Shimanski on 17.05.2026.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FlatBinPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        FlatCodableMacro.self,
        FlatRawCodableMacro.self,
        FlatRawMacro.self,
        FlatSharedMacro.self
    ]
}
