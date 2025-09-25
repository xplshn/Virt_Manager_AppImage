#!/bin/sh
set -eu

WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"
ARCH_DIR="$WORKSPACE/arch"
BOOTSTRAP_DIR="$ARCH_DIR/root.x86_64"

sudo apt-get update
sudo apt-get install -y desktop-file-utils debootstrap schroot perl git wget xz-utils bubblewrap autoconf coreutils

echo "Downloading appimagetool..."
curl -fsSL "https://github.com/pkgforge-dev/appimagetool-uruntime/releases/download/continuous/appimagetool-x86_64.AppImage" -o appimagetool
chmod +x appimagetool

echo "Downloading pelf (latest)..."
PELF_LATEST_URL=$(curl -fsSL "https://api.github.com/repos/xplshn/pelf/releases/latest" | grep -o '"browser_download_url": *"[^"]*pelf_x86_64[^"]*"' | cut -d'"' -f4)
curl -fsSL "${PELF_LATEST_URL}" -o pelf
chmod +x pelf

echo "Getting Arch Linux bootstrap archive..."
curl -fsSL "https://archive.archlinux.org/iso/" -o index.html
BOOTSTRAP_DATE=$(tail -n 3 index.html | awk '{print $2}' | cut -d'/' -f1 | cut -d'"' -f2 | tail -n1)
BOOTSTRAP_URL="https://archive.archlinux.org/iso/${BOOTSTRAP_DATE}/archlinux-bootstrap-x86_64.tar.zst"
echo "Downloading bootstrap: ${BOOTSTRAP_URL}"
curl -fsSL "${BOOTSTRAP_URL}" -o "archlinux-bootstrap-x86_64.tar.zst"
mkdir -p "$ARCH_DIR"
tar xf archlinux-bootstrap-x86_64.tar.zst -C "$ARCH_DIR/"

echo "Setting up chroot environment..."
cp /etc/resolv.conf "$BOOTSTRAP_DIR/etc/"
cp "$WORKSPACE/mirrorlist" "$BOOTSTRAP_DIR/etc/pacman.d/" 2>/dev/null || echo "Warning: mirrorlist not found"
cp "$WORKSPACE/pacman.conf" "$BOOTSTRAP_DIR/etc/" 2>/dev/null || echo "Warning: pacman.conf not found"

echo "Installing packages in chroot..."
sudo chroot "$BOOTSTRAP_DIR" /bin/bash -c "
    pacman -Syyu --noconfirm && \
    pacman -S --noconfirm virt-manager dnsmasq bridge-utils openbsd-netcat swtpm virtiofsd qemu-full jack2 && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/* && \
    sed -i '17,\$ {/^[#] *[a-zA-Z]/s/^# *//}' /etc/locale.gen && \
    locale-gen
"

echo "Downloading bubblewrap..."
# Lucas, replace by `latest` if your releases are reliable
curl -fsSL "https://github.com/lucasmz1/bubblewrap-musl-static/releases/download/7f9bc5f/bwrap-x86_64" -o bwrap
chmod +x bwrap
mv bwrap "$ARCH_DIR/"

echo "Setting up AppBundle files..."
if [ -f "$WORKSPACE/AppRun" ]; then
    cp "$WORKSPACE/AppRun" "$ARCH_DIR/"
    chmod +x "$ARCH_DIR/AppRun"
else
    echo "Error: AppRun file not found"
    exit 1
fi

if [ -f "$WORKSPACE/virt-manager.desktop" ]; then
    cp "$WORKSPACE/virt-manager.desktop" "$ARCH_DIR/"
else
    echo "Warning: virt-manager.desktop not found"
fi

if [ -f "$WORKSPACE/virt-manager.png" ]; then
    cp "$WORKSPACE/virt-manager.png" "$ARCH_DIR/"
else
    echo "Warning: virt-manager.png not found"
fi

mv "$BOOTSTRAP_DIR" "$ARCH_DIR/root/"

echo "Building AppImage..."
ARCH=x86_64 ./appimagetool -n "$ARCH_DIR/"

echo "Building AppBundle..."
./pelf --add-appdir "$ARCH_DIR" --appbundle-id "Virt-Manager-lucasmz1" --output-to "Virt-Manager.dwfs.AppBundle"

echo "Build complete!"

# Lucas, once you have a reliable way to get the version of Virt-Manager, please see: https://pelf.xplshn.com.ar/docs/appbundleid
# Then replace the AppBundleID, the output filename, and the AppImage output filename, so that it is consistent with the way things are done over at:
# https://github.com/pkgforge-dev
# Ofc, it is optional, I just think it'd be a nice improvement.
