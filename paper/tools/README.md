# Rebuilding the paper

From `paper/`, after editing `wardrobe_plus.tex`:

```bash
tectonic --keep-intermediates wardrobe_plus.tex                        # -> wardrobe_plus.pdf (+ .aux)
python3 tools/make_figs.py wardrobe_plus.tex /tmp/wp_figs                # TikZ figures -> PNG
python3 tools/build_docx.py wardrobe_plus.tex wardrobe_plus.aux wardrobe_plus.docx /tmp/wp_figs/
```

You need `tectonic` (`brew install tectonic`), `pandoc` and `poppler`. You can also upload
`wardrobe_plus.tex` to Overleaf: it compiles as is with the IEEEtran class.
