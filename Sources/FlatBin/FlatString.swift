//
//  FlatString.swift
//  FlatBin
//
//  Created by Artem Shimanski on 04.06.2026.
//

extension String: FlatCodable {
    public struct Storage: BitwiseCopyable {
        public var count: UInt32
        public var utf8: FlatReference<UInt8>
    }
    
    @inlinable
    @inline(always)
    public init(pointer: FlatPointer<Storage>) {
        let bytes = pointer[\.utf8].resolved()
        let count = Int(pointer[\.count].pointee)
        self = bytes.withUnsafeBufferPointer(count: count) { src in
            String(unsafeUninitializedCapacity: count) { buffer in
                buffer.initialize(fromContentsOf: src)
            }
        }
    }
    
    borrowing public func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
        let bytes = utf8
        storage.count = UInt32(bytes.count)
        storage.utf8 = encoder.writeIndirect(of: UInt8.self, count: bytes.count) { indirect in
            var indirect = indirect
            indirect.write(contentsOf: bytes)
        }
    }
}

extension String: FlatHashable {
    public func hash(into hasher: inout FlatHasher) {
        hasher.combine(bytes: utf8)
    }
}
