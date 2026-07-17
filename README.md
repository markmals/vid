# vid

`vid` is a Swift command-line interface for converting and organizing video files with FFmpeg. It can remux media into MP4, apply Apple-compatible codec tags, encode video as HEVC, repair problematic video, and add external subtitles.

## Requirements

- `ffmpeg` and `ffprobe` must be installed and available on `PATH`.
- Building from source requires Swift 6.4.
- The Swift package supports macOS 13 or later and Linux.

## Install with Homebrew

```sh
brew install markmals/tap/vid
```

On macOS, Homebrew installs FFmpeg with `vid`. On Linux, the formula intentionally leaves FFmpeg unmanaged and uses the `ffmpeg` and `ffprobe` already on `PATH`, preserving custom builds with codecs such as H.264 and HEVC.

## Build from source

Build and run the executable locally:

```sh
swift build -c release
.build/release/vid --help
```

During development, Swift Package Manager can build and run it in one command:

```sh
swift run vid --help
```

## Command overview

```text
vid remux
vid tag
vid encode
vid repair
vid subtitles add
vid subtitles add-matching
```

| Command | Accepts files | Accepts directories | Purpose |
| --- | --- | --- | --- |
| `vid remux` | Yes, one or more | Yes | Repackage media as MP4 without re-encoding video |
| `vid tag` | Yes, one or more | Yes | Create an Apple-compatible MP4 without re-encoding video |
| `vid encode` | Yes, one or more | Yes | Encode video as HEVC in an Apple-compatible MP4 |
| `vid repair` | Yes, one or more | Yes | Deinterlace and encode problematic video as H.264/AAC |
| `vid subtitles add` | One video and one subtitle file | No | Add one external text subtitle track |
| `vid subtitles add-matching` | Yes, one or more | Yes | Add same-named subtitle files to multiple videos |

`vid subtitles` is only a command group; use either `subtitles add` or `subtitles add-matching` beneath it.

## Passing files and directories

Commands that accept `<paths>` can receive any mixture of files and directories:

```sh
vid remux movie.mkv episode.mkv
vid tag movie.mkv ~/Downloads/another-movie.mkv
vid encode ~/Media/Incoming movie.mkv
```

A directory is processed at its top level by default. Pass `--recursive` or `-r` to descend into subdirectories:

```sh
vid encode ~/Media/Incoming --recursive
```

When scanning directories, `vid` recognizes these extensions:

```text
3gp avi flv m2ts m4v mkv mov mp4 mpeg mpg mts ts webm wmv
```

An explicitly supplied file is still sent to `ffprobe` even if its extension is not in that list. Duplicate paths are processed once, and batches run sequentially in deterministic path order. Processing stops at the first error.

## Output and source-file behavior

By default, source files are preserved.

For a non-MP4 input, the output uses the same basename with an `.mp4` extension:

```text
Movie.mkv -> Movie.mp4
```

For an MP4 input, the source cannot also be the default output. A suffix identifies the operation:

```text
Movie.mp4 -> Movie.remuxed.mp4
Movie.mp4 -> Movie.tagged.mp4
Movie.mp4 -> Movie.encoded.mp4
Movie.mp4 -> Movie.repaired.mp4
Movie.mp4 -> Movie.subbed.mp4
```

Every media operation supports these output options:

| Option | Behavior |
| --- | --- |
| `--output-directory <directory>` | Write outputs to an existing directory instead of beside each source |
| `--overwrite` | Replace an existing output or extracted subtitle sidecar |
| `--remove-source` | Permanently remove the source only after a valid output has been committed |
| `--replace` | Replace an MP4 input in place; for another container, create the corresponding MP4 and remove the source after success |

`--replace` cannot be combined with `--output-directory`.

> `--remove-source`, `--replace`, `--remove-subtitle`, and `--remove-subtitles` permanently delete files. They do not move files to the macOS Trash or a Linux desktop trash directory.

FFmpeg always writes to a hidden temporary file first. `vid` verifies that the temporary output is non-empty before moving it into place or removing a source file. Existing outputs are rejected unless `--overwrite` is present.

## Subtitle handling modes

The media conversion commands expose `--subtitles` with one of three values:

| Value | Text subtitles | Bitmap subtitles |
| --- | --- | --- |
| `text` | Convert to MP4 `mov_text` tracks | Omit |
| `extract` | Convert to MP4 `mov_text` tracks | Extract beside the output |
| `none` | Omit | Omit |

Extracted bitmap subtitles use names such as:

```text
Movie_sub3.sup
Movie_sub4.sub
Movie_sub5.xsub
```

The number is the original FFmpeg stream index. PGS subtitles use `.sup`; DVD and DVB subtitles use `.sub`; XSUB subtitles use `.xsub`.

## `vid remux`

Repackages the primary video stream, all audio streams, and selected subtitles into MP4. Video is always copied. Audio is copied by default but can be encoded as E-AC-3 or AAC.

```sh
vid remux Movie.mkv
vid remux Movie.mkv --subtitles none
vid remux Movie.mkv --subtitles extract --remove-source
vid remux ~/Media/Incoming --recursive --output-directory ~/Media/Remuxed
```

Options specific to `remux`:

