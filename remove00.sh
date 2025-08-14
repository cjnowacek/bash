for f in *00?*; do echo mv "$f" "${f//00/0}"; done

