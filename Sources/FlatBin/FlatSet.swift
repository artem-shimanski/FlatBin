//
//  FlatSet.swift
//  FlatBin
//
//  Created by Artem Shimanski on 15.06.2026.
//

extension Set: FlatCodable where Element: FlatHashable & FlatCodable {
    public struct Storage: BitwiseCopyable {
        public var count: UInt32
        public var buckets: [Entry?].Storage
    }
    
    @FlatCodable
    public struct Entry {
        public var hash: Int64
        public var element: Element
        
        @inline(always)
        init(hash: Int64, element: Element) {
            self.hash = hash
            self.element = element
        }
    }
    
    @usableFromInline
    func buckets() -> [Entry?] {
        let capacity = Int(Double(count) * 1.43) + 1
        var buckets = [Entry?](repeating: nil, count: capacity)
        
        for element in self {
            var hasher = FlatHasher()
            element.hash(into: &hasher)
            let h = Int64(truncatingIfNeeded: hasher.finalize())
            var index = Int(UInt64(bitPattern: h) % UInt64(capacity))
            while buckets[index] != nil {
                index = (index + 1) % capacity
            }
            buckets[index] = Entry(hash: h, element: element)
        }
        return buckets
    }
    
    public init(pointer: FlatPointer<Storage>) {
        let buckets = [Entry?](pointer: pointer[\.buckets])
        self.init(minimumCapacity: Int(pointer[\.count].pointee))
        for entry in buckets {
            guard let entry else {continue}
            self.insert(entry.element)
        }
    }
    
    @inlinable
    @inline(always)
    public func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
        storage.count = UInt32(count)
        buckets().encode(to: &storage.buckets, with: encoder)
    }
    
    
    public struct View: FlatView<Set>, ~Escapable {
        public let pointer: FlatPointer<Storage>
        
        @_lifetime(copy pointer)
        public init(pointer: FlatPointer<Storage>) {
            self.pointer = pointer
            buckets = .init(pointer: pointer[\.buckets])
            capacity = buckets.count
        }
        
        private let buckets: [Entry?].View
        private let capacity: Int
        
        public var count: Int {
            Int(pointer[\.count].pointee)
        }
        
        public func contains(_ element: Element) -> Bool {
            var hasher = FlatHasher()
            element.hash(into: &hasher)
            let h = Int64(truncatingIfNeeded: hasher.finalize())
            
            var index = Int(UInt64(bitPattern: h) % UInt64(capacity))
            let startIndex = index
            
            while let bucket = buckets[index].value {
                if bucket.hash == h && bucket.element.load() == element {
                    return true
                }
                
                index = (index + 1) % capacity
                
                if index == startIndex { break }
            }
            return false
        }
    }
}
