//
//  FlatArray.swift
//  FlatBin
//
//  Created by Artem Shimanski on 19.05.2026.
//

extension Array: FlatCodable where Element: FlatCodable {
    public struct Storage: BitwiseCopyable {
        public var count: UInt32
        public var elements: FlatReference<Element.Storage>
    }
    
    @inlinable
    @inline(always)
    public init(pointer: FlatPointer<Storage>) {
        let count = Int(pointer[\.count].pointee)
        let elements = pointer[\.elements].resolved()
        if Element.Storage.self == Element.self {
            self = [Element](unsafeUninitializedCapacity: count) { dst, initializedCount in
                elements.withUnsafeBufferPointer(count: count) { src in
                    src.withMemoryRebound(to: Element.self) { buffer in
                        initializedCount = dst.initialize(from: buffer).index
                    }
                }
            }
            
        }
        else {
            self = [Element](capacity: count) { span in
                var ptr = elements
                for _ in 0..<count {
                    span.append(Element.View(pointer: ptr).load())
                    ptr = ptr.nextPointer()
                }
            }
        }
    }
    
    @inlinable
    @inline(always)
    borrowing public func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
        storage.count = UInt32(count)
        storage.elements = encoder.writeIndirect(of: Element.self, count: count) { indirect in
            var indirect = indirect
            if Element.Storage.self == Element.self {
                withUnsafeBufferPointer { src in
                    src.withMemoryRebound(to: Element.Storage.self) { buffer in
                        indirect.write(contentsOf: buffer)
                    }
                }
            }
            else {
                forEach {indirect.write($0)}
            }
        }
    }
    
    public struct View: FlatView<Array>, ~Escapable {
        public let pointer: FlatPointer<Storage>
        public let count: Int
        @usableFromInline let elements: FlatPointer<Element.Storage>
        
        @inlinable
        @inline(always)
        @_lifetime(copy pointer)
        public init(pointer: FlatPointer<Storage>) {
            self.pointer = pointer
            count = Int(pointer.pointee.count)
            elements = pointer[\.elements].resolved()
        }
        
        @inlinable
        @inline(always)
        public var isEmpty: Bool {count == 0}
        
        @inlinable
        @inline(always)
        public subscript(_ index: Int) -> Element.View {
            @_lifetime(copy self)
            get {
                .init(pointer: elements.advanced(by: index))
            }
        }
        
        @inlinable
        public func forEach<E: Error>(_ body: (Element.View) throws(E) -> Void) throws(E) {
            var ptr = elements
            for _ in 0..<count {
                try body(.init(pointer: ptr))
                ptr = ptr.nextPointer()
            }
        }
        
        @inlinable
        public func contains(where predicate: (Element.View) -> Bool) -> Bool {
            var ptr = elements
            for _ in 0..<count {
                if predicate(.init(pointer: ptr)) {
                    return true
                }
                ptr = ptr.nextPointer()
            }
            return false
        }
    }
}

extension Array.View where Element: Equatable & FlatCodable {
    @inlinable
    public func contains(_ element: Element) -> Bool {
        var ptr = elements
        for _ in 0..<count {
            if element == .init(pointer: ptr) {
                return true
            }
            ptr = ptr.nextPointer()
        }
        return false
    }
}

extension Array.View where Element: FlatRawCodable & Equatable {
    @inlinable
    public func contains(_ element: Element) -> Bool {
        var ptr = elements
        for _ in 0..<count {
            if element == ptr.pointee {
                return true
            }
            ptr = ptr.nextPointer()
        }
        return false
    }
}
