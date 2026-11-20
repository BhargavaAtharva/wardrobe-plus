"""Extract each tikzpicture from a .tex into a standalone PNG (fig1.png, fig2.png...)."""
import re, subprocess, sys, os
tex, outdir = sys.argv[1], sys.argv[2]
t = open(tex).read()
os.makedirs(outdir, exist_ok=True)
pre = r'''\documentclass[border=4pt]{standalone}
\usepackage[T1]{fontenc}\usepackage{newtxtext,newtxmath}\usepackage{amsmath}
\usepackage{tikz}\usetikzlibrary{positioning,arrows.meta,fit,calc}
\usepackage{pgfplots}\pgfplotsset{compat=1.18}
\newlength{\colw}\setlength{\colw}{252pt}
\begin{document}'''
for i, m in enumerate(re.findall(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}', t, re.S), 1):
    body = m.replace(r'\columnwidth', r'\colw')
    f = os.path.join(outdir, f'fig{i}.tex')
    open(f, 'w').write(pre + body + r'\end{document}')
    subprocess.run(['tectonic', '-o', outdir, f], check=True, capture_output=True)
    subprocess.run(['pdftoppm', '-r', '300', '-png', '-singlefile', f[:-4] + '.pdf', f[:-4]], check=True)
    print('fig', i)
