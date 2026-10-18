//
//  FlatShared.swift
//  FlatBin
//
//  Created by Artem Shimanski on 08.06.2026.
//

@FlatCodable
public struct FlatSharedWrapper<Wrapped: FlatCodable> {
    @FlatShared
    public var wrapped: Wrapped
    public init(wrapped: Wrapped) {
        self.wrapped = wrapped
    }
}
