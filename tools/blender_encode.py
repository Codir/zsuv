"""Encode a folder of numbered frames (+ an optional WAV) to an H.264/AAC MP4 with Blender's FFmpeg.

  blender -b --factory-startup -P tools/blender_encode.py -- <frames dir> <out.mp4> <fps> <kbps> [audio.wav]

Called by tools/make_media.py; Blender is the one encoder this machine has.
"""
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
src, out, fps, kbps = args[0], args[1], int(args[2]), int(args[3])
wav = args[4] if len(args) > 4 else ""
files = sorted(f for f in os.listdir(src) if f.lower().endswith((".jpg", ".png")))

scn = bpy.context.scene
ed = scn.sequence_editor_create()
strips = ed.strips if hasattr(ed, "strips") else ed.sequences
frames = strips.new_image("frames", os.path.join(src, files[0]), 1, 1)
for f in files[1:]:
    frames.elements.append(f)
if wav:
    strips.new_sound("audio", wav, 2, 1)
scn.frame_start, scn.frame_end = 1, len(files)
scn.render.fps, scn.render.fps_base = fps, 1
scn.render.resolution_x, scn.render.resolution_y, scn.render.resolution_percentage = 1920, 1080, 100
scn.render.image_settings.file_format = "FFMPEG"
ff = scn.render.ffmpeg
ff.format, ff.codec = "MPEG4", "H264"
# A set bitrate rather than a quality level: the dithering is noise to the encoder, and a
# quality level lets the file run to 50+ MB for under a minute.
ff.constant_rate_factor, ff.ffmpeg_preset = "NONE", "BEST"
ff.video_bitrate, ff.minrate, ff.maxrate, ff.buffersize = kbps, 0, kbps * 2, kbps * 2
ff.gopsize = fps
if wav:
    ff.audio_codec, ff.audio_bitrate, ff.audio_channels, ff.audio_mixrate = "AAC", 192, "STEREO", 48000
else:
    ff.audio_codec = "NONE"
scn.view_settings.view_transform = "Standard"
scn.render.filepath = out
bpy.ops.render.render(animation=True)
print("encoded", len(files), "frames ->", out)
