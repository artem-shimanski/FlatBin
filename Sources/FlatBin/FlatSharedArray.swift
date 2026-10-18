//
//  FlatSharedArray.swift
//  FlatBin
//
//  Created by Artem Shimanski on 08.06.2026.
//

public struct FlatSharedArray<Element: FlatCodable>: FlatCodable {
    public var elements: [Element]
    public struct Storage: BitwiseCopyable {
        public var elements: [FlatSharedWrapper<Element>].Storage
    }
    public func encode(to storage: inout Storage, with encoder: borrowing FlatEncoder) {
        elements.map{FlatSharedWrapper(wrapped: $0)}.encode(to: &storage.elements, with: encoder)
    }
    
    public init(elements: [Element]) {
        self.elements = elements
    }
    
    public init(pointer: FlatPointer<Storage>) {
        elements = [FlatSharedWrapper](pointer: pointer[\.elements]).map{$0.wrapped}
    }
    
    public struct View: FlatView<FlatSharedArray>, ~Escapable {
        public let pointer: FlatPointer<Storage>
        
        @usableFromInline
        let elements: [FlatSharedWrapper<Element>].View
        
        @inlinable
        @inline(always)
        @_lifetime(copy pointer)
        public init(pointer: FlatPointer<Storage>) {
            self.pointer = pointer
            elements = .init(pointer: pointer[\.elements])
        }
        
        @inlinable
        @inline(always)
        public var isEmpty: Bool {elements.isEmpty}

        
        @inlinable
        @inline(always)
        public var count: Int {
            elements.count
        }
        
        @inlinable
        @inline(always)
        public subscript(_ index: Int) -> Element.View {
            @_lifetime(copy self)
            get {
                elements[index].wrapped
            }
        }
        
        @inlinable
        @inline(always)
        public func load() -> [Element] {
            Owning(pointer: pointer).elements
        }

        @inlinable
        public func forEach<E: Error>(_ body: (Element.View) throws(E) -> Void) throws(E) {
            try elements.forEach { (element) throws(E) in
                try body(element.wrapped)
            }
        }
        
        @inlinable
        public func contains(where predicate: (Element.View) -> Bool) -> Bool {
            elements.contains {
                predicate($0.wrapped)
            }
        }
    }
}
