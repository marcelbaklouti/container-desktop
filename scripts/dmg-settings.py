# dmgbuild settings for the Container Desktop installer window.
# Used by scripts/release.sh. Builds the layout headlessly (no Finder/AppleScript),
# so it works locally and in CI. Pass the app path and background via -D defines.
import os.path

application = defines["app"]
appname = os.path.basename(application)

volume_name = "Container Desktop"
format = defines.get("format", "UDZO")

files = [application]
symlinks = {"Applications": "/Applications"}

background = defines["background"]
window_rect = ((200, 140), (660, 400))
default_view = "icon-view"
icon_size = 128
text_size = 1  # Finder's labels are hidden; readable white labels are baked into the background.
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False

icon_locations = {
    appname: (165, 175),
    "Applications": (495, 175),
}
