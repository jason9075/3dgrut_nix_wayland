#!/usr/bin/env bash

ffmpeg -i assets/scene.mp4 -qscale:v 2 -vf "fps=2" assets/scene/frame_%04d.jpg
