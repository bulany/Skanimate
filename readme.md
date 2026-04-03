# Skanimate

A lightweight, Bash-scripted workflow to turn short video clips into frame-by-frame reference images, and then stitch photographed drawings back into a synced, animated video.

---

## 🤖 Context for AI Assistant (Copy/Paste this into new chats)

> **Project Overview:**
> I am building a bash-scripted video-to-flipbook workflow. I take short human-motion video clips, extract frames, draw over them by hand, and then stitch those photos back into a new video with the original audio synced up.
> 
> **Core Scripts:**
> 1. `slice.sh`: Takes an `.mp4` and a config file to extract a specific time window and animated crop area into black-and-white reference frames.
> 2. `stitch.sh`: Takes an input directory of photographed drawings (e.g., `folder/raw/`), auto-detects the image extensions, and compiles them. It automatically creates a sibling directory (e.g., `folder/stitched/`) where it stores the `stitch.conf` configuration file, temporary files, and the final `output.mp4`. 
> 
> **Key Features & Tools:**
> - Relies entirely on `ffmpeg` for media processing, `bc` for floating point math, and `mpv` for non-blocking background video previewing.
> - Heavily utilizes `.conf` files so I can rapidly iterate on crop, rotation, and framerate without typing long CLI commands.
> 
> **Strict Instructions for the LLM:**
> - **Bash Syntax Warning:** I have encountered frequent bugs with LLM-generated Bash scripts regarding square brackets. **You must ensure proper spacing** in if-statements (e.g., `if[ -z "$var" ]; then`, NEVER `if[ ... ]` or `if [ ... ]; ];`). 
> - I prefer heavily commented Bash scripts so I can learn the language as I go.
> - Keep things lean, simple, and isolated to these bash tools.

---

## 🛠 Prerequisites
Ensure you have the following installed on your system:
* **`ffmpeg`**: The core engine for video/image manipulation.
* **`ffprobe`**: Included with ffmpeg, used to check video/audio durations.
* **`bc`**: Basic calculator for command-line math (used for audio syncing).
* **`mpv`**: A lightweight media player used for looping the final result while you work.

---

## 🎬 The Workflow

### Step 1: Slice (Extracting Reference Frames)
Find a short clip of human motion you want to animate.

```bash
./slice.sh path/to/video.mp4
```
1. The first time you run this, it will create a config file at `path/to/video.conf`.
2. Open that `.conf` file and adjust the `START_TIME`, `END_TIME`, and `KEYFRAMES` (for panning/cropping).
3. Run the script again. It will generate your black-and-white reference images in a `frames/` subdirectory.

### Step 2: Draw (The Analog Step)
Print, trace, or digitally draw over your extracted frames. Once you are done, photograph your drawings in order and drop them into a folder. 
*(e.g., `flipbooks/2026_03/drawings/raw/`)*

### Step 3: Stitch (Compiling the Final Video)
Point the stitch script at the directory containing your raw photos.

```bash
./stitch.sh flipbooks/2026_03/drawings/raw
```
1. The script will instantly create a sibling directory called `stitched/`.
2. It will generate a default configuration file at `stitched/stitch.conf` and compile a first-pass video (`output.mp4`), automatically popping up a looping preview window using `mpv`.
3. **Iterate:** Leave the preview window open! Open `stitched/stitch.conf` in your text editor. 
   - Need to fix the framing? Uncomment and tweak `CROP`.
   - Photos sideways? Uncomment `ROTATE_DEGREES`.
   - Want the original sound? Point `AUDIO_FILE` to the original `.mp4`.
4. Re-run `./stitch.sh`. The terminal remains unblocked, the old video player will instantly close, and the updated video will begin looping on your screen.