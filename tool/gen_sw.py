"""Gera build/web/sw.js a partir de tool/sw_template.js.

Uso (depois do flutter build web):  python3 tool/gen_sw.py build/web

Lista os arquivos do jogo para o cache (sem o CanvasKit, que o navegador
guarda quando usa, e sem arquivos de depuração) e calcula a versão pelo
conteúdo deles: o service worker só muda quando o jogo muda.
"""
import hashlib
import json
import os
import re
import sys

web = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
skip_dirs = {'canvaskit'}
skip_files = {'sw.js', 'flutter_service_worker.js', '.last_build_id', 'version.json'}
# o jogo vem em duas versões (WebAssembly e JS) e o navegador usa uma só:
# o service worker guarda apenas a que este aparelho usa (veja sw_template.js)
entry_files = {'main.dart.wasm', 'main.dart.mjs', 'main.dart.js'}

files = []
for root, dirs, names in os.walk(web):
    rel_root = os.path.relpath(root, web)
    if rel_root.split(os.sep)[0] in skip_dirs:
        continue
    for n in names:
        rel = os.path.normpath(os.path.join(rel_root, n)).replace(os.sep, '/')
        if n in skip_files or n.endswith('.symbols'):
            continue
        files.append(rel)
files.sort()

h = hashlib.sha256()
for f in files:
    h.update(f.encode())
    with open(os.path.join(web, f), 'rb') as fh:
        h.update(fh.read())
version = h.hexdigest()[:16]

boot = open(os.path.join(web, 'flutter_bootstrap.js'), encoding='utf-8').read()
m = re.search(r'"engineRevision":"([0-9a-f]+)"', boot)
engine = m.group(1)[:16] if m else version

# a página entra pelo endereço da pasta ("./"), não por index.html
urls = ['./' if f == 'index.html' else f for f in files if f not in entry_files]
tpl = open(os.path.join(here, 'sw_template.js'), encoding='utf-8').read()
out = (tpl.replace('__VERSAO__', version)
          .replace('__MOTOR__', engine)
          .replace('__ARQUIVOS__', json.dumps(urls, indent=2)))
open(os.path.join(web, 'sw.js'), 'w', encoding='utf-8').write(out)
print(f'sw.js: versão {version}, motor {engine}, {len(urls)} arquivos')
