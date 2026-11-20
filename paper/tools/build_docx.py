"""Build the Word version from the compiled LaTeX source.

usage: python3 build_docx.py <tex> <aux> <out.docx> <figdir>
- labels/citations are resolved from the LaTeX .aux so numbering matches the PDF
- tikz figures are replaced by PNGs rendered from standalone builds (figdir/fig1.png ...)
- the algorithm is rewritten as a numbered list (pandoc drops algorithmic)
"""
import re, subprocess, sys, zipfile, shutil, os, tempfile

tex_path, aux_path, out_path, figdir = sys.argv[1:5]
tex = open(tex_path).read()
aux = open(aux_path).read()

labels = {k: re.sub(r'\\mbox\s*\{', '', v) for k, v in re.findall(r'\\newlabel\{([^}]+)\}\{\{([^}]*)\}', aux)}
bib = dict(re.findall(r'\\bibcite\{([^}]+)\}\{([^}]+)\}', aux))

body = tex[tex.index(r'\begin{document}'):]

# author block -> plain centred lines
a, b = body.index(r'\author{'), body.index(r'\maketitle')
body = body[:a] + body[b:]
title = re.search(r'\\title\{(.+?)\}\n', tex).group(1)

def cite(m):
    nums = sorted(int(bib[k.strip()]) for k in m.group(1).split(','))
    return '[' + ', '.join(map(str, nums)) + ']'
body = re.sub(r'~?\\cite\{([^}]+)\}', lambda m: ' ' + cite(m) if m.group(0).startswith('~') else cite(m), body)
body = re.sub(r'\\ref\{([^}]+)\}', lambda m: labels[m.group(1)], body)

# figures -> images (in order of appearance)
figs = iter(sorted(f for f in os.listdir(figdir) if f.endswith('.png')))
body = re.sub(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}',
              lambda m: r'\includegraphics[width=3.3in]{' + os.path.join(figdir, next(figs)) + '}',
              body, flags=re.S)

# algorithm -> caption + numbered list
def alg(m):
    cap = re.search(r'\\caption\{(.+?)\}', m.group(0)).group(1)
    return (r'\textbf{Algorithm ' + labels['alg:seg'] + ': ' + cap + r'}\\' + '\n'
            r'\textit{Input:} photo $I$ (EXIF-corrected, longest side $\le 1280$)' '\n'
            r'\begin{enumerate}'
            r'\item $M_1 \gets$ U2Net$(I)$; compute $f_1, s_1$.'
            r'\item If $f_1 \ge 0.25$ and $s_1 \le 0.10$: return $M_1$.'
            r'\item $M_2 \gets$ BiRefNetLite$(I)$; compute $f_2$.'
            r'\item If $f_2 > f_1$: return $M_2$; otherwise return $M_1$.'
            r'\end{enumerate}')
body = re.sub(r'\\begin\{algorithm\}.*?\\end\{algorithm\}', alg, body, flags=re.S)

# IEEE numbering: "I. Introduction", "A. Dataset ..."; numbered captions
ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X']
state = {'sec': 0, 'sub': 0}
def number(m):
    if m.group(1) == 'section':
        state['sec'] += 1; state['sub'] = 0
        return r'\section*{' + ROMAN[state['sec'] - 1] + '. '
    state['sub'] += 1
    return r'\subsection*{' + chr(64 + state['sub']) + '. '
body = re.sub(r'\\(section|subsection)\{', number, body)
def caption(m):
    env = m.group(0)
    lab = re.search(r'\\label\{([^}]+)\}', env)
    num = labels[lab.group(1)] if lab else '?'
    prefix = 'TABLE ' + num + ': ' if env.startswith(r'\begin{table}') else 'Fig. ' + num + '. '
    return env.replace(r'\caption{', r'\caption{' + prefix, 1)
body = re.sub(r'\\begin\{(table|figure)\}.*?\\end\{\1\}', caption, body, flags=re.S)

# pandoc misparses >{...} column prefixes (eats cell text); Word doesn't need them
body = body.replace(r'>{\raggedright\arraybackslash}', '')

# IEEE keywords -> plain paragraph
body = body.replace(r'\begin{IEEEkeywords}', r'\textbf{\textit{Index Terms}}---').replace(r'\end{IEEEkeywords}', '')

# bibliography -> numbered paragraphs
def biblio(m):
    items = re.split(r'\\bibitem\{([^}]+)\}', m.group(1))[1:]
    out = [r'\section*{References}']
    for key, text in zip(items[::2], items[1::2]):
        out.append(f'[{bib[key]}] ' + ' '.join(text.split()) + '\n')
    return '\n\n'.join(out)
body = re.sub(r'\\begin\{thebibliography\}\{\d+\}(.*?)\\end\{thebibliography\}', biblio, body, flags=re.S)

body = body.replace(r'\maketitle', '').replace(r'\IEEEoverridecommandlockouts', '')
body = body.replace(r'\multicolumn{5}{l}', r'\multicolumn{5}{l}')

