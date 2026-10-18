//
//  FlatDictionary.swift
//  FlatBin
//
//  Created by Artem Shimanski on 05.06.2026.
//

extension Dictionary: FlatCodable where Key: FlatHashable & FlatCodable, Value: FlatCodable {
    public struct Storage: BitwiseCopyable {
        public var count: UInt32
        public var buckets: [Entry?].Storage
    }
    
    @FlatCodable
    public struct Entry {
        public var hash: Int64
        public var key: Key
        public var value: Value
        
        @inline(always)
        init(hash: Int64, key: Key, value: Value) {
            self.hash = hash
            self.key = key
            self.value = value
        }
    }
    
    @usableFromInline
    func buckets() -> [Entry?] {
        let capacity = Int(Double(count) * 1.43) + 1
        var buckets = [Entry?](repeating: nil, count: capacity)
        
        for (key, value) in self {
            var hasher = FlatHasher()
            key.hash(into: &hasher)
            let h = Int64(truncatingIfNeeded: hasher.finalize())
            var index = Int(UInt64(bitPattern: h) % UInt64(capacity))
            while buckets[index] != nil {
                index = (index + 1) % capacity
            }
            buckets[index] = Entry(hash: h, key: key, value: value)
        }
        return buckets
    }
    
    public init(pointer: FlatPointer<Storage>) {
        let buckets = [Entry?](pointer: pointer[\.buckets])
        self.init(minimumCapacity: Int(pointer[\.count].pointee))
        for entry in buckets {
            guard let entry else {continue}
            self[entry.key] = entry.value
        }
    }
    
    @inlinable
    @inline(always)
    public func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
        storage.count = UInt32(count)
        buckets().encode(to: &storage.buckets, with: encoder)
    }
    
    
    public struct View: FlatView<Dictionary>, ~Escapable {
        public let pointer: FlatPointer<Storage>
        
        @_lifetime(copy pointer)
        public init(pointer: FlatPointer<Storage>) {
            self.pointer = pointer
            buckets = .init(pointer: pointer[\.buckets])
            capacity = buckets.count
        }
        
        @usableFromInline let buckets: [Entry?].View
        @usableFromInline let capacity: Int
        
        @inlinable
        public var count: Int {
            Int(pointer[\.count].pointee)
        }
        
        @inlinable
        public subscript(_ key: Key) -> Value.View? {
            @_lifetime(copy self)
            get {
                var hasher = FlatHasher()
                key.hash(into: &hasher)
                let h = Int64(truncatingIfNeeded: hasher.finalize())
                
                var index = Int(UInt64(bitPattern: h) % UInt64(capacity))
                let startIndex = index
                
                while let bucket = buckets[index].value {
                    if bucket.hash == h && bucket.key.load() == key {
                        return bucket.value
                    }
                    
                    index = (index + 1) % capacity

                    if index == startIndex { break }
                }
                return nil
            }
        }
    }
}
