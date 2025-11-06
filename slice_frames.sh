#!/bin/bash

# --- 1. Handle Command Line Arguments ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <INPUT_VIDEO_FILE> <NUMBER_OF_FRAMES> <OUTPUT_DIRECTORY>"
    echo "Example: $0 input.mp4 50 output_frames"
    exit 1
fi

INPUT_FILE="$1"
NUM_FRAMES="$2"
OUTPUT_DIR="$3"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input video file '$INPUT_FILE' not found."
    exit 1
fi

# Check if the number of frames is a positive integer
if ! [[ "$NUM_FRAMES" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: Number of frames must be a positive integer."
    exit 1
fi

# --- 2. Create Output Directory ---
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# --- 3. Get Total Number of Frames (NF) ---
# We use ffprobe to get the total number of frames in the video stream (v:0).
echo "Retrieving total frame count..."
TOTAL_FRAMES=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")

if [ -z "$TOTAL_FRAMES" ]; then
    echo "ERROR: Could not retrieve total frame count from '$INPUT_FILE'."
    exit 1
fi

echo "Total frames in video: $TOTAL_FRAMES"

# --- 4. Calculate the Selection Interval (Frame Step) ---
# The total number of frames is TOTAL_FRAMES. We want to select NUM_FRAMES.
# The step must select a frame every TOTAL_FRAMES / NUM_FRAMES frames.
# FFmpeg's select filter is zero-indexed, so we subtract 1 from NUM_FRAMES for the step calculation.
# Example: 100 frames total, want 10 frames. We select frame 0, 11, 22, 33, 44, 55, 66, 77, 88, 99.
# The step should be N/(M-1), where N is TOTAL_FRAMES and M is NUM_FRAMES.
# However, using N/M is simpler and often closer to the desired distribution.
# We use a select filter expression: 'not(mod(n\,STEP))'
# We use 'bc' for precise floating-point division.
# Adding 1 to the denominator (NUM_FRAMES) accounts for the first frame (n=0) always being selected.

# The most reliable method to select N equally spaced samples over TOTAL_FRAMES is:
# 1. Select the first frame (n=0).
# 2. Select frames at intervals of TOTAL_FRAMES / (NUM_FRAMES - 1)
# FFmpeg's 'select=not(mod(n,N))' needs an integer, so we use a different approach:
# The expression 'eq(mod(n\,FLOOR(STEP*t))\,0)' is too complex for a simple script.

# Simpler, reliable FFmpeg selection expression: "select=not(mod(n,N/M))"
# We calculate the step (N/M) and round it up to ensure we don't sample too many frames.
STEP_FLOAT=$(echo "scale=0; ($TOTAL_FRAMES / $NUM_FRAMES) / 1" | bc) # Simple step (round down)

# We use the 'gte(mod(n,STEP), 0)' structure for the FFmpeg select filter
# to choose one frame out of every 'STEP' frames.
# We ensure STEP is at least 1.
STEP=$(awk "BEGIN {print int(($TOTAL_FRAMES/$NUM_FRAMES)+0.5)}") # Round to nearest integer

# Ensure STEP is not zero (for very small videos/large number of frames)
if [ "$STEP" -lt 1 ]; then
    STEP=1
fi

echo "Selection step calculated: $STEP (Selects one frame every $STEP frames)"

# --- 5. Execute FFmpeg Extraction ---
echo "Starting frame extraction (this may take a moment)..."

# Filter: select=not(mod(n,$STEP)) selects a frame where n (frame index) is divisible by $STEP.
# This results in the desired number of frames, though the last frame might be slightly off.
ffmpeg -i "$INPUT_FILE" \
       -vf "select=not(mod(n\,$STEP)),crop=iw:ih" \
       -vsync vfr \
       -frames:v "$NUM_FRAMES" \
       -q:v 2 \
       "$OUTPUT_DIR/frame_%02d.png"

if [ $? -ne 0 ]; then
    echo "ERROR: FFmpeg extraction failed."
    exit 1
fi

echo "---"
echo "Success! Extracted $NUM_FRAMES frames to '$OUTPUT_DIR/'"