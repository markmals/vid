# ``MediaRepair``

Build a fixed compatibility-oriented repair plan for problematic video.

The plan keeps the first video and audio streams, deinterlaces with `yadif`,
encodes H.264/AAC, removes subtitles, and enables MP4 fast start.

```swift
import MediaRepair

let plan = RepairPlan()
```

`RepairPlan` only authors the FFmpeg execution plan. Pass it to
`MediaProcessor` to add probing, staging, rollback, and commit behavior.

## Topics

### Repairing media

- ``RepairPlan``
