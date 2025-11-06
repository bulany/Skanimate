#!/bin/bash

# --- 1. Handle Command Line Arguments ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <VIDEO_FILE> <AUDIO_FILE> <OUTPUT_FILE>"
    echo "Example: $0 cropped_video.mp4 audio_source.mov final_synced.mp4"
    exit 1
fi

VIDEO_FILE="$1"         # The generated video (Input 0, Target Duration)
AUDIO_FILE="$2"         # The original audio file (Input 1, Original Duration)
OUTPUT_FILE="$3"        # The final output file

# Check if input files exist
if [ ! -f "$VIDEO_FILE" ] || [ ! -f "$AUDIO_FILE" ]; then
    echo "ERROR: One or both input files not found. Please check paths."
    exit 1
fi

# --- 2. Get Durations ---
echo "Retrieving durations..."

# Get the duration of the video (TARGET DURATION)
VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO_FILE")

# Get the duration of the audio (ORIGINAL DURATION)
AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE")

if [ -z "$VIDEO_DURATION" ] || [ -z "$AUDIO_DURATION" ]; then
    echo "ERROR: Could not retrieve one or both file durations."
    exit 1
fi

echo "Video Duration (Target): $VIDEO_DURATION seconds"
echo "Audio Duration (Original): $AUDIO_DURATION seconds"

# --- 3. Calculate the atempo Ratio ---
# Ratio = Original Duration / Target Duration. Uses 'bc' for floating-point math.
ATEMPO_RATIO=$(echo "scale=6; $AUDIO_DURATION / $VIDEO_DURATION" | bc)

echo "Calculated atempo Ratio: $ATEMPO_RATIO"

# --- 4. Execute FFmpeg Merge and Stretch ---
echo "---"
echo "Starting FFmpeg merge and stretch operation..."

# Run FFmpeg to copy video, apply atempo filter to audio, and combine
ffmpeg -i "$VIDEO_FILE" \
       -i "$AUDIO_FILE" \
       -c:v copy \
       -filter_complex "[1:a]atempo=$ATEMPO_RATIO[a_out]" \
       -map 0:v:0 \
       -map "[a_out]" \
       -c:a aac \
       -shortest "$OUTPUT_FILE"

# Check the exit status of FFmpeg
if [ $? -ne 0 ]; then
    echo "ERROR: FFmpeg operation failed."
    exit 1
fi

echo "---"
echo "Success! Final file created: $OUTPUT_FILE"

# --- 5. Preview with mpv ---
echo "Starting MPV preview (Looped and Auto-fit)... Press 'q' to quit."
mpv --loop-file=inf --autofit-larger=100%x100% "$OUTPUT_FILE"

echo "Script finished."