#!/bin/bash


# Install OpenGL headers for the playground
# Use --override-channels to avoid conflicts with nvidia channel's cuda-toolkit spec
conda install -c conda-forge --override-channels mesa-libgl-devel-cos7-x86_64 -y

# Initialize git submodules and install Python requirements
git submodule update --init --recursive
# Use --no-build-isolation so packages can access torch during build
pip install --no-build-isolation -r requirements.txt
pip install --no-build-isolation -e .

echo "Setup completed successfully!"
