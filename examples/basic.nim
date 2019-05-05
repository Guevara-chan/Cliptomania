# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
# Basic formats coverage for Cliptomania
# Developed in 2019 by V.A. Guevara
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
import strformat, "../src/cliptomania"

# Text data coverage.
let text_data = "Hallo there." 
echo fmt"Adding '{text_data}' to clipboard..."
clip.set_text text_data
if clip.contains_text: echo fmt"Retrieved back: {clip.get_text}"

# Droplist coverage.
let drop_data = @[r"C:\a.txt", r"d:\b.exe"]
echo fmt"---{'\n'}Adding '{drop_data}' to clipboard..."
clip.set_file_drop_list drop_data
if clip.contains_file_drop_list: echo fmt"Retrieved back: {clip.get_file_drop_list}"

# Final clearance.
clip.clear
echo "---\nClipboard content erased."