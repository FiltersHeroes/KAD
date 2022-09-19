#!/usr/bin/env python3
# coding=utf-8
# pylint: disable=anomalous-backslash-in-string
# pylint: disable=C0103
# pylint: disable=missing-function-docstring

import os
import sys
import shutil
import re
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
KADhosts_path = "./KADhosts.txt"

download(KADhosts_path,
         "https://raw.githubusercontent.com/FiltersHeroes/KADhosts/master/KADhosts.txt")


if tp == "CERT":
    download(tp_path, "https://hole.cert.pl/domains/domains.txt")
elif tp == "LWS":
    import findSuspiciousDomains_LWS as findLWS
    with open(tp_path, "w", encoding='utf-8') as tp_f:
        for domain in findLWS.main():
            tp_f.write(domain + "\n")


with open(KADhosts_path, "r", encoding='utf-8') as KADhosts, \
        NamedTemporaryFile(dir='.', delete=False) as f_out:
    lines = []
    for line in KADhosts:
        result = re.search(r"^0\.0\.0\.0 (.*)", line)
        if result is not None:
            lines.append(result.group(1).replace("www.", ""))
    for line in sorted(set(lines)):
        f_out.write(str(line+"\n").encode())
    os.rename(f_out.name, KADhosts_path)

cleanup3p(tp_path)

expired_path = pj(main_path, "exclusions", tp + "_expired.txt")

KADhosts_list = {}
with open(KADhosts_path, "r", encoding='utf-8') as KADhosts:
    for line in KADhosts:
        if line != "":
            KADhosts_list[line.strip()] = ""

novelties = {}
with open(tp_path, "r", encoding='utf-8') as tp_f:
    for line in tp_f:
        if not line.strip() in KADhosts_list:
            novelties[line.strip()] = ""

if os.path.isfile(expired_path):
    with open(expired_path, "r", encoding='utf-8') as expired_list:
        for line in expired_list:
            if line.strip() in novelties:
                del novelties[line.strip()]

skip_path = pj(main_path, "exclusions", tp + "_skip.txt")
if os.path.isfile(skip_path):
    with open(skip_path, "r", encoding='utf-8') as skip_list:
        for line in skip_list:
            if line.strip() in novelties:
                del novelties[line.strip()]

regex_list = []

if os.path.isfile(expired_path):
    with open(expired_path, "r", encoding='utf-8') as offline_list:
        for line in offline_list:
            line = "^(.*\.)?" + re.escape(line.strip())+"$"
            regex_list.append(re.compile(line))

if os.path.isfile(skip_path):
    with open(skip_path, "r", encoding='utf-8') as skip_list:
        for line in skip_list:
            line = "^(.*\.)?" + re.escape(line.strip())+"$"
            regex_list.append(re.compile(line))

tp_novelties_path = pj(main_path, "sections", tp + "_novelties.txt")

with open(tp_novelties_path, "w+", encoding='utf-8') as f_out:
    for entry in novelties:
        for regex in regex_list:
            entry = regex.sub(r'', entry)
        if entry.strip():
            f_out.write(str("||"+entry.strip("\n")+"^$all"+"\n"))

shutil.rmtree(temp_path)
