import sys
import lyricsgenius
import subprocess
import os

if len(sys.argv) < 3:
    print('Usage: lyrics.py "Song Title" "audio_file_path"')
    sys.exit(1)

title = sys.argv[1]
filepath = sys.argv[2]

# Get Genius token securely
GENIUS_TOKEN = os.getenv("GENIUS_TOKEN")
if not GENIUS_TOKEN:
    print("Error: GENIUS_TOKEN not set")
    sys.exit(1)

genius = lyricsgenius.Genius(
    GENIUS_TOKEN,
    skip_non_songs=True,
    excluded_terms=["(Remix)", "(Live)"],
    remove_section_headers=False,
    timeout=15
)

song = genius.search_song(title)
if song is None or not song.lyrics:
    print(f"Lyrics not found for: {title}")
    sys.exit(1)

# Raw lyrics
lyrics = song.lyrics

# Clean lyrics
filtered_lines = []
exclude_phrases = [
    "Translations", "Contributors", "Lyrics", "Romanization", "Embed",
    "Read More", "Genius", "About", "You might also like"
]

for line in lyrics.splitlines():
    clean_line = line.strip()
    if not clean_line:
        continue
    if any(p.lower() in clean_line.lower() for p in exclude_phrases):
        continue
    filtered_lines.append(clean_line)

final_lyrics = "\n".join(filtered_lines).replace('"', "'").replace("\r", "")

# Temporary files
lyrics_file = "genius_lyrics.txt"
temp_file = filepath + ".tmp"

# Save lyrics
with open(lyrics_file, "w", encoding="utf-8") as f:
    f.write(final_lyrics)

# Embed using ffmpeg
subprocess.run([
    "ffmpeg", "-y",
    "-i", filepath,
    "-i", lyrics_file,
    "-map_metadata", "0",
    "-metadata", f"lyrics={final_lyrics}",
    "-c", "copy", temp_file
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Replace original file
os.replace(temp_file, filepath)

# Cleanup
os.remove(lyrics_file)

print(f"Lyrics embedded into {filepath}")