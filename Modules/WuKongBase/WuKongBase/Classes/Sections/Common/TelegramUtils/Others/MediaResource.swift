//
//  Others.swift
//  25519
//
//  Created by tt on 2022/6/18.
//

public struct MediaResourceId: Equatable, Hashable {
    public var stringRepresentation: String

    public init(_ stringRepresentation: String) {
        self.stringRepresentation = stringRepresentation
    }
}

public protocol MediaResource {
    var id: MediaResourceId { get }
    var size: Int? { get }
    var streamable: Bool { get }
    var headerSize: Int32 { get }
    
    func isEqual(to: MediaResource) -> Bool
}

public extension MediaResource {
    var size: Int? {
        return nil
    }
    
    var streamable: Bool {
        return false
    }
    
    var headerSize: Int32 {
        return 0
    }
}