pre = r'''\documentclass{article}
\usepackage{amsmath}\usepackage{graphicx}\usepackage{booktabs}
'''
tmp = tempfile.mkdtemp()
src = os.path.join(tmp, 'p.tex')
open(src, 'w').write(pre + body)

ref = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'reference.docx')
subprocess.run(['pandoc', src, '-f', 'latex', '-o', out_path, '--reference-doc', ref,
                '--metadata', f'title={title}'], check=True)

# --- post-process: authors under title, IEEE-style two columns after the keywords
d = tempfile.mkdtemp()
with zipfile.ZipFile(out_path) as z: z.extractall(d)
docp = os.path.join(d, 'word/document.xml')
x = open(docp).read()

def para(text, size, bold=False, italic=False, after=0):
    rpr = f'<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>' + ('<w:b/>' if bold else '') + \
          ('<w:i/>' if italic else '') + f'<w:sz w:val="{size}"/>'
    return (f'<w:p><w:pPr><w:spacing w:before="0" w:after="{after}"/><w:jc w:val="center"/></w:pPr>'
            f'<w:r><w:rPr>{rpr}</w:rPr><w:t xml:space="preserve">{text}</w:t></w:r></w:p>')
authors = (para('Manaswi Bajaj, Atharva Bhargava, Harsh Doshi, Khush Doshi', 22)
           + para('Department of Information Technology, Dwarkadas J. Sanghvi College of Engineering,', 20, italic=True)
           + para('University of Mumbai, Mumbai, India', 20, italic=True)
           + para('Guide: Prof. Neha Ram', 20, italic=True, after=240))
# insert after the title paragraph
i = x.index('</w:p>', x.index('w:val="Title"')) + len('</w:p>')
x = x[:i] + authors + x[i:]

# section break after the Index Terms paragraph: single column above, two columns below
# (US Letter, IEEE margins; child order follows the OOXML schema)
def sect(cols, continuous):
    return ('<w:sectPr>' + ('<w:type w:val="continuous"/>' if continuous else '')
            + '<w:pgSz w:w="12240" w:h="15840"/>'
            + '<w:pgMar w:top="1080" w:right="893" w:bottom="1440" w:left="893" w:header="720" w:footer="720" w:gutter="0"/>'
            + (f'<w:cols w:num="2" w:space="317"/>' if cols == 2 else '<w:cols w:space="720"/>')
            + '</w:sectPr>')
k = x.index('Index Terms')
pend = x.index('</w:p>', k) + len('</w:p>')
x = x[:pend] + '<w:p><w:pPr>' + sect(1, False) + '</w:pPr></w:p>' + x[pend:]
x = re.sub(r'<w:sectPr[^>]*>(?:(?!<w:sectPr).)*?</w:sectPr>(\s*</w:body>)', sect(2, True) + r'\1', x, flags=re.S)
# tables: fit the column width (pandoc sizes them for a full page)
COL = 5000
def fit_table(m):
    tbl = m.group(0)
    cols = [int(w) for w in re.findall(r'<w:gridCol w:w="(\d+)"', tbl)]
    if cols and sum(cols) > 0:
        scale = COL / sum(cols)
        it = iter(round(c * scale) for c in cols)
        tbl = re.sub(r'<w:gridCol w:w="\d+"', lambda _: f'<w:gridCol w:w="{next(it)}"', tbl)
    tbl = re.sub(r'<w:tblW [^>]*/>', f'<w:tblW w:type="dxa" w:w="{COL}" />', tbl)
    # 8pt text inside tables, like IEEE
    tbl = re.sub(r'<w:r>(?!<w:rPr>)', '<w:r><w:rPr><w:sz w:val="16"/></w:rPr>', tbl)
    tbl = re.sub(r'<w:rPr>(?!<w:sz)', '<w:rPr><w:sz w:val="16"/>', tbl)
    # keep each table on one page: every row's paragraphs keep with the next row
    rows = re.findall(r'<w:tr>.*?</w:tr>', tbl, re.S)
    for row in rows[:-1]:
        new = re.sub(r'<w:pPr>(<w:pStyle [^>]*/>)?', lambda m: '<w:pPr>' + (m.group(1) or '') + '<w:keepNext/>', row)
        new = re.sub(r'<w:p>(?!<w:pPr>)', '<w:p><w:pPr><w:keepNext/></w:pPr>', new)
        tbl = tbl.replace(row, new, 1)
    return tbl
x = re.sub(r'<w:tbl>.*?</w:tbl>', fit_table, x, flags=re.S)
open(docp, 'w').write(x)
ct = os.path.join(d, '[Content_Types].xml')
c = open(ct).read()
if 'Extension="png"' not in c:
    c = c.replace('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
                  '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="png" ContentType="image/png"/>', 1)
    open(ct, 'w').write(c)
os.remove(out_path)
with zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(d):
        for f in files:
            full = os.path.join(root, f)
            z.write(full, os.path.relpath(full, d))
print('wrote', out_path)
