# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
# Basic formats coverage for Cliptomania
# Developed in 2019 by V.A. Guevara
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
import "../src/cliptomania"

clip.set_text "Hallo there."
if clip.contains_text: echo clip.get_text()
clip.set_file_drop_list @[r"C:\a.txt"]
if clip.contains_file_drop_list: echo clip.get_file_drop_list()