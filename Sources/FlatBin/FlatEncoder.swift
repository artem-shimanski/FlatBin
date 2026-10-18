//
//  FlatEncoder.swift
//  FlatBin
//
//  Created by Artem Shimanski on 13.05.2026.
//

import Foundation

public struct FlatEncoder {
    @usableFromInline
    unowned(unsafe) let context: FlatEncoderContext
    
    @usableFromInline init(context: FlatEncoderContext) {
        self.context = context
    }
    
    @inlinable
    @inline(always)
    @_transparent
    public func writeIndirect<T: FlatCodable>(of type: T.Type = T.self,
                                                 count: Int = 1,
                                       _ content: (consuming FlatIndirectEncoder<T>) -> Void) -> FlatReference<T.Storage> {
        let savedState = context.currentState
        let (buffer, offset) = context.allocate(of: T.Storage.self, capacity: count)
        let encoder = FlatIndirectEncoder<T>(buffer: buffer, offset: offset, context: context)
        content(encoder)

        if let offset = context.getOffset(for: UnsafeRawBufferPointer(buffer)) {
            context.rollback(to: savedState)
            return FlatReference<T.Storage>(offset: UInt32(offset))
        }
        else {
            context.saveOffset(UInt32(offset), for: UnsafeRawBufferPointer(buffer))
            return FlatReference<T.Storage>(offset: UInt32(offset))
        }
    }
    
    @inlinable
    public static func encode<T: FlatCodable>(_ value: T) -> Data {
        let context = FlatEncoderContext()
        let encoder = FlatEncoder(context: context)
        _ = encoder.writeIndirect(of: T.self) { indirect in
            var indirect = indirect
            indirect.write(value)
        }
        return context.finalize()
    }
}

public struct FlatIndirectEncoder<Value: FlatCodable>: ~Copyable, ~Escapable {
    @usableFromInline var buffer: UnsafeMutableBufferPointer<Value.Storage>
    @usableFromInline unowned(unsafe) let context: FlatEncoderContext
    @usableFromInline var cursor: Int = 0
    @usableFromInline var offset: Int = 0
    
    @usableFromInline
    @_lifetime(borrow buffer)
    init(buffer: UnsafeMutableBufferPointer<Value.Storage>, offset: Int, context: FlatEncoderContext) {
        self.buffer = buffer
        self.offset = offset
        self.context = context
    }
    
    @inlinable
    @inline(always)
    public mutating func write(_ value: borrowing Value) {
        precondition(cursor < buffer.count)
        value.encode(to: &buffer[cursor], with: FlatEncoder(context: context))
        cursor += 1
    }
    
    @inlinable
    @inline(always)
    public mutating func write<S: Collection>(contentsOf elements: S) where S.Element == Value.Storage {
        precondition(cursor + elements.count <= buffer.count)
        let result: Void? = elements.withContiguousStorageIfAvailable { src in
            let src = UnsafeRawBufferPointer(src)
            let dst = UnsafeMutableRawBufferPointer(UnsafeMutableBufferPointer(rebasing: buffer[cursor...]))
            dst.copyMemory(from: src)
            cursor += elements.count
        }
        if result == nil {
            for element in elements {
                buffer[cursor] = element
                cursor += 1
            }
        }
    }

}
