transcodeHEVCAll() {
    for file in "$1"/**/*(.); do
        transcodeHEVC "$file"
    done
}

transcodeHEVC() {
    file="$1"
    ext="${file##*.}"
    base=$(basename $file $ext)
    out="$(pwd)/${base}mp4"

    ffmpeg -i "$file" -strict unofficial -metadata:s:a:0 language=eng -metadata:s:a:0 title="ENG" -c copy -c:s mov_text -tag:v hvc1 "$out"
    trash "$file"
}

transcodeAll() {
    for file in "$1"/**/*(.); do
        transcode "$file"
    done
}

transcode() {
    file="$1"
    transcodeWSubs "$file"
}

transcodeNoSub() {
    file="$1"
    ext="${file##*.}"
    base=$(basename $file $ext)
    out="$(pwd)/${base}mp4"

    ffmpeg -i "$file" -strict unofficial -c copy "$out"
    trash "$file"
}

transcodeFix() {
    file="$1"
    base="${file%.*}"
    out="${base}.mp4"

    ffmpeg -i "$file" \
        -map 0:v:0 -map 0:a:0 \
        -c:v libx264 -crf 18 -preset medium \
        -vf "yadif,format=yuv420p" \
        -c:a aac -b:a 192k \
        -movflags +faststart \
        "$out"
}

transcodeWSubsAll() {
    for file in "$1"/**/*(.); do
        transcodeWSubs "$file"
    done
}

transcodeWSubs() {
    file="$1"
    ext="${file##*.}"
    base=$(basename $file $ext)
    out="$(pwd)/${base}mp4"

    ffmpeg -i "$file" -strict unofficial -map "0:v" -map "0:a" -map "0:s?" -c:v copy -c:a copy -c:s mov_text "$out"
    trash "$file"
}

convertAll() {
    for file in "$1"/**/*(.); do
        convert "$file"
    done
}

convert() {
    file="$1"
    ext="${file##*.}"
    base=$(basename $file $ext)
    out="$(pwd)/${base}mp4"

    ffmpeg -i "$file" -strict unofficial -metadata:s:a:0 language=eng -metadata:s:a:0 title="ENG" -c:v libx265 -tag:v hvc1 -crf 23 -c:a eac3 -b:a 320k -c:s mov_text "$out"
    trash "$file"
}

convertNoSubs() {
    file="$1"
    ext="${file##*.}"
    base=$(basename $file $ext)
    out="$(pwd)/${base}mp4"

    ffmpeg -i "$file" -strict unofficial -c:v libx265 -tag:v hvc1 -crf 23 -c:a eac3 -b:a 320k "$out"
    trash "$file"
}

tagAllNoSubs() {
    for file in "$1"/**/*(.); do
        tagNoSubs "$file"
    done
}

tagAll() {
    for file in "$1"/**/*(.); do
        tag "$file"
    done
}

