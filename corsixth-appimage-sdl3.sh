#!/bin/bash
## This runs suitably on LXC Ubuntu 26.10. Not currently tested on any other format/distro
## NOTE: Not suitable for use on Corsix-TH versions prior to v0.71.0 (or pre PR3436)!

set -euo pipefail

# Initialise
echo ":: CorsixTH AppImage Builder ::"
echo " "

echo "Would you like to specify a fork of CorsixTH?"
echo "e.g. lewri to use the fork lewri/CorsixTH; or leave blank to use the upstream."
read -r fork || true

echo "Would you like to specify a branch or tag? (must be at least 0.71.0 or newer)"
echo "e.g. v0.71.0, or leave blank to create an appimage from master"
read -r ver || true

# If $fork is unset or empty, default it to 'CorsixTH'
fork="${fork:-CorsixTH}"
repo_url="https://github.com/$fork/CorsixTH.git"

# Let's make sure we know where we are first
cd / || exit 1

# Check the branch at the fork exists first, so we can exit early if so.
apt-get update && apt-get install -y git

# If $ver is unset or empty, default it to 'master'
ver="${ver:-master}"
# Check the branch specified exists
if ! git ls-remote --exit-code --heads "$repo_url" "$ver" &>/dev/null && ! git ls-remote --exit-code --tags "$repo_url" "$ver" &>/dev/null; then
  echo "Error: '$ver' is neither a branch nor a tag in $repo_url. Exiting..."
  exit 1
fi

# Install packages
apt-get install -y \
    build-essential cmake doxygen ffmpeg graphviz libavfilter-dev libavformat-dev \
    libavutil-dev libavcodec-dev libavdevice-dev libcurl4-openssl-dev libfreetype-dev libflac++-dev \
    libfluidsynth-dev liblua5.4-dev libmikmod-dev libmpg123-dev libogg-dev libsdl3-dev libsdl3-mixer-dev \
    libswresample-dev libswscale-dev libvorbis-dev lua-filesystem luarocks libwhereami-dev \
    librtmidi-dev libjack-jackd2-0 zlib1g wget

## Clone repo
# Clone with specified version set with $ver
if [ -n "$ver" ]; then
    echo "Cloning $ver..."
    git clone "$repo_url" --branch "$ver"
else
# Clone from master if no version set
    echo "Cloning from master..."
    ver="master"
    git clone "$repo_url" --branch "$ver"
fi

# Go to project
cd CorsixTH || exit 1

# Compile
mkdir build
cd build || exit 1
cmake \
    -DCMAKE_INSTALL_PREFIX=../AppDir/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DSEARCH_LOCAL_DATADIRS=ON \
    -DUSE_SOURCE_DATADIRS=OFF \
    -DLUA_INCLUDE_DIR='/usr/include/lua5.4' \
    -DLUA_LIBRARY='/usr/lib/x86_64-linux-gnu/liblua5.4.so' \
    -DCMAKE_INSTALL_RPATH='\$ORIGIN/../lib' \
    -DFETCH_UNICODE_FONT=ON \
    ..
make -j"$(nproc)"
make install

# Get linuxdeploy
wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage

# Copy some deps over manually
luarocks install lpeg --lua-version 5.4
cp  /usr/lib/x86_64-linux-gnu/lua/5.4/lfs.so \
    /usr/local/lib/lua/5.4/lpeg.so \
../AppDir/usr/share/corsix-th/
wget https://github.com/Jacalz/fluid-soundfont/raw/master/SF3/FluidR3.sf3 -P ../AppDir/usr/share/corsix-th

# Make .appimage
./linuxdeploy-x86_64.AppImage \
    --appdir ../AppDir \
    --output appimage \
    --desktop-file ../AppDir/usr/share/applications/com.corsixth.corsixth.desktop \
    --icon-file ../AppDir/usr/share/icons/hicolor/scalable/apps/corsix-th.svg \
    --library=/usr/lib/x86_64-linux-gnu/libjack.so.0

# Rename
if [ -n "$ver" ]
then
  echo "Renaming the AppImage to the version requested."
  mv CorsixTH-x86_64.AppImage CorsixTH-"$ver"-x86_64.AppImage
fi
