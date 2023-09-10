#!/usr/bin/env python3
# coding=utf-8
# pylint: disable=anomalous-backslash-in-string
# pylint: disable=C0103
# pylint: disable=missing-function-docstring
#
# Usage: update3pExpired.py tpName listOfExpiredDomains.txt

import os
import sys
import shutil
import importlib.util
from tempfile import NamedTemporaryFile
from downloader import download
from cleanup3p import cleanup3p

pj = os.path.join
pn = os.path.normpath

script_path = os.path.dirname(os.path.realpath(__file__))
main_path = pn(script_path+"/..")
temp_path = pj(main_path, "temp")

if os.path.isdir(temp_path):
    shutil.rmtree(temp_path)
os.makedirs(temp_path)
os.chdir(temp_path)

tp = sys.argv[1]
tp_path = "./" + tp + ".txt"

if tp == "CERT":
    download(tp_path, "https://hole.cert.pl/domains/domains.txt")
elif tp == "LWS":
    import findSuspiciousDomains_LWS as findLWS
    with open(tp_path, "w", encoding='utf-8') as tp_f:
        for domain in findLWS.main():
            tp_f.write(domain + "\n")

cleanup3p(tp_path)

expired_path = sys.argv[2]

with open(tp_path, "r", encoding='utf-8') as tp_f, \
        NamedTemporaryFile(dir='.', delete=False) as f_out:
    domains = []
    for domain in tp_f:
        if not "\n" in domain:
            domain = domain + "\n"
        domains.append(domain)
    domains = sorted(set(domains))
    for domain in domains:
        f_out.write(str(domain).encode())
    os.rename(f_out.name, tp_path)

tp_e_path = pn(main_path + "/exclusions/" + tp + "_expired.txt")
commonLines = []
with open(expired_path, "r", encoding='utf-8') as expired_f, \
    open(tp_path, "r", encoding='utf-8') as tp_f, \
        open(tp_e_path, "a", encoding='utf-8') as tp_e:

    lines_tp_f = tp_f.readlines()
    for line in expired_f:
        if line := line.strip():
            if any(line in s for s in lines_tp_f):
                commonLines.append(line)
    for commonLine in sorted(set(commonLines)):
        if not "\n" in commonLine:
            commonLine = commonLine + "\n"
        tp_e.write(commonLine)

os.remove(tp_path)

# Sort and remove duplicates
lines = []
with open(tp_e_path, "r", encoding='utf-8') as tp_e:
    for line in tp_e:
        lines.append(line)
    lines = sorted(set(lines))

with open(tp_e_path, "w+", encoding='utf-8') as tp_e:
    for line in lines:
        tp_e.write(line)