# Tag HEVC MP4 files with the hvc1 tag so they display correctly on Apple platforms
tag() {
  #########################################################
  ## 1) Parse input file path into directory & base name ##
  #########################################################
  file="$1"
  dir="$(dirname "$file")"
  filename="$(basename "$file")"        # e.g. "Succession - S01E01.mkv"
  ext="${filename##*.}"                 # e.g. "mkv"
  base="${filename%.*}"                 # e.g. "Succession - S01E01"

  # Our output paths (temporary "-tagged" before renaming)
  tagged="${dir}/${base}-tagged.mp4"
  out="${dir}/${base}.mp4"

  ###################################################
  ## 2) Find the index + codec of each subtitle.   ##
  ##    Separate "bitmap" vs "text" into 2 arrays. ##
  ###################################################
  typeset -a text_subs bitmap_subs
  text_subs=()
  bitmap_subs=()

  while IFS=',' read -r idx codec; do
    case "$codec" in
      hdmv_pgs_subtitle|dvd_subtitle) bitmap_subs+=("$idx") ;; # bitmap (PGS/VobSub)
      *)                               text_subs+=("$idx")   ;; # treat others as text
    esac
  done < <(ffprobe -v error -select_streams s -show_entries stream=index,codec_name -of csv=p=0 "$file")

  echo "Text subtitle streams: ${text_subs[*]}"
  echo "Bitmap subtitle streams: ${bitmap_subs[*]}"

  ############################################################
  ## 3) Extract each bitmap subtitle stream to its own .sup ##
  ############################################################
  for idx in "${bitmap_subs[@]}"; do
    sup_file="${dir}/${base}_sub${idx}.sup"
    echo "Extracting bitmap subtitle from stream #$idx -> $sup_file"
    ffmpeg -y -probesize 50M -analyzeduration 50M -i "$file" -map "0:${idx}?" -c copy "$sup_file"
    if [[ -s "$sup_file" ]]; then
      echo "✓ Created: $sup_file"
    else
      echo "✗ Failed to extract bitmap subtitle #$idx"
      rm -f "$sup_file"
    fi
  done

  #################################################################
  ## 4) Capture audio streams (index + codec) in input order     ##
  #################################################################
  typeset -a audio_idx audio_codec
  audio_idx=()
  audio_codec=()
  while IFS=',' read -r idx codec; do
    audio_idx+=("$idx")
    audio_codec+=("$codec")
  done < <(ffprobe -v error -select_streams a -show_entries stream=index,codec_name -of csv=p=0 "$file")

  ##############################################################
  ## 5) Build the final MP4                                   ##
  ##############################################################
  typeset -a cmd
  cmd=(
    ffmpeg -y
    -probesize 50M
    -analyzeduration 50M
    -i "$file"

    # (A) First real video track (skip cover images)
    -map "0:v:0?"

    # (B) All audio tracks (in input order)
    -map "0:a?"

    # Copy everything by default
    -c copy

    # Keep container/title metadata from source
    -map_metadata 0

    # Ensure AUDs for HEVC and tag video as hvc1
    -bsf:v hevc_metadata=aud=insert
    -tag:v:0 hvc1

    # MP4 web distribution best-practice
    -movflags +faststart
  )

  # zsh-safe per-audio tagging: iterate 1..$#audio_idx, but emit tags for a:0, a:1, ...
  if (( $#audio_idx )); then
    for i in {1..$#audio_idx}; do
      case "${audio_codec[i]}" in
        eac3) cmd+=(-tag:a:$((i-1)) ec-3) ;;  # Dolby Digital Plus
        ac3)  cmd+=(-tag:a:$((i-1)) ac-3) ;;  # Dolby Digital
        *)    ;;                               # leave others alone
      esac
    done
  fi

  # Map text subs (if any) and set codec once
  if (( $#text_subs )); then
    for idx in "${text_subs[@]}"; do
      cmd+=(-map "0:${idx}?")
    done
    cmd+=(-c:s mov_text)
  else
    cmd+=(-sn)
  fi

  # Output to the temporary tagged file
  cmd+=("$tagged")

  echo "Running final MP4 creation command:"
  echo "${cmd[*]}"

  # Execute and capture status
  "${cmd[@]}"
  ff_status=$?

  ########################################################################
  ## 6) If success, trash source and rename; otherwise clean up         ##
  ########################################################################
  if [[ $ff_status -eq 0 && -s "$tagged" ]]; then
    trash "$file"
    mv -f "$tagged" "$out"
    echo "Successfully created: $out"
    if (( $#bitmap_subs )); then
      echo "Extracted .sup files for bitmap subtitles:"
      for idx in "${bitmap_subs[@]}"; do
        echo "  ${dir}/${base}_sub${idx}.sup"
      done
    fi
  else
    echo "Error: FFmpeg failed or wrote an empty file."
    [[ -f "$tagged" && ! -s "$tagged" ]] && rm -f "$tagged"
    return 1
  fi
}


tagNoSubs() {
    file="$1"
    ext="${file##*.}"
    base=$(basename $file $ext)
    tagged="$(pwd)/${base}-tagged.mp4"
    out="$(pwd)/${base}mp4"

    ffmpeg -i "$file" -strict unofficial -strict -2 -c:v copy -c:a eac3 -tag:v hvc1 "$tagged"
    trash "$file"
    mv "$tagged" "$out"
    echo "$tagged"
    echo "$out"
}

ffsub() {
    video="$1"
    subs="$2"

    video_ext="${file##*.}"
    video_base=$(basename $video $video_ext)
    subbed="$(pwd)/${base}-subbed.mp4"

    output="$video"

    ffmpeg -i "$video" -i "$subs" -c copy -c:s mov_text \
        -strict unofficial \
        -metadata:s:a:0 language=eng -metadata:s:a:0 title="ENG" \
        -metadata:s:s:0 language=eng -metadata:s:s:0 title="ENG" \
        "$subbed"

    rm -r "$video"
    rm -r "$subs"

    mv -v "$subbed" "$output"
}

applySubs() {
    files=(
        "/Volumes/SSD/Media/Movies/Dallas Buyer's Club (2013)"
        "/Volumes/SSD/Media/Movies/Days of Heaven (1978)"
        "/Volumes/SSD/Media/Movies/Delicatessen (1991)"
        "/Volumes/SSD/Media/Movies/Detroit (2017)"
        "/Volumes/SSD/Media/Movies/Die Hard (1988)"
        "/Volumes/SSD/Media/Movies/Dirty Dancing (1987)"
        "/Volumes/SSD/Media/Movies/Disclosure (2020)"
        "/Volumes/SSD/Media/Movies/Do Revenge (2022)"
        "/Volumes/SSD/Media/Movies/Don't Look Up (2021)"
        "/Volumes/SSD/Media/Movies/Don't Think Twice (2016)"
        "/Volumes/SSD/Media/Movies/Drive (2011)"
        "/Volumes/SSD/Media/Movies/Erin Brockovich (2000)"
        "/Volumes/SSD/Media/Movies/Escape From New York (1981)"
        "/Volumes/SSD/Media/Movies/Eternal Sunshine of the Spotless Mind (2004)"
        "/Volumes/SSD/Media/Movies/Eyes Wide Shut (1999)"
        "/Volumes/SSD/Media/Movies/Fear and Loathing In Las Vegas (1998)"
        "/Volumes/SSD/Media/Movies/Fire Island (2022)"
        "/Volumes/SSD/Media/Movies/Free Fire (2016)"
        "/Volumes/SSD/Media/Movies/Gangs of New York (2002) - Remastered"
        "/Volumes/SSD/Media/Movies/Girl Interrupted (1999)"
        "/Volumes/SSD/Media/Movies/Glass Onion (2022)"
        "/Volumes/SSD/Media/Movies/Glengarry Glen Ross (1992)"
        "/Volumes/SSD/Media/Movies/Guillermo Del Toros Pinocchio (2022)"
        "/Volumes/SSD/Media/Movies/Guys and Dolls (1955)"
        "/Volumes/SSD/Media/Movies/Hard Eight (1996)"
        "/Volumes/SSD/Media/Movies/Horse Girl (2020)"
        "/Volumes/SSD/Media/Movies/How It Ends (2021)"
        "/Volumes/SSD/Media/Movies/I'm Not There (2007)"
        "/Volumes/SSD/Media/Movies/I'm Thinking Of Ending Things (2020)"
        "/Volumes/SSD/Media/Movies/Indiana Jones and the Kingdom of the Crystal Skull (2008)"
        "/Volumes/SSD/Media/Movies/Indiana Jones and the Last Crusade (1989)"
        "/Volumes/SSD/Media/Movies/Indiana Jones And The Temple Of Doom (1984)"
        "/Volumes/SSD/Media/Movies/Inside (2021)"
        "/Volumes/SSD/Media/Movies/Joel Kim- Booster Psychosexual (2022)"
        "/Volumes/SSD/Media/Movies/Julie and Julia (2009)"
        "/Volumes/SSD/Media/Movies/Jurassic World Dominion (2022)"
        "/Volumes/SSD/Media/Movies/Labyrinth (1986)"
        "/Volumes/SSD/Media/Movies/Little Miss Sunshine (2006)"
        "/Volumes/SSD/Media/Movies/Little Shop of Horrors (1986)"
        "/Volumes/SSD/Media/Movies/Logan's Run (1976)"
        "/Volumes/SSD/Media/Movies/Long Shot (2017)"
        "/Volumes/SSD/Media/Movies/Magnolia (1999)"
        "/Volumes/SSD/Media/Movies/Memento (2000)"
        "/Volumes/SSD/Media/Movies/Men (2022)"
        "/Volumes/SSD/Media/Movies/Mr. Roosevelt (2017)"
        "/Volumes/SSD/Media/Movies/National Lampoon's Christmas Vacation (1989)"
        "/Volumes/SSD/Media/Movies/Nick Kroll- Little Big Boy (2022)"
        "/Volumes/SSD/Media/Movies/No Time To Die (2021)"
        "/Volumes/SSD/Media/Movies/Norm Macdonald- Nothing Special (2022)"
        "/Volumes/SSD/Media/Movies/Not Okay (2022)"
        "/Volumes/SSD/Media/Movies/Obi-Wan Kenobi (2022)"
        "/Volumes/SSD/Media/Movies/Once (2007)"
        "/Volumes/SSD/Media/Movies/Paris Is Burning (1990)"
        "/Volumes/SSD/Media/Movies/Patton Oswalt- We All Scream (2022)"
        "/Volumes/SSD/Media/Movies/Point Break (1991)"
        "/Volumes/SSD/Media/Movies/Prometheus (2012)"
        "/Volumes/SSD/Media/Movies/Punch-Drunk Love (2002)"
        "/Volumes/SSD/Media/Movies/Raiders of the Lost Ark (1981)"
        "/Volumes/SSD/Media/Movies/Ratatouille (2007)"
        "/Volumes/SSD/Media/Movies/Rocky (1976)"
        "/Volumes/SSD/Media/Movies/Scott Pilgrim vs. The World (2010)"
        "/Volumes/SSD/Media/Movies/Sheng Wang- Sweet And Juicy (2022)"
        "/Volumes/SSD/Media/Movies/Soapdish (1991)"
        "/Volumes/SSD/Media/Movies/Song to Song (2017)"
        "/Volumes/SSD/Media/Movies/Strangers On A Train (1951)"
        "/Volumes/SSD/Media/Movies/Stutz (2022)"
        "/Volumes/SSD/Media/Movies/Sweeney Todd (2007)"
        "/Volumes/SSD/Media/Movies/Synecdoche. New York (2008)"
        "/Volumes/SSD/Media/Movies/Tár (2022)"
        "/Volumes/SSD/Media/Movies/Taylor Tomlinson- Look At You (2022)"
        "/Volumes/SSD/Media/Movies/The Bee Gees How Can You Mend A Broken Heart (2020)"
        "/Volumes/SSD/Media/Movies/The Big Lebowski (1998)"
        "/Volumes/SSD/Media/Movies/The Graduate (1967)"
        "/Volumes/SSD/Media/Movies/The Green Knight (2021)"
        "/Volumes/SSD/Media/Movies/The Inside Outtakes (2022)"
        "/Volumes/SSD/Media/Movies/The Lost Leonardo (2021)"
        "/Volumes/SSD/Media/Movies/The Master (2012)"
        "/Volumes/SSD/Media/Movies/The Music Man (1962)"
        "/Volumes/SSD/Media/Movies/The New World (2005)"
        "/Volumes/SSD/Media/Movies/The Orange Years- The Nickelodeon Story (2020)"
        "/Volumes/SSD/Media/Movies/The Silence Of The Lambs (1991)"
        "/Volumes/SSD/Media/Movies/The Social Network (2010)"
        "/Volumes/SSD/Media/Movies/The Tree of Life (2011)"
        "/Volumes/SSD/Media/Movies/The Wrong Missy (2020)"
        "/Volumes/SSD/Media/Movies/Tin Men (1987)"
        "/Volumes/SSD/Media/Movies/Together Together (2021)"
        "/Volumes/SSD/Media/Movies/Topsy-Turvy (1999)"
        "/Volumes/SSD/Media/Movies/Trainspotting (1996)"
        "/Volumes/SSD/Media/Movies/Unbreakable (2000)"
        "/Volumes/SSD/Media/Movies/Unpregnant (2020)"
        "/Volumes/SSD/Media/Movies/Waitress (2007)"
        "/Volumes/SSD/Media/Movies/Would It Kill You To Laugh (2022)"
    )

    for file in $files; do
        ffsub "${file}.mp4" "${file}.srt"
    done
}

hevcVideo() {
    local file="$1"
    local dir="${file:h}"
    local base="${file:t:r}"

    # Confirm it's a video before converting
    local isVideo="$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=codec_type \
        -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)"

    if [[ "$isVideo" != "video" ]]; then
        echo "Skipping $file (not a video)"
        return
    fi

    echo "Converting ${base} to HEVC…"

    local input="$file"
    local backup="${dir}/${base}.x264.mp4"
    local tmp_output="${dir}/${base}.x265.mp4"
    local output="${dir}/${base}.mp4"

    ffmpeg -hide_banner -y -i "$input" \
        -map '0:v:0' \
        -map '0:a?' \
        -map '-0:a:m:language:rus' \
        -map '0:s?' \
        -c:v libx265 -tag:v hvc1 -crf 23 \
        -c:a eac3 -b:a 320k \
        -c:s mov_text \
        -movflags +faststart \
        -disposition:a 0 \
        -disposition:s 0 \
        -disposition:a:0 default \
        -disposition:s:m:language:eng default \
        "$tmp_output" || { echo "Error: FFmpeg failed or wrote an empty file."; return 1; }

    # Only rename after success; keep original as .x264.mp4
    mv "$tmp_output" "$output"
    rm -rf "$input"

    echo "Converted $output to HEVC!"
}

hevcAll() {
    for file in "$1"/**/*(.); do
        local isHevc="$(ffprobe -v error -select_streams v -show_entries stream=codec_name,codec_type -of default=noprint_wrappers=1 "$file" | grep hevc)"

        # Not HEVC; -z == empty string
        if [ -z $isHevc ]; then
            hevcVideo "$file"
        else
            local file_name=$file:t:r
            echo "Skipping $file_name; Already HEVC"
        fi
    done
}