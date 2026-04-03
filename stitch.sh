#!/bin/bash

# =============================================================================
# STITCH.SH
# Compiles a sequence of raw image files into a final video.
# Automatically creates a "stitched" sibling directory for output & config.
# =============================================================================

# --- 1. ARGUMENT PARSING & SETUP ---
QUIET_CLI=0

# Check if the first argument is our quiet flag
if [ "$1" == "-q" ] || [ "$1" == "--quiet" ]; then
    QUIET_CLI=1
    shift # Destroys $1 and shifts the remaining arguments to the left
fi

# Ensure the user provided a directory path
if [ -z "$1" ]; then
    echo "Usage: $0 [-q|--quiet] path/to/drawings/raw"
    exit 1
fi

# Remove trailing slashes (e.g., 'raw/' becomes 'raw')
INPUT_DIR="${1%/}"

# Ensure the input directory actually exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory '$INPUT_DIR' does not exist."
    exit 1
fi

# Set up our file and folder paths
PARENT_DIR=$(dirname "$INPUT_DIR")
STITCH_DIR="$PARENT_DIR/stitched"

CONF_FILE="$STITCH_DIR/stitch.conf"
TMP_DIR="$STITCH_DIR/tmp"

# Create the stitched directory immediately if it doesn't exist
mkdir -p "$STITCH_DIR"

# --- 2. CONFIGURATION FILE CREATION & SOURCING ---
if [ ! -f "$CONF_FILE" ]; then
    echo "No config file found. Creating default config at:"
    echo " -> $CONF_FILE"
    
    echo "# === STITCH CONFIGURATION ===" > "$CONF_FILE"
    echo "# Tweak these values and re-run the script to update your video!" >> "$CONF_FILE"
    echo "" >> "$CONF_FILE"
    echo "OUTPUT_FILENAME=\"output.mp4\"" >> "$CONF_FILE"
    echo "FPS=10 # Frames per second (e.g., 30 frames at 10fps = 3 seconds)" >> "$CONF_FILE"
    echo "" >> "$CONF_FILE"
    echo "# --- Operations ---" >> "$CONF_FILE"
    echo "QUIET=0        # Set to 1 to hide FFmpeg output (or use -q switch)" >> "$CONF_FILE"
    echo "CLEANUP_TMP=0  # Set to 1 to delete temporary files after completion" >> "$CONF_FILE"
    echo "AUTO_PLAY=1    # Set to 1 to auto-play the final video with mpv" >> "$CONF_FILE"
    echo "" >> "$CONF_FILE"
    echo "# --- Transformations ---" >> "$CONF_FILE"
    echo "# Uncomment to apply a crop (Syntax: WIDTH:HEIGHT:X_OFFSET:Y_OFFSET)" >> "$CONF_FILE"
    echo "# CROP=\"1080:1080:0:0\"" >> "$CONF_FILE"
    echo "" >> "$CONF_FILE"
    echo "# Uncomment to rotate images (Degrees: 90, 180, 270, 45, etc.)" >> "$CONF_FILE"
    echo "# ROTATE_DEGREES=90" >> "$CONF_FILE"
    echo "" >> "$CONF_FILE"
    echo "# --- Audio ---" >> "$CONF_FILE"
    echo "# Path to the original clip to borrow and sync audio from." >> "$CONF_FILE"
    echo "# Note: Path is relative to where you RUN the script from." >> "$CONF_FILE"
    echo "# AUDIO_FILE=\"orig.mp4\"" >> "$CONF_FILE"
    
    echo "Config created! Running workflow with defaults for now..."
fi

# Source the config to load variables into memory
source "$CONF_FILE"

# Provide fallback defaults in case the user deletes them from the config
OUTPUT_FILENAME=${OUTPUT_FILENAME:-"output.mp4"}
FPS=${FPS:-10}
QUIET=${QUIET:-0}
CLEANUP_TMP=${CLEANUP_TMP:-0}
AUTO_PLAY=${AUTO_PLAY:-1}

# Build FFmpeg verbosity flags as an array
FFMPEG_FLAGS=()
if [ "$QUIET_CLI" -eq 1 ] || [ "$QUIET" -eq 1 ]; then
    FFMPEG_FLAGS+=("-hide_banner" "-loglevel" "error")
fi

