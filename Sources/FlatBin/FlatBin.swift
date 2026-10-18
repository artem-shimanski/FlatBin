//
//  FlatBin.swift
//  FlatBin
//
//  Created by Artem Shimanski on 12.06.2026.
//

@attached(member, names: named(encode(to:with:)), named(init(pointer:)), named(Storage), named(View), named(Payload))
@attached(extension, conformances: FlatCodable)
public macro FlatCodable() = #externalMacro(module: "FlatBinMacros", type: "FlatCodableMacro")

@attached(extension, conformances: FlatRawCodable)
public macro FlatRawCodable() = #externalMacro(module: "FlatBinMacros", type: "FlatRawCodableMacro")

@attached(peer)
public macro FlatRaw() = #externalMacro(module: "FlatBinMacros", type: "FlatRawMacro")

@attached(peer)
public macro FlatShared() = #externalMacro(module: "FlatBinMacros", type: "FlatSharedMacro")
