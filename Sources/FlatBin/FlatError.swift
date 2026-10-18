//
//  FlatError.swift
//  FlatBin
//
//  Created by Artem Shimanski on 18.05.2026.
//


public enum FlatError: Error {
    case outOfBounds(Any.Type)
    case misaligned(Any.Type, offset: Int, alignment: Int)
}
