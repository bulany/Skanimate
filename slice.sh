#!/bin/bash

# -----------------------------------------------------------------------------
# 1. ARGUMENT PARSING & SWITCHES
# -----------------------------------------------------------------------------
FORCE_RESET=0

# Check if the first argument is our force flag
# If it is, we flag it, and then use the 'shift' command.
# 'shift' destroys $1 and shifts all other arguments to the left.
# So what WAS $2 (the video file) magically becomes the new $1!
if [[ "$1" == "-f" || "$1" == "--force" ]]; then
    FORCE_RESET=1
    shift
fi

if [ -z "$1" ]; then
    echo "Usage: $0 [-f|--force] path/to/video.mp4"
    exit 1
fi

VIDEO_FILE="$1"

if [ ! -f "$VIDEO_FILE" ]; then
    echo "Error: The file '$VIDEO_FILE' does not exist!"
    exit 1
fi

DIR=$(dirname "$VIDEO_FILE")
FILENAME=$(basename "$VIDEO_FILE")
BASENAME="${FILENAME%.*}"
CONF_FILE="$DIR/$BASENAME.conf"
OUT_DIR="$DIR/frames"
TMP_DIR="$DIR/tmp_frames"

# -----------------------------------------------------------------------------
# 2. FORCE RESET & FOLDER CLEANUP
# -----------------------------------------------------------------------------
if [ $FORCE_RESET -eq 1 ] && [ -f "$CONF_FILE" ]; then
    echo "Force flag used: Obliterating existing $CONF_FILE..."
    rm -f "$CONF_FILE"
fi

# If the output directory exists, wipe it out completely to prevent mixing old frames
if [ -d "$OUT_DIR" ]; then
    echo "Clearing out existing frames directory..."
    rm -rf "$OUT_DIR"
fi

# -----------------------------------------------------------------------------
# 3. EXTRACT VIDEO METADATA
# -----------------------------------------------------------------------------
echo "Analyzing video metadata..."

DEF_DURATION=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$VIDEO_FILE")
DEF_WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$VIDEO_FILE")
DEF_HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$VIDEO_FILE")

if [ "$DEF_WIDTH" -lt "$DEF_HEIGHT" ]; then
    DEF_CROP_SIZE="$DEF_WIDTH"
else
    DEF_CROP_SIZE="$DEF_HEIGHT"
fi

MAX_X=$(( DEF_WIDTH - DEF_CROP_SIZE ))
MAX_Y=$(( DEF_HEIGHT - DEF_CROP_SIZE ))

# -----------------------------------------------------------------------------
# 4. CONFIGURATION FILE HANDLING
# -----------------------------------------------------------------------------
if [ ! -f "$CONF_FILE" ]; then
    echo "Creating fresh configuration file at $CONF_FILE..."
    
    echo "# Number of frames to slice" > "$CONF_FILE"
    echo "FRAMES=30" >> "$CONF_FILE"
    echo "" >> "$CONF_FILE"
    
    echo "# Times are in seconds. (Clip duration is $DEF_DURATION)" >> "$CONF_FILE"
    echo "START_TIME=0.0" >> "$CONF_FILE"
    echo "END_TIME=$DEF_DURATION" >> "$CONF_FILE"
    echo "" >> "$CONF_FILE"
    
    echo "# ---------------------------------------------------------------------" >> "$CONF_FILE"
    echo "# CROP KEYFRAMES" >> "$CONF_FILE"
    echo "# Syntax: \"TIME_FRACTION:CROP_X:CROP_Y:CROP_SIZE\"" >> "$CONF_FILE"
    echo "# TIME_FRACTION : 0.0 is the first frame, 0.5 is the middle, 1.0 is the end" >> "$CONF_FILE"
    echo "# CROP_X limit  : 0 to $MAX_X" >> "$CONF_FILE"
    echo "# CROP_Y limit  : 0 to $MAX_Y" >> "$CONF_FILE"
    echo "# CROP_SIZE max : $DEF_CROP_SIZE" >> "$CONF_FILE"
    echo "# ---------------------------------------------------------------------" >> "$CONF_FILE"
    echo "# EXAMPLE OF A MOVING CROP (Uncomment to use):" >> "$CONF_FILE"
    echo "# KEYFRAMES=(" >> "$CONF_FILE"
    echo "#     \"0.0:0:$MAX_Y:$DEF_CROP_SIZE\"  # Start at the bottom" >> "$CONF_FILE"
    echo "#     \"0.5:0:0:$DEF_CROP_SIZE\"       # Move to the top by the middle" >> "$CONF_FILE"
    echo "#     \"1.0:0:$MAX_Y:$DEF_CROP_SIZE\"  # End at the bottom" >> "$CONF_FILE"
    echo "# )" >> "$CONF_FILE"
    echo "" >> "$CONF_FILE"
    
    echo "# Default: Top-left corner, full size, completely static." >> "$CONF_FILE"
    echo "KEYFRAMES=(" >> "$CONF_FILE"
    echo "    \"0.0:0:0:$DEF_CROP_SIZE\"" >> "$CONF_FILE"
    echo ")" >> "$CONF_FILE"
