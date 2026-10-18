//
//  FlatView.swift
//  FlatBin
//
//  Created by Artem Shimanski on 17.05.2026.
//

public protocol FlatView<Owning>: ~Escapable {
    associatedtype Owning: FlatCodable
    
    var pointer: FlatPointer<Owning.Storage> {@_lifetime(copy self) get}
    
    @_lifetime(copy pointer)
    init(pointer: FlatPointer<Owning.Storage>)
}

extension FlatView where Self: ~Escapable {
    
    @inlinable
    @inline(always)
    public func load() -> Owning {
        .init(pointer: pointer)
    }
    
    @inlinable
    @inline(always)
    public var reference: FlatReference<Owning> {
        FlatReference(offset: UInt32(pointer.offset))
    }
}

public struct FlatDefaultView<Enum: FlatCodable>: FlatView<Enum>, ~Escapable {
    public let pointer: FlatPointer<Owning.Storage>
    
    @inlinable
    @inline(always)
    @_lifetime(copy pointer)
    public init(pointer: FlatPointer<Owning.Storage>) {
        self.pointer = pointer
    }
}

