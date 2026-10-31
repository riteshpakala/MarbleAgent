# MarbleAgent

A photo filter that runs on the GPU, shipped as a [Granite](https://github.com/riteshpakala/Granite) agent
package. A call names a photo and a look from Marble's catalog; Marble gives the photo that look with a
Metal kernel and writes the result beside it.

The catalog holds one look for now:

| Look | What it does |
|---|---|
| `sepia` | warm brown tones, like an old print |

## How an app finds it

Marble is a `GraniteAgentPackage`, and it carries a record in its binary:

```swift
@used @section("__DATA_CONST,__granite")
let marbleRecord: GraniteRoster.Record = { GraniteRoster.record(MarbleAgent.self) }
```

An app that links the package finds it through Granite's roster. The app imports nothing from Marble and
lists nothing:

```swift
// Package.swift: a target the app links depends on the product.
.package(url: "https://github.com/riteshpakala/MarbleAgent.git", branch: "main"),
.product(name: "MarbleAgent", package: "MarbleAgent"),

// Anywhere in the app.
let roster = GraniteRoster.discovered()
let input = Data(#"{"path": "beach.jpg", "directory": "/Users/me/Pictures"}"#.utf8)
let answer = try await roster.package("marble")?.perform(input)
// {"filter":"sepia","height":2048,"intensity":1,"milliseconds":41,"path":"/Users/me/Pictures/beach-sepia.jpg","width":3072}
```

[Craft](https://github.com/riteshpakala/Craft) does this: its model sees a `marble` tool with the schema
below, and the run shows on Craft's agent map.

## What a call takes and answers

| Field | | |
|---|---|---|
| `path` | required | the photo, relative to `directory` or absolute |
| `filter` | optional | the look; `sepia` when left out |
| `intensity` | optional | 0 (the photo as it was) to 1 (the whole look); 1 when left out |
| `output` | optional | where to write the result; beside the photo, named for the look, when left out |
| `directory` | the host's | the folder the host works in; a host fills it and does not show it to a model |

The answer is a `MarbleResult`: the file written, as an absolute path, its width and height, the look,
the intensity, and how long the GPU took. The format follows the output's extension (`.png`, `.jpg`,
`.heic`, `.tiff`), and the photo's orientation is kept.

## Nothing on the GPU until a call

The device and queue are made on the first call, and a look's kernel is compiled from its source the first
time it is asked for. No metallib ships, and an app that links Marble and never calls it pays nothing.

## Adding a look

A look is a case in `MarbleFilter` and its kernel in a file of its own beside it, as sepia's is
(`Sources/MarbleAgent/Filters/MarbleFilter+Sepia.swift`). Every kernel reads the photo from texture 0,
writes texture 1, and reads its intensity from buffer 0; the colors are premultiplied RGBA in sRGB. The
schema a model sees lists every case, so a new look reaches it with no other change.

## Requirements

macOS 14, a Metal device, and a Swift compiler with the `@used` and `@section` attributes (Swift 6.4).
`swift test` filters a generated photo on the GPU and checks its pixels; the GPU tests skip without a
Metal device.