# --- 3. AUTO-DETECT IMAGES ---
# nullglob ensures the array stays empty if no files are found
shopt -s nullglob nocaseglob
IMAGES=("$INPUT_DIR"/*.jpg "$INPUT_DIR"/*.jpeg "$INPUT_DIR"/*.png)

if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "Error: No jpg, jpeg, or png files found in '$INPUT_DIR'."
    exit 1
fi

# Grab extension of the first file
FIRST_IMG_NAME=$(basename "${IMAGES[0]}")
IMAGE_EXT="${FIRST_IMG_NAME##*.}"

echo "Found ${#IMAGES[@]} images (Auto-detected extension: .$IMAGE_EXT)."
echo "Compiling at $FPS FPS..."

mkdir -p "$TMP_DIR"

# --- 4. BUILD VIDEO FILTERS DYNAMICALLY ---
VF_FILTERS=""

if [ -n "$CROP" ]; then
    VF_FILTERS="${VF_FILTERS}crop=${CROP},"
fi

if [ -n "$ROTATE_DEGREES" ]; then
    # We pass the math directly into rotw() and roth() so ffmpeg doesn't 
    # complain about 'a' being undefined during the canvas setup phase.
    VF_FILTERS="${VF_FILTERS}rotate=${ROTATE_DEGREES}*PI/180:ow=rotw(${ROTATE_DEGREES}*PI/180):oh=roth(${ROTATE_DEGREES}*PI/180),"
fi

# Always add standard pixel formatting at the end
VF_FILTERS="${VF_FILTERS}format=yuv420p"

if [ "$QUIET_CLI" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
    echo "Applying filters: $VF_FILTERS"
fi

# --- 5. COMPILE IMAGES TO VIDEO ---
echo "Step 1: Stitching images into temporary video..."

TMP_VIDEO="$TMP_DIR/tmp_video.mp4"

ffmpeg -y -framerate "$FPS" \
    -pattern_type glob -i "$INPUT_DIR/*.$IMAGE_EXT" \
    -vf "$VF_FILTERS" \
    -c:v libx264 \
    "${FFMPEG_FLAGS[@]}" \
    "$TMP_VIDEO"

if [ ! -f "$TMP_VIDEO" ]; then
    echo "Error: FFmpeg failed to create the video. Check your crop/rotate parameters."
    exit 1
fi

# --- 6. AUDIO SYNCING (IF REQUESTED) ---
if [ -n "$AUDIO_FILE" ] && [ -f "$AUDIO_FILE" ]; then
    echo "Step 2: Syncing audio from $AUDIO_FILE..."
    
    VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TMP_VIDEO")
    AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE")
    
    ATEMPO_RATIO=$(echo "scale=6; $AUDIO_DURATION / $VIDEO_DURATION" | bc)
    
    if [ "$QUIET_CLI" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
        echo " -> Target video duration: $VIDEO_DURATION sec"
        echo " -> Original audio duration: $AUDIO_DURATION sec"
        echo " -> Applying atempo ratio: $ATEMPO_RATIO"
    fi
    
    ffmpeg -y \
        -i "$TMP_VIDEO" \
        -i "$AUDIO_FILE" \
        -filter_complex "[1:a]atempo=$ATEMPO_RATIO[a_out]" \
        -map 0:v:0 \
        -map "[a_out]" \
        -c:v copy \
        -c:a aac \
        -shortest \
        "${FFMPEG_FLAGS[@]}" \
        "$STITCH_DIR/$OUTPUT_FILENAME"
else
    echo "Step 2: No audio requested. Finalizing video..."
    mv "$TMP_VIDEO" "$STITCH_DIR/$OUTPUT_FILENAME"
fi

# --- 7. CLEANUP & FINISH ---
if [ "$CLEANUP_TMP" -eq 1 ]; then
    echo "Cleaning up temporary files..."
    rm -rf "$TMP_DIR"
else
    echo "Temporary files retained at: $TMP_DIR"
fi

echo ""
echo "🎉 Done! Final video saved to: $STITCH_DIR/$OUTPUT_FILENAME"

# --- 8. PREVIEW WITH MPV (NON-BLOCKING) ---
if [ "$AUTO_PLAY" -eq 1 ]; then
    echo "Starting MPV preview in background..."
    
    # Silently kill any existing mpv instances to prevent overlapping windows
    pkill -x mpv 2>/dev/null
    
    # Launch mpv in the background (&) and discard its terminal output
    mpv --loop-file=inf --autofit-larger=100%x100% "$STITCH_DIR/$OUTPUT_FILENAME" > /dev/null 2>&1 &
    
    echo "Terminal is free! You can tweak the config and run again."
fi