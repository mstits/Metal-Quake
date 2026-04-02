#!/bin/bash

# Script to download and extract metal-cpp
set -e

METAL_CPP_URL="https://developer.apple.com/metal/cpp/files/metal-cpp_macOS15_iOS18-beta.zip"
METAL_CPP_DIR="metal-cpp"

if [ ! -d "$METAL_CPP_DIR" ]; then
    echo "Downloading metal-cpp from Apple..."
    curl -O "$METAL_CPP_URL"
    
    echo "Extracting..."
    # The zip usually contains a folder, so we extract it
    unzip -q metal-cpp_macOS15_iOS18-beta.zip
    
    # Clean up
    rm metal-cpp_macOS15_iOS18-beta.zip
    echo "metal-cpp downloaded and extracted to $(pwd)/metal-cpp"
else
    echo "metal-cpp already exists in the project root."
fi
