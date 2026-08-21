#!/usr/bin/env bash
# ============================================================
#  Package the self-compiled fcitx5 (>= 5.1.22, SVG support)
#  into a single tarball that Ubuntu users can extract & copy.
#
#  Usage:  bash package-fcitx5.sh [PATCH_DIR]
#  Output: dist/fcitx5-svg-<version>-linux-x86_64.tar.gz
#
#  PATCH_DIR (optional): directory containing patched modules to bundle
#  (libclassicui.so + libnotificationitem.so). If given, these are copied
#  from there instead of from the live system, so the tarball carries the
#  latest candidate-button / tray patches regardless of local state.
#
#  NOTE: Run this on the machine where fcitx5 was compiled from
#  source with librsvg. The tarball is tied to Ubuntu 26.04 x86_64
#  (system libc/libstdc++ match). It packages only the self-built
#  fcitx5 files, NOT apt dependencies (librsvg, librime are installed
#  via apt on the target machine).
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
DIST="$ROOT/dist"
LIBDIR="/usr/lib/x86_64-linux-gnu"
PATCH_DIR="${1:-}"

# ---- resolve version from the installed libFcitx5Core ----
VERSION="$(dpkg-query -W -f='${Version}' fcitx5 2>/dev/null || true)"
[ -n "$VERSION" ] || VERSION="$(basename $(readlink -f "$LIBDIR/libFcitx5Core.so") | sed 's/.*\.so\.//')"
[ -n "$VERSION" ] || VERSION="5.1.22"
echo "Detected fcitx5 version: $VERSION"

# ---- staging data/ directory (relative paths preserved) ----
STAGE="$ROOT/build/fcitx5-svg"
rm -rf "$STAGE"
mkdir -p "$STAGE/usr/bin" \
         "$STAGE/usr/lib/x86_64-linux-gnu" \
         "$STAGE/usr/lib/x86_64-linux-gnu/fcitx5" \
         "$STAGE/usr/lib/x86_64-linux-gnu/gtk-3.0/3.0.0/immodules" \
         "$STAGE/usr/lib/x86_64-linux-gnu/gtk-4.0/4.0.0/immodules" \
         "$STAGE/usr/lib/x86_64-linux-gnu/gtk-2.0/2.10.0/immodules" \
         "$STAGE/usr/lib/x86_64-linux-gnu/qt5/plugins/platforminputcontexts" \
         "$STAGE/usr/lib/x86_64-linux-gnu/qt6/plugins/platforminputcontexts" \
         "$STAGE/usr/share/fcitx5"

info(){ echo -e "\033[0;32m[✓]\033[0m $1"; }

# 1. binaries
cp -a /usr/bin/fcitx5 /usr/bin/fcitx5-configtool /usr/bin/fcitx5-diagnose \
      /usr/bin/fcitx5-remote /usr/bin/fcitx5-gtk2-immodule-probing \
      /usr/bin/fcitx5-gtk3-immodule-probing /usr/bin/fcitx5-gtk4-immodule-probing \
      /usr/bin/fcitx5-qt5-immodule-probing /usr/bin/fcitx5-qt6-immodule-probing \
      "$STAGE/usr/bin/"
info "Binaries"

# 2. core libs (fcitx5-self-built ones only)
cp -a "$LIBDIR"/libFcitx5Core.so* "$LIBDIR"/libFcitx5Config.so* \
      "$LIBDIR"/libFcitx5Utils.so* "$LIBDIR"/libFcitx5GClient.so* \
      "$LIBDIR"/libFcitx5Qt5*.so* "$LIBDIR"/libFcitx5Qt6*.so* \
      "$STAGE/usr/lib/x86_64-linux-gnu/"
info "Core libraries"

# 3. fcitx5 plugins (incl. classicui -> SVG, and rime)
cp -a "$LIBDIR"/fcitx5/libclassicui.so "$LIBDIR"/fcitx5/librime.so \
      "$LIBDIR"/fcitx5/lib*.so \
      "$STAGE/usr/lib/x86_64-linux-gnu/fcitx5/"
# keep the qt6 subdir of the addon dir too
[ -d "$LIBDIR/fcitx5/qt6" ] && cp -a "$LIBDIR/fcitx5/qt6" "$STAGE/usr/lib/x86_64-linux-gnu/fcitx5/"
# 3b. overlay patched modules (candidate-button classicui + tray notificationitem)
if [ -n "$PATCH_DIR" ]; then
  [ -f "$PATCH_DIR/libclassicui.so" ] && cp -f "$PATCH_DIR/libclassicui.so" \
    "$STAGE/usr/lib/x86_64-linux-gnu/fcitx5/libclassicui.so"
  [ -f "$PATCH_DIR/libnotificationitem.so" ] && cp -f "$PATCH_DIR/libnotificationitem.so" \
    "$STAGE/usr/lib/x86_64-linux-gnu/fcitx5/libnotificationitem.so"
  info "Overlaid patched modules from $PATCH_DIR"
fi
info "fcitx5 plugins (classicui/rime/frontends)"

# 4. gtk im modules
cp -a "$LIBDIR/gtk-3.0/3.0.0/immodules/im-fcitx5.so"       "$STAGE/usr/lib/x86_64-linux-gnu/gtk-3.0/3.0.0/immodules/"
cp -a "$LIBDIR/gtk-4.0/4.0.0/immodules/libim-fcitx5.so"    "$STAGE/usr/lib/x86_64-linux-gnu/gtk-4.0/4.0.0/immodules/"
cp -a "$LIBDIR/gtk-2.0/2.10.0/immodules/im-fcitx5.so"      "$STAGE/usr/lib/x86_64-linux-gnu/gtk-2.0/2.10.0/immodules/"
info "GTK im modules"

# 5. qt platforminputcontexts
cp -a "$LIBDIR/qt5/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so" "$STAGE/usr/lib/x86_64-linux-gnu/qt5/plugins/platforminputcontexts/"
cp -a "$LIBDIR/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so" "$STAGE/usr/lib/x86_64-linux-gnu/qt6/plugins/platforminputcontexts/"
info "QT platform input contexts"

# 6. data / config
cp -a /usr/share/fcitx5/*  "$STAGE/usr/share/fcitx5/"
info "share data"

# generate a manifest of the detected version
echo "$VERSION" > "$STAGE/VERSION"

# ---- archive ----
mkdir -p "$DIST"
TARGET="$DIST/fcitx5-svg-${VERSION}-linux-x86_64.tar.gz"
tar -C "$STAGE" -czf "$TARGET" .
rm -rf "$STAGE"
info "Packaged: $TARGET"
echo "--- contents (top) ---"
tar -tzf "$TARGET" | sed -n '1,40p' | sort
echo "... ($(tar -tzf "$TARGET" | wc -l) entries total)"
