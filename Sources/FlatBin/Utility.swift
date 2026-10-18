//
//  Utility.swift
//  FlatBin
//
//  Created by Artem Shimanski on 13.05.2026.
//

import Foundation

extension BinaryInteger {
    
    @inlinable
    @inline(always)
    public var isPowerOfTwo: Bool {
        self > 0 && (self & (self - 1)) == 0
    }
    
    @inlinable
    @inline(always)
    public func alignedUp(to alignment: Self) -> Self {
        precondition(alignment > 0)
        precondition(alignment.isPowerOfTwo)
        let mask = alignment - 1
        return (self + mask) & ~mask
    }

    @inlinable
    @inline(always)
    public func alignedDown(to alignment: Self) -> Self {
        precondition(alignment > 0)
        precondition(alignment.isPowerOfTwo)
        let mask = alignment - 1
        return self & ~mask
    }

    @inlinable
    @inline(always)
    public func padding(to alignment: Self) -> Self {
        alignedUp(to: alignment) - self
    }
}

extension Data {
    mutating func align(to alignment: Int) {
        let padding = count.padding(to: alignment)
        guard padding > 0 else { return }
        append(contentsOf: repeatElement(0, count: padding))
    }
}


extension OutputRawSpan {
    mutating func align(to alignment: Int) {
        let padding = byteCount.padding(to: alignment)
        guard padding > 0 else { return }
        append(repeating: 0, count: padding, as: UInt8.self)
    }
}