fi

source "$CONF_FILE"

FRAMES=${FRAMES:-30}
START_TIME=${START_TIME:-0.0}
END_TIME=${END_TIME:-$DEF_DURATION}

# -----------------------------------------------------------------------------
# 5. MATH & PREPARATION
# -----------------------------------------------------------------------------
DURATION=$(awk "BEGIN {print $END_TIME - $START_TIME}")

if [ "$FRAMES" -gt 1 ]; then
    FPS=$(awk "BEGIN {print ($FRAMES - 1) / $DURATION}")
else
    FPS=1
fi

mkdir -p "$TMP_DIR"
mkdir -p "$OUT_DIR"

# -----------------------------------------------------------------------------
# 6. PASS ONE: EXTRACT FULL-FRAME B&W IMAGES
# -----------------------------------------------------------------------------
echo "Step 1/2: Extracting $FRAMES full-resolution B&W frames..."

ffmpeg -y -ss "$START_TIME" -t "$DURATION" -i "$VIDEO_FILE" \
    -vf "format=gray,fps=${FPS}" \
    -vframes "$FRAMES" \
    "$TMP_DIR/frame_%02d.png" \
    -hide_banner -loglevel error

# -----------------------------------------------------------------------------
# 7. PASS TWO: BASH LOOP & KEYFRAME INTERPOLATION
# -----------------------------------------------------------------------------
echo "Step 2/2: Interpolating crop boxes and cropping..."

for (( i=1; i<=FRAMES; i++ )); do
    
    PADDED_NUM=$(printf "%02d" $i)
    
    # --- NEW: EOF FALLBACK LOGIC ---
    # If FFmpeg dropped the last frame due to a microsecond truncation at the
    # EOF boundary, this grabs the previous frame and duplicates it.
    if [ ! -f "$TMP_DIR/frame_$PADDED_NUM.png" ]; then
        PREV_NUM=$(printf "%02d" $((i-1)))
        echo "  -> [Notice] Frame $PADDED_NUM hit video boundary. Duplicating frame $PREV_NUM."
        cp "$TMP_DIR/frame_$PREV_NUM.png" "$TMP_DIR/frame_$PADDED_NUM.png"
    fi
    
    if [ "$FRAMES" -eq 1 ]; then
        PCT=0.0
    else
        PCT=$(awk "BEGIN {print ($i - 1) / ($FRAMES - 1)}")
    fi
    
    COORDS=$(printf "%s\n" "${KEYFRAMES[@]}" | awk -F':' -v p="$PCT" '
        { frac[NR]=$1; x[NR]=$2; y[NR]=$3; s[NR]=$4 }
        END {
            if (NR == 1 || p <= frac[1]) {
                print x[1], y[1], s[1]; exit
            }
            if (p >= frac[NR]) {
                print x[NR], y[NR], s[NR]; exit
            }
            for (i = 1; i < NR; i++) {
                if (p >= frac[i] && p <= frac[i+1]) {
                    range = frac[i+1] - frac[i]
                    weight = (p - frac[i]) / range
                    cx = x[i] + (x[i+1] - x[i]) * weight
                    cy = y[i] + (y[i+1] - y[i]) * weight
                    cs = s[i] + (s[i+1] - s[i]) * weight
                    printf "%d %d %d\n", cx, cy, cs; exit
                }
            }
        }
    ')
    
    read curr_x curr_y curr_size <<< "$COORDS"
    
    PCT_PRINT=$(awk "BEGIN {printf \"%03.0f\", $PCT * 100}")
    echo "  -> Frame $PADDED_NUM ($PCT_PRINT%) | Crop: ${curr_size}x${curr_size} at X:${curr_x} Y:${curr_y}"
    
    ffmpeg -y -i "$TMP_DIR/frame_$PADDED_NUM.png" \
        -vf "crop=${curr_size}:${curr_size}:${curr_x}:${curr_y}" \
        "$OUT_DIR/frame_$PADDED_NUM.png" \
        -hide_banner -loglevel error

done

# Clean up
rm -rf "$TMP_DIR"

echo "Done! Check your keyframed slice in $OUT_DIR"