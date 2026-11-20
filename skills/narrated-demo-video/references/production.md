# Local video production

## Plan the cut

Write a scene list in playback order. For each scene, record the slide number
or clip and source time range, what the viewer should notice, the on-screen
label, and the narration. Keep the relevant build, capture date, environment,
and evidence for claims in private notes. Link each caption to the final
timeline so cuts and narration changes can be checked together.

For example, a short walkthrough can open on a synthetic inventory, show a
category filter narrowing the list, then clear it and show the full list
again. Keep the cursor and result in frame. Rehearse at the capture size and
check the edit at the expected playback size.

## Edit and caption

1. Record only the slides or app window needed for the demo. If reviewing
   supplied footage, check for names, faces, browser tabs, URLs, identifiers,
   tokens, notifications, and background speech. Prefer recapturing with
   synthetic inputs. When redaction is needed, apply it to the exported
   picture and sound and check cuts and moving overlays frame by frame.
2. Keep narration on a separate editing track. Mute capture audio unless
   the viewer needs to hear it. Align captions to the final narration and
   include meaningful audible cues. For a silent cut, hold each caption or
   text card long enough to read.
3. Use original or authorized slides, fonts, images, music, and voices.
   Record any required credits in the delivery. For optional hosted
   narration, send only cleared narration text. Keep credentials out of
   prompts and logs, and check previous results before retrying a request
   that may already have been billed.

## Export locally

Use your editor to export H.264 video in an MP4, with AAC if there is sound.
Alternatively, export a local intermediate with one edited video track and
one mixed audio track if needed. Burn captions into the intermediate or
deliver a checked SRT or WebVTT alongside the MP4.

With FFmpeg and FFprobe installed and `libx264` available, run this from the
private working folder. Use a trusted, locally rendered `edited.mov` and
an unused output filename.

```bash
(
  output=./demo.mp4
  if [ -e "$output" ] || [ -L "$output" ]; then
    printf 'Export already exists: %s\n' "$output" >&2
    exit 1
  fi
  ffmpeg -v error -xerror -nostdin -n -f mov -protocol_whitelist file -i ./edited.mov \
    -map 0:V:0 -map '0:a:0?' -map_metadata -1 -map_metadata:s -1 -map_chapters -1 \
    -vf 'pad=ceil(iw/2)*2:ceil(ih/2)*2' -c:v libx264 -a53cc 0 -pix_fmt yuv420p \
    -c:a aac -b:a 160k -movflags +faststart "$output" &&
    ffprobe -v error -show_format -show_streams -show_chapters -of json "$output"
)
```

The command includes the main picture and optional audio. It drops chapters,
input tags, and inherited A/53 captions. Review the probe output for
unexpected tags or streams. For editor exports, also check for closed captions
embedded in the video track. Review any separate caption file, transcript,
and thumbnail for private content and filenames before handoff.

Play the final file from start to finish. Check that the opening and closing
frames are legible, captions match what is said, audio transitions are clear,
and environment labels and edits support the stated result. If the intended
player is available locally, verify caption playback there too.
