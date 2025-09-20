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

if tp == "CERT":
    download(tp_path, "https://hole.cert.pl/domains/v2/domains_ublock.txt")
elif tp == "LWS":
    import findSuspiciousDomains_LWS as findLWS
    with open(tp_path, "w", encoding='utf-8') as tp_f:
        for domain in findLWS.main():
            tp_f.write(f"{domain}\n")

unnecessary_pat = re.compile(r"^(#|!)")

cleanup3p(tp_path)

expired_path = pj(main_path, "exclusions", tp + "_expired.txt")

KADomains_list = {}
KADomains_parts = ["podejrzane_inne_oszustwa.txt", "przekierowujace_do_przekretow.txt", "szybko_wygaszajace.txt", "przekrety.txt", "blogspot.txt"]

if tp != "CERT":
    KADomains_parts.append("przekrety_CERT.txt")

for KADomains_part in KADomains_parts:
    with open(pj(main_path, "sections", KADomains_part), "r", encoding='utf-8') as KADomains_part_content:
        for line in KADomains_part_content:
            line = line.strip()
            if line != "" and not line.startswith("!") and re.match(r"^(0\.0\.0\.0.*|\|\|(?!.*\/).*\^(\$all)?$)", line):
                convertItems = [(r"^[|][|]", ""),
                                (r"\^\$all$", ""),
                                (r"[\^]$", "")]
                for old, new in convertItems:
                    line = re.sub(old, new, line)
                KADomains_list[line] = ""

novelties = {}
with open(tp_path, "r", encoding='utf-8') as tp_f:
    for line in tp_f:
        line = line.strip()
        if line and not line.startswith("!") and not line in KADomains_list:
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
            if line and not line.startswith("!") and line in novelties:
                del novelties[line]

exclusion_f_list = []
if os.path.isfile(expired_path):
    with open(expired_path, "r", encoding='utf-8') as offline_list:
        for line in offline_list:
            line = line.strip()
            if line and not line.startswith("!"):
                exclusion_f_list.append(re.escape(line))

if os.path.isfile(skip_path):
    with open(skip_path, "r", encoding='utf-8') as skip_list:
        for line in skip_list:
            line = line.strip()
            if line and not line.startswith("!"):
                exclusion_f_list.append(re.escape(line))

regex_part_domains = '|'.join(exclusion_f_list)
regex_part_domains = f"^(.*\.)?({regex_part_domains})$"
long_regex = re.compile(regex_part_domains)

tp_novelties_path = pj(main_path, "sections", tp + "_novelties.txt")

with open(tp_novelties_path, "w+", encoding='utf-8') as f_out:
    for entry in novelties:
        entry = long_regex.sub(r'', entry)
        entry = entry.strip()
        if entry:
            f_out.write(f"||{entry}^$all\n")

shutil.rmtree(temp_path)
