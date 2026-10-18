import Testing
import Foundation
import FlatBin

@FlatRawCodable
struct Point: Equatable {
    var x: Float
    var y: Float
}

@FlatCodable
enum Kind: UInt8 {
    case a, b, c
}

@FlatCodable
enum Shape {
    case none
    case circle(radius: Float)
    case rect(Float, Float)
}

@FlatCodable
struct Item {
    var id: UInt32
    var name: String
    var tags: [String]
    var origin: Point
    var kind: Kind
    var nick: String?
    var attrs: [UInt32: Float]
    var shape: Shape

    init(id: UInt32, name: String, tags: [String], origin: Point, kind: Kind,
         nick: String?, attrs: [UInt32: Float], shape: Shape) {
        self.id = id
        self.name = name
        self.tags = tags
        self.origin = origin
        self.kind = kind
        self.nick = nick
        self.attrs = attrs
        self.shape = shape
    }
}

private func makeItem(nick: String? = "Nick", shape: Shape = .none) -> Item {
    Item(id: 42, name: "Hello", tags: ["one", "two", "three"], origin: Point(x: 1.5, y: -2),
         kind: .b, nick: nick, attrs: [1: 0.5, 7: 2.25], shape: shape)
}

@Suite("FlatBin round trip")
struct FlatBinTests {
    @Test("Scalars and strings are read through the view")
    func scalarsAndStrings() {
        let data = FlatEncoder.encode(makeItem())
        let decoder = FlatDecoder(data: data)
        let view = decoder.decode(Item.self)
        #expect(view.id == 42)
        #expect(view.name.load() == "Hello")
    }

    @Test("Array elements are read by index")
    func arrays() {
        let data = FlatEncoder.encode(makeItem())
        let decoder = FlatDecoder(data: data)
        let view = decoder.decode(Item.self)
        #expect(view.tags.count == 3)
        #expect(view.tags[1].load() == "two")
        #expect(view.tags[2].load() == "three")
    }

    @Test("Raw struct and raw-value enum are read through the view")
    func rawStructAndEnum() {
        let data = FlatEncoder.encode(makeItem())
        let decoder = FlatDecoder(data: data)
        let view = decoder.decode(Item.self)
        #expect(view.origin.load() == Point(x: 1.5, y: -2))
        #expect(view.kind.load() == .b)
    }

    @Test("Optional is present or nil")
    func optionals() {
        let present = FlatDecoder(data: FlatEncoder.encode(makeItem(nick: "Nick")))
        #expect(present.decode(Item.self).nick?.load() == "Nick")
        let absent = FlatDecoder(data: FlatEncoder.encode(makeItem(nick: nil)))
        if absent.decode(Item.self).nick != nil { Issue.record("nick should be nil") }
    }

    @Test("Dictionary lookup by key")
    func dictionaries() {
        let data = FlatEncoder.encode(makeItem())
        let decoder = FlatDecoder(data: data)
        let view = decoder.decode(Item.self)
        #expect(view.attrs.count == 2)
        #expect(view.attrs[7]?.load() == 2.25)
        #expect(view.attrs[1]?.load() == 0.5)
        if view.attrs[3] != nil { Issue.record("key 3 should be missing") }
    }

    @Test("Enum with payloads survives the round trip")
    func payloadEnum() {
        for shape in [Shape.none, .circle(radius: 3), .rect(2, 4)] {
            let decoder = FlatDecoder(data: FlatEncoder.encode(makeItem(shape: shape)))
            let loaded: Shape = decoder.decode(Item.self).shape.load()
            switch (shape, loaded) {
            case (.none, .none):
                break
            case let (.circle(a), .circle(b)):
                #expect(a == b)
            case let (.rect(a, b), .rect(c, d)):
                #expect(a == c && b == d)
            default:
                Issue.record("Shape changed during the round trip")
            }
        }
    }

    @Test("load() materializes the whole value")
    func fullLoad() {
        let decoder = FlatDecoder(data: FlatEncoder.encode(makeItem()))
        let item: Item = decoder.decode(Item.self).load()
        #expect(item.id == 42)
        #expect(item.name == "Hello")
        #expect(item.tags == ["one", "two", "three"])
        #expect(item.origin == Point(x: 1.5, y: -2))
        #expect(item.kind == .b)
        #expect(item.nick == "Nick")
        #expect(item.attrs == [1: 0.5, 7: 2.25])
    }
}
