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
KADomains_path = "./KADomains.txt"

download(KADomains_path,
         "https://raw.githubusercontent.com/FiltersHeroes/KADhosts/master/KADomains.txt")


if tp == "CERT":
    download(tp_path, "https://hole.cert.pl/domains/v2/domains.txt")
elif tp == "LWS":
    import findSuspiciousDomains_LWS as findLWS
    with open(tp_path, "w", encoding='utf-8') as tp_f:
        for domain in findLWS.main():
            tp_f.write(f"{domain}\n")

unnecessary_pat = re.compile(r"^(#|!)")

if tp != "CERT":
    with open(KADomains_path, "r", encoding='utf-8') as KADhosts, \
            NamedTemporaryFile(dir='.', delete=False, mode="w", encoding='utf-8') as f_out:
        lines = []
        for line in KADhosts:
            line = line.strip()
            if not unnecessary_pat.match(line):
                lines.append(re.sub(r"^www\.", "", line))
        for line in sorted(set(lines)):
            f_out.write(f"{line}\n")
        del lines
    os.rename(f_out.name, KADomains_path)

cleanup3p(tp_path)

expired_path = pj(main_path, "exclusions", tp + "_expired.txt")

KADomains_list = {}
if tp != "CERT":
    with open(KADomains_path, "r", encoding='utf-8') as KADhosts:
        for line in KADhosts:
            line = line.strip()
            if line != "":
                KADomains_list[line] = ""

novelties = {}
with open(tp_path, "r", encoding='utf-8') as tp_f:
    for line in tp_f:
        line = line.strip()
        if not line in KADomains_list:
            novelties[line] = ""

if os.path.isfile(expired_path):
    with open(expired_path, "r", encoding='utf-8') as expired_list:
        for line in expired_list:
            line = line.strip()
            if line in novelties:
                del novelties[line]

skip_path = pj(main_path, "exclusions", tp + "_skip.txt")
if os.path.isfile(skip_path):
    with open(skip_path, "r", encoding='utf-8') as skip_list:
        for line in skip_list:
            line = line.strip()
            if line in novelties:
                del novelties[line]

exclusion_f_list = []
if os.path.isfile(expired_path):
    with open(expired_path, "r", encoding='utf-8') as offline_list:
        for line in offline_list:
            if line := line.strip():
                exclusion_f_list.append(re.escape(line))

if os.path.isfile(skip_path):
    with open(skip_path, "r", encoding='utf-8') as skip_list:
        for line in skip_list:
            if line := line.strip():
                exclusion_f_list.append(re.escape(line))

regex_part_domains = '|'.join(exclusion_f_list)
regex_part_domains = f"^(.*\.)?({regex_part_domains})$"
long_regex = re.compile(regex_part_domains)

tp_novelties_path = pj(main_path, "sections", tp + "_novelties.txt")

with open(tp_novelties_path, "w+", encoding='utf-8') as f_out:
    for entry in novelties:
        entry = long_regex.sub(r'', entry)
        if entry := entry.strip():
            f_out.write(f"||{entry}^$all\n")

shutil.rmtree(temp_path)
