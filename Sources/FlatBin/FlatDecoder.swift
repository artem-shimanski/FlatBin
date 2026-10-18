//
//  FlatDecoder.swift
//  FlatBin
//
//  Created by Artem Shimanski on 20.05.2026.
//

import Foundation

public struct FlatDecoder: Sendable {
    public let data: Data
    public init(data: Data) {
        self.data = data
    }
    
    @inlinable
    @_lifetime(borrow self)
    public func decode<T: FlatCodable>(_ type: T.Type) -> T.View {
        let base = data.bytes
        let ptr = FlatPointer<T.Storage>(base: base, offset: 0)
        return T.View(pointer: _overrideLifetime(ptr, borrowing: self))
    }
    
    @inlinable
    @_lifetime(borrow self)
    public func decode<T: FlatCodable>(by reference: FlatReference<T>) -> T.View {
        precondition(reference.offset < .max)
        let base = data.bytes
        let ptr = FlatPointer<T.Storage>(base: base, offset: Int(reference.offset))
        return T.View(pointer: _overrideLifetime(ptr, borrowing: self))
    }
}

