//
//  FlatOptional.swift
//  FlatBin
//
//  Created by Artem Shimanski on 25.05.2026.
//

extension Optional: FlatCodable where Wrapped: FlatCodable {
    public struct Storage: BitwiseCopyable {
        public var offset: UInt32
    }
    
    @inlinable
    @inline(always)
    public init(pointer: FlatPointer<Storage>) {
        let offset = pointer[\.offset].pointee
        if offset < .max {
            let ptr = FlatPointer<Wrapped.Storage>(base: pointer.base, offset: Int(offset))
            self = Wrapped(pointer: ptr)
        }
        else {
            self = nil
        }
    }
    
    @inlinable
    @inline(always)
    public func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
        if let value = self {
            storage.offset = encoder.writeIndirect(of: Wrapped.self) { indirect in
                var indirect = indirect
                indirect.write(value)
            }.offset
        }
        else {
            storage.offset = .max
        }
    }
    
    public struct View: FlatView<Optional>, ~Escapable {
        public let pointer: FlatPointer<Storage>
        
        @inlinable
        @inline(always)
        @_lifetime(copy pointer)
        public init(pointer: FlatPointer<Storage>) {
            self.pointer = pointer
        }
        
        @inlinable
        @inline(always)
        public var value: Wrapped.View? {
            @_lifetime(copy self)
            get {
                let offset = pointer[\.offset].pointee
                guard offset < .max else { return nil }
                let ptr = _overrideLifetime(FlatPointer<Wrapped.Storage>(base: pointer.base, offset: Int(offset)), copying: self)
                return .init(pointer: ptr)
            }
        }
    }
}
