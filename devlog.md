
# 06/11/2025

Setting up November drawing:

```bash
# Screen recorded movie on iPhone 
# Cropped on iPhone
# Filtered to black and white on iphone

# Got .mov onto laptop and need to rotate it:

ffmpeg -i lee_sedol.mov -vf "transpose=2" -c:a copy input_01.mp4

# actually didn't need to
vidloop lee_sedol.mov

# slice film up into 25 frames
../../slice_frames.sh lee_sedol.mov 25 images

```


Processing handdrawn images...
This time, make a film and then crop afterward
```bash

# need to rename files first!
a=1
for i in *.JPG; do 
  new=$(printf "frame%04d.JPG" "$a")
  cp -i -- "$i" "../renamed/$new"
  let a=a+1
done

# stitch and crop
ffmpeg -framerate 10 -i "frame%04d.JPG" -vf "crop=1080:1080:844:1464" -c:v libx264 -pix_fmt yuv420p cropped_10.mp4

# preview
mpv --loop-file=inf --autofit-larger=100%x100% cropped_10.mp4

# adjust crop and preview
ffmpeg -framerate 10 -i "frame%04d.JPG" -vf "crop=1050:1020:874:1464" -c:v libx264 -pix_fmt yuv420p cropped_10.mp4
mpv --loop-file=inf --autofit-larger=100%x100% cropped_10.mp4

# Add audio from original mov
ffmpeg -i daewon_drawn.mp4 -i daewon.mov -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest daewon_drawn_audio.mp4

# Audio is out of sync!

# Get target duration:
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 daewon_drawn.mp4
# 2.8000

# Get original duration
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 daewon.mov
# 2.796667

# Just write a script...
 ../../audio_transfer.sh daewon_drawn.mp4 daewon.mov daewon_audio.mp4


# Old tests follow...

# Use existing filename ordering and stitch into film
ffmpeg -framerate 5 -pattern_type glob -i "*.JPG" -c:v libx264 -pix_fmt yuv420p step1_stitched2.mp4

# make it slightly faster
ffmpeg -framerate 6 -pattern_type glob -i "*.JPG" -c:v libx264 -pix_fmt yuv420p step1_stitched2.mp4

# faster again
ffmpeg -framerate 7 -pattern_type glob -i "*.JPG" -c:v libx264 -pix_fmt yuv420p step1_stitched3.mp4

# faster still
ffmpeg -framerate 10 -pattern_type glob -i "*.JPG" -c:v libx264 -pix_fmt yuv420p framerate_10.mp4

# find dimensions
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 framerate_10.mp4
# 3024, 4032

# 844, 1464 (offset from looking at one photo in preview)
# 1076 x 1076 (crop dimensions)

# preview crop
ffplay -i framerate_10.mp4 -vf "crop=1080:1080:844:1464"

# Crop and generate
ffmpeg -framerate 10 -pattern_type glob -i "*.JPG" -vf "crop=1080:1080:844:1464" -c:v libx264 -pix_fmt yuv420p cropped_10.mp4



```

# 09/10/2025
Processing the handdrawn images...
```bash
# Get imagemagick tools
brew install imagemagick
# Rotate all frames 180 degrees
mogrify -rotate 180 frame_*.JPG

magick frame_00020.JPG -crop 1800x1800+1500+700 test5.jpg && open test5.jpg
mogrify -crop 2000x2000+1500+500 frame_*.JPG

# Oh the cropping is really hard!
# use ffmpeg instead!
ffmpeg -framerate 5 -i frame_%05d.jpg -c:v libx264 -pix_fmt yuv420p step1_stitched.mp4

ffmpeg -framerate 6 -i frame_%05d.jpg -vf "crop=1690:1690:577:1669" -c:v libx264 -pix_fmt yuv420p one_step_01.mp4

ffmpeg -framerate 6 -i frame_%05d.jpg -vf "crop=1500:1500:644:1733" -c:v libx264 -pix_fmt yuv420p one_step_01.mp4

# Getting the next one ready...
ffmpeg -i daewon.mov -vf fps=10 -q:v 2 images/frame_%02d.jpg

```

# 09/09/2025
Got the chatgpt version of index.html running locally on an iPhone by putting index.html and the images folder into Firefox iOS downloads folder and running it from there.
Will run with this for now but PDF option would be a promising offline option also.

# 06/09/2025
```bash
# Get local ip address on mac
ipconfig getifaddr en0
```
Get client side going

# 05/09/2025
```bash
START="00:00:03.0"
END="00:00:06.0"
ffmpeg -ss "$START" -to "$END" -i clip.mp4 -frames:v 1 \
  -vf "crop='min(iw,ih)':'min(iw,ih)':'(iw-min(iw,ih))/2':'(ih-min(iw,ih))/2',\
       scale=1080:1080,format=gray,\
       drawgrid=width=280:height=280:thickness=1:color=red@0.28" \
  crop_preview.jpg
open crop_preview.jpg
```

```bash
START="00:00:03.0"
END="00:00:06.0"
ffmpeg -i clip.mp4 -ss "$START" -t "$END" -vf "fps=15,crop=1080:1080:0:420,scale=800:800,format=gray" -q:v 2 images/frame_%02d.png
open images
```

```bash
mkdir images2
START="00:00:03.0"
END="00:00:06.0"
ffmpeg -i clip.mp4 -ss "$START" -t "$END" -vf "fps=10,crop=1080:1080:0:420,scale=800:800,format=gray" -q:v 2 images2/frame_%02d.png
open images2
```

```bash
mkdir images3
START="00:00:03.0"
END="00:00:05.5"
ffmpeg -i clip.mp4 -ss "$START" -t "$END" -vf "fps=10,crop=1080:1080:0:420,scale=800:800,format=gray" -q:v 2 images3/frame_%02d.png
open images3
```

# 05/09/2025
```bash
mkdir Skanimate
cd Skatnimate
git init .
git config user.name bulany
git config user.email bulany.git@gmail.com
touch devlog.md
touch readme.md
code .
mkdir prompts
git remote add origin git@github.com:bulany/Skanimate.git
git push -u origin main
yt-dlp --version
pip3 install --upgrade yt-dlp

START="00:00:03.0"
END="00:00:06.0"
ffmpeg -ss "$START" -to "$END" -i clip.mp4 -c copy preview.mp4
open preview.mp4
```