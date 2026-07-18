# ``MediaDiscovery``

Resolve user-supplied paths and discover media files without running media tools.

```swift
import MediaDiscovery

let files = try InputDiscovery().mediaFiles(
    at: ["~/Media/Incoming"],
    recursive: true
)
```

Explicit extension sets make the discovery policy replaceable per caller.
`FilePathResolver` can also be used independently when directory enumeration is
not needed. This product has no internal package dependencies.

## Topics

### Paths

- ``FilePathResolver``

### Discovery

- ``InputDiscovery``
- ``MediaDiscoveryError``
