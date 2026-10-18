//
//  FlatHasher.swift
//  FlatBin
//
//  Created by Artem Shimanski on 25.05.2026.
//

public struct FlatHasher {
    private static let offsetBasis: UInt64 = 14695981039346656037
    private static let fnvPrime: UInt64 = 1099511628211
    
    private var hash: UInt64 = offsetBasis
    
    public init() {}

    @inlinable
    public mutating func combine<H: FlatHashable>(_ value: H) {
        value.hash(into: &self)
    }

    public mutating func combine(bytes: UnsafeRawBufferPointer) {
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= Self.fnvPrime
        }
    }

    public mutating func combine<S: Collection>(bytes: S) where S.Element == UInt8 {
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= Self.fnvPrime
        }
    }

    @inlinable
    public mutating func combine<T: BitwiseCopyable>(bytesOf value : borrowing T) {
        withUnsafeBytes(of: value) { ptr in
            combine(bytes: ptr)
        }
    }
    
    public func finalize() -> Int {
        return Int(truncatingIfNeeded: hash)
    }
}


public protocol FlatHashable: Hashable {
    func hash(into hasher: inout FlatHasher)
}

extension FlatHashable where Self: BitwiseCopyable {
    @inlinable
    public func hash(into hasher: inout FlatHasher) {
        hasher.combine(bytesOf: self)
    }
}

