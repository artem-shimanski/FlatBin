//
//  FlatRawCodable.swift
//  FlatBin
//
//  Created by Artem Shimanski on 05.06.2026.
//

public protocol FlatRawCodable: BitwiseCopyable, FlatCodable where Storage == Self, View == FlatRawCodableView<Self> {
}

public struct FlatRawCodableView<Owning: FlatCodable>: FlatView<Owning>, ~Escapable where Owning.Storage == Owning {
    public let pointer: FlatPointer<Owning.Storage>
    
    @inlinable
    @inline(always)
    @_lifetime(copy pointer)
    public init(pointer: FlatPointer<Owning.Storage>) {
        self.pointer = pointer
    }

    @inlinable
    @inline(always)
    public func load() -> Owning {
        pointer.pointee
    }
}

extension FlatRawCodable {
    @inlinable
    @inline(always)
    public init(pointer: FlatPointer<Storage>) {
        self = pointer.pointee
    }

    @inlinable
    @inline(always)
    public func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
        storage = self
    }
}

