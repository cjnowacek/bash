for f in *-*; do mv "$f" "${f%-*}_${f##*-}"; done

