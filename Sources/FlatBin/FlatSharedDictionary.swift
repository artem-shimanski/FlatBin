//
//  FlatSharedDictionary.swift
//  FlatBin
//
//  Created by Artem Shimanski on 08.06.2026.
//

public struct FlatSharedDictionary<Key: FlatHashable & FlatCodable, Value: FlatCodable>: FlatCodable {
    public var elements: [Key: Value]
    public struct Storage: BitwiseCopyable {
        public var elements: [Key: FlatSharedWrapper<Value>].Storage
    }
    public func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
        elements.mapValues{FlatSharedWrapper(wrapped: $0)}.encode(to: &storage.elements, with: encoder)
    }
    
    public init(elements: [Key: Value]) {
        self.elements = elements
    }
    
    public init(pointer: FlatPointer<Storage>) {
        elements = [Key: FlatSharedWrapper<Value>](pointer: pointer[\.elements]).mapValues{$0.wrapped}
    }
    
    public struct View: FlatView<FlatSharedDictionary>, ~Escapable {
        public let pointer: FlatPointer<Storage>
        
        @usableFromInline
        let elements: [Key: FlatSharedWrapper<Value>].View
        
        @inlinable
        @inline(always)
        @_lifetime(copy pointer)
        public init(pointer: FlatPointer<Storage>) {
            self.pointer = pointer
            elements = .init(pointer: pointer[\.elements])
        }
        
        @inlinable
        @inline(always)
        public subscript(_ key: Key) -> Value.View? {
            @_lifetime(copy self)
            get {
                elements[key]?.wrapped
            }
        }
        
        public func load() -> [Key: Value] {
            Owning(pointer: pointer).elements
        }

    }
}
