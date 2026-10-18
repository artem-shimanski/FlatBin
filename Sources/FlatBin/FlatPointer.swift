//
//  FlatPointer.swift
//  FlatBin
//
//  Created by Artem Shimanski on 14.05.2026.
//

public struct FlatPointer<Value: BitwiseCopyable>: ~Escapable {
    public let base: RawSpan
    public let offset: Int
    
    @inlinable
    @inline(always)
    @_lifetime(borrow base)
    public init(base: RawSpan, offset: Int) {
        self.base = base
        self.offset = offset
    }
    
    @inlinable
    @inline(always)
    @_lifetime(copy self)
    public func advanced(by n: Int) -> Self {
        let ptr = FlatPointer(base: base, offset: self.offset + n * MemoryLayout<Value>.stride)
        return _overrideLifetime(ptr, copying: self)
    }

    @inlinable
    @inline(always)
    @_lifetime(copy self)
    public func nextPointer() -> Self {
        let ptr = FlatPointer(base: base, offset: self.offset + MemoryLayout<Value>.stride)
        return _overrideLifetime(ptr, copying: self)
    }

    @inlinable
    @inline(always)
    public subscript<T: BitwiseCopyable>(_ property: KeyPath<Value, T>) -> FlatPointer<T> {
        @_lifetime(copy self)
        get {
            let ptr = FlatPointer<T>(base: base, offset: self.offset + MemoryLayout<Value>.offset(of: property)!)
            return _overrideLifetime(ptr, copying: self)
        }
    }
    
    @inlinable
    @inline(always)
    public var pointee: Value {
        base.unsafeLoad(fromByteOffset: offset, as: Value.self)
    }
    
    @inlinable
    @inline(always)
    @_transparent
    public func withUnsafeBufferPointer<R>(count: Int = 1, _ block: (UnsafeBufferPointer<Value>) -> R) -> R {
        base.withUnsafeBytes { buffer -> R in
            let slice = buffer[offset..<(offset + MemoryLayout<Value>.stride * count)]
            return block(slice.assumingMemoryBound(to: Value.self))
        }
    }
    
    @inlinable
    @inline(always)
    @_lifetime(copy self)
    public func resolved<Base>() -> FlatPointer<Base> where Value == FlatReference<Base> {
        let ptr = FlatPointer<Base>(base: base, offset: Int(pointee.offset))
        return _overrideLifetime(ptr, copying: self)
    }
}

@FlatRawCodable
public struct FlatReference<Base>: BitwiseCopyable, Hashable, Sendable {
    public var offset: UInt32 = 0
    public init(offset: UInt32) {
        self.offset = offset
    }
    
    public static var invalid: FlatReference { FlatReference(offset: .max) }
}