| Option | Default | Behavior |
| --- | --- | --- |
| `--subtitles` (`text`, `extract`, or `none`) | `text` | Select subtitle handling |
| `--apple-compatible` | Off | Apply HEVC and Dolby codec tags used by Apple software |
| `--audio-codec` (`copy`, `eac3`, or `aac`) | `copy` | Select audio handling |
| `--audio-bitrate <bitrate>` | `320k` | Set bitrate when encoding audio |

Apple compatibility sets the HEVC video tag to `hvc1`, inserts HEVC access-unit delimiters, tags copied AC-3/E-AC-3 audio correctly, and enables MP4 fast start.

## `vid tag`

Creates an Apple-compatible MP4 while copying the video stream. This is the dedicated form of `vid remux --apple-compatible` and defaults to extracting bitmap subtitles.

```sh
vid tag Movie.mkv
vid tag Movie.mp4 --replace
vid tag Movie.mkv --audio-codec eac3 --audio-bitrate 320k
vid tag ~/Media/Movies --recursive --remove-source
```

Options specific to `tag`:

| Option | Default | Behavior |
| --- | --- | --- |
| `--subtitles` (`extract`, `text`, or `none`) | `extract` | Select subtitle handling |
| `--audio-codec` (`copy`, `eac3`, or `aac`) | `copy` | Copy or encode audio |
| `--audio-bitrate <bitrate>` | `320k` | Set bitrate when encoding audio |

For HEVC input, `tag` applies `hvc1` and inserts access-unit delimiters. It also applies `ac-3` or `ec-3` tags to matching audio and enables MP4 fast start.

## `vid encode`

Encodes the primary video stream with `libx265`, tags it as `hvc1`, and writes an Apple-compatible MP4. By default, audio is encoded as E-AC-3 at 320 kb/s, text subtitles become `mov_text`, and bitmap subtitles are extracted.

```sh
vid encode Movie.mkv
vid encode Movie.mkv --preset slow --crf 20
vid encode Movie.mkv --audio-codec copy --subtitles text
vid encode ~/Media/Incoming --recursive --skip-hevc --remove-source
```

Options specific to `encode`:

| Option | Default | Behavior |
| --- | --- | --- |
| `--subtitles` (`extract`, `text`, or `none`) | `extract` | Select subtitle handling |
| `--audio-codec` (`eac3`, `aac`, or `copy`) | `eac3` | Select audio handling |
| `--audio-bitrate <bitrate>` | `320k` | Set bitrate when encoding audio |
| `--crf <0...51>` | `23` | Set the libx265 constant rate factor; lower values retain more quality and produce larger files |
| `--preset <preset>` | `medium` | Set the libx265 encoding preset |
| `--exclude-audio-language <code>` | None | Exclude audio tracks with an ISO 639 language code; repeat the option for multiple codes |
| `--normalize-dispositions` | Off | Clear existing defaults, then make the first audio track and first English subtitle track default |
| `--skip-hevc` | Off | Skip files whose primary video stream is already HEVC |

Exclude more than one audio language by repeating the option:

```sh
vid encode Movie.mkv \
  --exclude-audio-language rus \
  --exclude-audio-language jpn
```

## `vid repair`

Uses a fixed compatibility-oriented H.264/AAC profile for problematic or interlaced video:

- Primary video stream only
- First audio stream only
- `libx264`, CRF 18, `medium` preset
- `yadif` deinterlacing and `yuv420p` pixel format
- AAC audio at 192 kb/s
- No subtitle tracks
- MP4 fast start

```sh
vid repair Broken.mkv
vid repair ~/Media/Problematic --recursive --output-directory ~/Media/Repaired
vid repair Broken.mp4 --replace
```

## `vid subtitles add`

Adds one external text subtitle file to one video. This command accepts files, not directories.

```sh
vid subtitles add Movie.mp4 Movie.srt
vid subtitles add Movie.mp4 Movie.es.srt --language spa --title Spanish
vid subtitles add Movie.mp4 Movie.srt --replace --remove-subtitle
```

Options specific to `subtitles add`:

| Option | Default | Behavior |
| --- | --- | --- |
| `--language <code>` | `eng` | Set the added subtitle track's ISO 639 language code |
| `--title <title>` | `ENG` | Set the added subtitle track's title |
| `--remove-subtitle` | Off | Permanently remove the external subtitle after success |

Existing text subtitles are retained and converted to `mov_text`. Existing bitmap subtitles are extracted as sidecars.

## `vid subtitles add-matching`

Pairs each video with a subtitle in the same directory that has the same basename:

```text
Movie.mkv + Movie.srt
Series/S01E01.mkv + Series/S01E01.srt
```

It accepts individual video files, directories, or a mixture of both:

```sh
vid subtitles add-matching Movie.mkv
vid subtitles add-matching ~/Media/Incoming
vid subtitles add-matching ~/Media/TV --recursive --replace --remove-subtitles
```

Options specific to `subtitles add-matching`:

| Option | Default | Behavior |
| --- | --- | --- |
| `--subtitle-extension <extension>` | `srt` | Select the extension used to find same-named subtitle files |
| `--language <code>` | `eng` | Set each added subtitle track's language code |
| `--title <title>` | `ENG` | Set each added subtitle track's title |
| `--remove-subtitles` | Off | Permanently remove matched external subtitles after success |

A missing matching subtitle is an error; it is not silently skipped.

## Getting command help

The generated help is the authoritative option reference:

```sh
vid --help
vid remux --help
vid tag --help
vid encode --help
vid repair --help
vid subtitles --help
vid subtitles add --help
vid subtitles add-matching --help
```
