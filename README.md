# FlatBin

FlatBin is a Swift package for zero-copy binary serialization. A value is written into a flat
buffer in the in-memory layout of its generated `Storage` type; on read, a lightweight *view*
reads fields straight out of the `Data`, and only the fields you touch are loaded. A value can
also be loaded back in full with `.load()`. The layout is generated from your Swift types by
macros, so there is no schema file or code generator.

The package is under development and has no tagged releases.

## Requirements

- Swift tools 6.4 (`swift-tools-version: 6.4`), Swift 6 language mode.
- macOS 26 (`platforms: [.macOS(.v26)]`). No other platform is declared.
- `swift-syntax` 603.x or 604.x (a dependency of the macro target).
- The library is built with the experimental `Lifetimes` feature, because views are
  `~Escapable`. Targets that use FlatBin enable `Lifetimes`, and some also `LifetimeDependence`, in
  their `swiftSettings`.

## Installation

The repository has no remote or tags yet, so add it by path:

```swift
dependencies: [
    .package(path: "../FlatBin")
],
targets: [
    .target(
        name: "MyTarget",
        dependencies: [.product(name: "FlatBin", package: "FlatBin")],
        swiftSettings: [
            .enableExperimentalFeature("Lifetimes"),
            .enableExperimentalFeature("LifetimeDependence"),
        ]
    )
]
```

## Usage

```swift
import FlatBin

@FlatRawCodable
struct Point { var x: Float; var y: Float }

@FlatCodable
enum Kind: UInt8 { case a, b }

@FlatCodable
enum Shape { case none; case circle(radius: Float); case rect(Float, Float) }

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

    // Required: the macro adds `init(pointer:)`, which suppresses the memberwise init.
    init(id: UInt32, name: String, tags: [String], origin: Point, kind: Kind,
         nick: String?, attrs: [UInt32: Float], shape: Shape) { /* assign */ }
}

func roundTrip(_ item: Item) {
    let data = FlatEncoder.encode(item)            // Data
    let decoder = FlatDecoder(data: data)          // keep it in a named local
    let view = decoder.decode(Item.self)           // Item.View, no allocation

    _ = view.id                                    // integers and floats come back as values
    _ = view.name.load()                           // String.View -> String
    _ = view.tags[1].load()                        // element view, then load
    _ = view.origin.load()                         // raw struct view -> Point
    if let nick = view.nick { _ = nick.load() }    // optional view
    if let weight = view.attrs[1] { _ = weight.load() }
    let whole: Item = view.load()                  // materialize everything
    _ = whole
}
```

## API by concern

**Protocols**
- `FlatCodable`: `associatedtype Storage: BitwiseCopyable`, `View: FlatView` (defaults to
  `FlatDefaultView`), `init(pointer:)`, `encode(to:with:)`.
- `FlatRawCodable`: a `BitwiseCopyable` type that is its own `Storage` (`View` is
  `FlatRawCodableView`). Conformed by `Int`/`UInt`, the fixed-width integers, `Float`, `Double`.
- `FlatView`: the non-escapable read side; provides `load()` and `reference`.
- `FlatHashable` and `FlatHasher`: deterministic FNV-1a hashing used for dictionary and set
  keys. Integers and `String` conform; add conformance for your own key types.

**Macros**
- `@FlatCodable`: on a struct or enum. Generates `Storage`, `View`, `encode`, `init(pointer:)`
  and the conformance.
- `@FlatRawCodable`: on a `BitwiseCopyable` struct or enum (including `OptionSet`s). Adds only
  the conformance; the value is copied as is.
- `@FlatRaw` (on a property or enum case): treat that member as bitwise-copyable even if its
  type is not one of the built-in numeric types.
- `@FlatShared` (on a property): store the property out of line behind a `FlatReference`.
  Arrays and dictionaries use `FlatSharedArray` and `FlatSharedDictionary`.

**Built-in conformances**: integers, `Float`, `Double`, `String`, `Optional`, `Array`,
`Dictionary` (key `FlatHashable & FlatCodable`), `Set` (element `FlatHashable & FlatCodable`).
`Bool`, `Date`, `UUID` and `Data` have none; use an integer or a `@FlatRawCodable` wrapper.

**Reading and writing**
- `FlatEncoder.encode(_:) -> Data`; `FlatEncoder.writeIndirect` and `FlatIndirectEncoder` are the
  building blocks for hand-written `encode(to:with:)`.
- `FlatDecoder(data:)`, `decode(_:)` (root at offset 0) and `decode(by: FlatReference<T>)`.
- `FlatReference<T>` (UInt32 offset, `invalid` is `.max`) and `FlatPointer<T>` (a `RawSpan` plus
  an offset) are the addressing primitives.
- View helpers: `Array.View` has `count`, `isEmpty`, `subscript`, `forEach`, `contains(where:)`
  and `contains(_:)`; `Dictionary.View` has `count` and `subscript(key)`; `Set.View` has `count`
  and `contains(_:)`.

## Rules and limits

- **Views cannot escape.** They are `~Escapable` and borrow the decoder. Keep `FlatDecoder`
  in a named local (a temporary such as `FlatDecoder(data: d).decode(T.self)` does not compile)
  and use views inside a function, not as `main.swift` globals. Call `.load()` to get a value
  you can keep.
- **Explicit `init` for `@FlatCodable` structs.** The generated `init(pointer:)` removes the
  memberwise initializer.
- **Stored properties need an explicit type annotation.** Computed and `static` properties are
  skipped. Arrays, dictionaries and optionals are recognised by their syntax (`[T]`, `Array<T>`,
  `[K: V]`, `T?`).
- **Padding in `@FlatRawCodable` structs.** The struct is copied whole, including compiler
  padding, and that padding is uninitialised. It makes the output differ from run to run and
  defeats the byte-wise deduplication of identical blocks. Make every layout hole an explicit
  zero field, for example `private var padding: UInt8 = 0` between a `UInt8` and a `UInt32`.
- **Enums.** An enum with an integer raw type is stored as its raw value; decoding a value that
  matches no case traps. An enum with payloads is stored as `EnumStorage` (case index plus
  offset to a generated `Payload` struct); the case index is the declaration order, so
  reordering or inserting cases changes the format, and an unknown index traps.
  `@FlatRawCodable` enums are copied bitwise.
- **Format.** No header, version or checksum; the root value is at offset 0. Offsets are
  `UInt32`, so a buffer is limited to 4 GiB. The layout is the host's native one (little-endian
  on Apple platforms). Byte-identical indirect blocks (strings, arrays, payloads) are stored
  once. Dictionary and set buckets follow Swift's iteration order, so their bytes can differ
  between runs.
- **No validation on read.** The decoder trusts the data; truncated or foreign input is not
  detected (`FlatError` is declared but not thrown). There is no schema evolution: regenerate
  files when a type changes.

## Tests

```
xcrun swift test
```

`FlatBinTests` round-trips a `@FlatCodable` type through `FlatEncoder` and `FlatDecoder` and reads it
back through the view types.

## License

MIT. See [LICENSE](LICENSE).
