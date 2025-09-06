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