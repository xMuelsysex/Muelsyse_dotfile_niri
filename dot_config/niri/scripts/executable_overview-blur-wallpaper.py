#!/usr/bin/env python3
"""Overview blur wallpaper layer for niri.

Shows a pre-blurred still as a background layer with namespace
``dms:blurwallpaper``. Pair with niri:

    layer-rule {
        match namespace="dms:blurwallpaper"
        place-within-backdrop true
    }

niri only composites that surface into the Overview / inter-workspace
backdrop, so normal desktop wallpaper stays sharp and window thumbnails
are untouched — same path DMS used under Shorin.
"""
from __future__ import annotations

import os
import signal
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("GtkLayerShell", "0.1")

from gi.repository import Gdk, GdkPixbuf, GLib, Gtk, GtkLayerShell  # noqa: E402

NAMESPACE = "dms:blurwallpaper"
DEFAULT_IMAGE = os.path.expanduser(
    "~/.cache/blur-wallpapers/overview/current.png"
)


class BlurWallpaper(Gtk.Window):
    def __init__(self, image_path: str) -> None:
        super().__init__()
        self._image_path = image_path
        self._pixbuf: GdkPixbuf.Pixbuf | None = None
        self._image = Gtk.Image()

        self.set_app_paintable(True)
        self.set_decorated(False)
        self.set_resizable(True)
        self.add(self._image)

        if not GtkLayerShell.is_supported():
            raise SystemExit("wlr-layer-shell not supported on this compositor")

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, NAMESPACE)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BACKGROUND)
        GtkLayerShell.set_exclusive_zone(self, -1)
        GtkLayerShell.set_keyboard_mode(
            self, GtkLayerShell.KeyboardMode.NONE
        )
        for edge in (
            GtkLayerShell.Edge.TOP,
            GtkLayerShell.Edge.BOTTOM,
            GtkLayerShell.Edge.LEFT,
            GtkLayerShell.Edge.RIGHT,
        ):
            GtkLayerShell.set_anchor(self, edge, True)

        self.connect("size-allocate", self._on_size_allocate)
        self.connect("destroy", Gtk.main_quit)

        self._load_pixbuf()
        self.show_all()

    def _load_pixbuf(self) -> None:
        path = self._image_path
        if not path or not os.path.isfile(path):
            raise SystemExit(f"blur image missing: {path}")
        self._pixbuf = GdkPixbuf.Pixbuf.new_from_file(path)
        # First paint uses a temporary size; size-allocate refits cover-crop.
        self._fit(1, 1)

    def _on_size_allocate(self, _widget, allocation) -> None:
        w = max(int(allocation.width), 1)
        h = max(int(allocation.height), 1)
        self._fit(w, h)

    def _fit(self, width: int, height: int) -> None:
        if self._pixbuf is None:
            return
        src_w = self._pixbuf.get_width()
        src_h = self._pixbuf.get_height()
        if src_w <= 0 or src_h <= 0:
            return
        # cover / crop (Noctalia fill_mode = crop)
        scale = max(width / src_w, height / src_h)
        scaled_w = max(int(src_w * scale + 0.5), 1)
        scaled_h = max(int(src_h * scale + 0.5), 1)
        scaled = self._pixbuf.scale_simple(
            scaled_w, scaled_h, GdkPixbuf.InterpType.BILINEAR
        )
        x = max((scaled_w - width) // 2, 0)
        y = max((scaled_h - height) // 2, 0)
        cropped = scaled.new_subpixbuf(
            x, y, min(width, scaled_w), min(height, scaled_h)
        )
        self._image.set_from_pixbuf(cropped)


def main(argv: list[str]) -> int:
    image = argv[1] if len(argv) > 1 else DEFAULT_IMAGE
    # Prefer existing Wayland display from the session.
    if not os.environ.get("WAYLAND_DISPLAY"):
        runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        for cand in ("wayland-1", "wayland-0"):
            if os.path.exists(os.path.join(runtime, cand)):
                os.environ["WAYLAND_DISPLAY"] = cand
                break

    def _exit_graceful(*_args) -> None:
        Gtk.main_quit()

    signal.signal(signal.SIGTERM, _exit_graceful)
    signal.signal(signal.SIGINT, _exit_graceful)

    # Quiet GTK accessibility noise in background services.
    os.environ.setdefault("NO_AT_BRIDGE", "1")

    Gdk.set_program_class("overview-blur-wallpaper")
    win = BlurWallpaper(image)
    # Keep reference so GC does not drop the window.
    win.show_all()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
