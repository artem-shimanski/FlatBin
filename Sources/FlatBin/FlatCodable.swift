//
//  FlatCodable.swift
//  FlatBin
//
//  Created by Artem Shimanski on 13.05.2026.
//

import Foundation



public protocol FlatCodable {
    associatedtype Storage: BitwiseCopyable
    associatedtype View: FlatView<Self>, ~Escapable = FlatDefaultView<Self>
    init(pointer: FlatPointer<Storage>)
    func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder)
}




extension UInt: FlatRawCodable, FlatHashable {}
extension UInt8: FlatRawCodable, FlatHashable {}
extension UInt16: FlatRawCodable, FlatHashable {}
extension UInt32: FlatRawCodable, FlatHashable {}
extension UInt64: FlatRawCodable, FlatHashable {}
extension Int: FlatRawCodable, FlatHashable {}
extension Int8: FlatRawCodable, FlatHashable {}
extension Int16: FlatRawCodable, FlatHashable {}
extension Int32: FlatRawCodable, FlatHashable {}
extension Int64: FlatRawCodable, FlatHashable {}
extension Float: FlatRawCodable {}
extension Double: FlatRawCodable {}


