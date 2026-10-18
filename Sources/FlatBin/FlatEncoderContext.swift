//
//  FlatEncoderContext.swift
//  FlatBin
//
//  Created by Artem Shimanski on 13.05.2026.
//

import Foundation

struct MemoryBlock {
    var buffer: UnsafeMutableRawBufferPointer
    var cursor: Int = 0
    var offset: Int
    var unused: Int
    
    init(byteCount: Int, offset: Int) {
        buffer = .allocate(byteCount: byteCount, alignment: 16)
        let gap = offset & 15
        cursor = gap
        unused = gap
        self.offset = offset
    }
    
    mutating func allocate(byteCount: Int) -> (buffer: UnsafeMutableRawBufferPointer, offset: Int)? {
        let start = cursor
        let end = start + byteCount
        guard end <= buffer.count else {return nil}
        cursor = end
        let slice = buffer[start..<end]
        let dst = UnsafeMutableRawBufferPointer(rebasing: slice)
        dst.initializeMemory(as: UInt8.self, repeating: 0)
        return (buffer: dst, offset: start + offset - unused)
    }
    
    mutating func align(to alignment: Int) -> Int {
        let newCursor = cursor.alignedUp(to: alignment)
        precondition(newCursor <= buffer.count)
        if newCursor != cursor {
            buffer[cursor..<newCursor].initializeMemory(as: UInt8.self, repeating: 0)
        }
        cursor = newCursor
        return offset + cursor - unused
    }
}

struct MemoryBufferKey: Hashable {
    var buffer: UnsafeRawBufferPointer
    func hash(into hasher: inout Hasher) {
        hasher.combine(bytes: buffer)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.buffer.count == rhs.buffer.count &&
        lhs.buffer.elementsEqual(rhs.buffer)
    }
}

@usableFromInline
final class FlatEncoderContext {
    @usableFromInline
    struct State {
        var memoryBlocksCount: Int
        var currentMemoryBlockCursor: Int
        var cursor: Int
    }
    private var memoryBlocks: [MemoryBlock] = []
    private var currentMemoryBlock = MemoryBlock(byteCount: 4096, offset: 0)
    private var cursor: Int = 0
    private var blockSize: Int = 4096
    private var emptyMemoryBlocks: [MemoryBlock] = []
        
    @usableFromInline
    init() {
        
    }
    
    deinit {
        for block in memoryBlocks {
            block.buffer.deallocate()
        }
        currentMemoryBlock.buffer.deallocate()
    }
    
    borrowing func allocate(byteCount: Int, alignment: Int = 1) -> (buffer: UnsafeMutableRawBufferPointer, offset: Int) {
        cursor = currentMemoryBlock.align(to: alignment)
        if let buffer = currentMemoryBlock.allocate(byteCount: byteCount) {
            cursor = buffer.offset + byteCount
            return buffer
        }
        else {
            let neededBytes = byteCount + 16
            memoryBlocks.append(currentMemoryBlock)
            while !emptyMemoryBlocks.isEmpty {
                guard emptyMemoryBlocks.last!.buffer.count < neededBytes else {break}
                emptyMemoryBlocks.removeLast().buffer.deallocate()
            }
            if !emptyMemoryBlocks.isEmpty {
                currentMemoryBlock = emptyMemoryBlocks.removeLast()
                currentMemoryBlock.cursor = currentMemoryBlock.unused
                currentMemoryBlock.offset = cursor
            }
            else {
                blockSize = max((byteCount + 16).alignedUp(to: 4096), blockSize * 2)
                currentMemoryBlock = .init(byteCount: blockSize, offset: cursor)
            }
            let buffer = currentMemoryBlock.allocate(byteCount: byteCount)!
            cursor = buffer.offset + byteCount
            return buffer
                
        }
    }
    
    @usableFromInline
    borrowing func allocate<T: BitwiseCopyable>(of type: T.Type, capacity: Int) -> (buffer: UnsafeMutableBufferPointer<T>, offset: Int) {
        let (buffer, offset) = allocate(byteCount: MemoryLayout<T>.stride &* capacity, alignment: MemoryLayout<T>.alignment)
        let ptr = buffer.bindMemory(to: T.self)
        return (ptr, offset)
    }

    @usableFromInline
    func finalize() -> Data {
        var data = Data(capacity: cursor)
        for block in memoryBlocks + [currentMemoryBlock] {
            data.append(contentsOf: block.buffer[block.unused..<block.cursor])
        }
        return data
    }
    
    
    @usableFromInline
    var currentState: State {
        State(memoryBlocksCount: memoryBlocks.count, currentMemoryBlockCursor: currentMemoryBlock.cursor, cursor: cursor)
    }
    
    @usableFromInline
    func rollback(to state: State) {
        let n = memoryBlocks.count - state.memoryBlocksCount
        if n > 0 {
            emptyMemoryBlocks.append(currentMemoryBlock)
            let extra = memoryBlocks.suffix(n)
            memoryBlocks.removeLast(n)
            currentMemoryBlock = extra.first!
            emptyMemoryBlocks.append(contentsOf: extra.dropFirst().reversed())
        }
        currentMemoryBlock.cursor = state.currentMemoryBlockCursor
        cursor = state.cursor
    }
    
    var cache: [MemoryBufferKey: UInt32] = [:]
    @usableFromInline
    func getOffset(for buffer: UnsafeRawBufferPointer) -> UInt32? {
        cache[MemoryBufferKey(buffer: buffer)]
    }

    @usableFromInline
    func saveOffset(_ offset: UInt32, for buffer: UnsafeRawBufferPointer) {
        cache[MemoryBufferKey(buffer: buffer)] = offset
    }

}
