//
//  FlatEnum.swift
//  FlatBin
//
//  Created by Artem Shimanski on 24.05.2026.
//

@FlatRawCodable
public struct EnumStorage {
    public var caseIndex: UInt32
    public var offset: UInt32
}
