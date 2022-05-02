#!/usr/bin/env python3
# coding=utf-8
# pylint: disable=anomalous-backslash-in-string
# pylint: disable=C0103
# pylint: disable=missing-function-docstring

import os
import shutil
import re
from tempfile import NamedTemporaryFile
from difflib import Differ
import requests

pj = os.path.join
pn = os.path.normpath

script_path = os.path.dirname(os.path.realpath(__file__))
main_path = pn(script_path+"/..")
temp_path = pj(main_path, "temp")

if os.path.isdir(temp_path):
    shutil.rmtree(temp_path)
os.makedirs(temp_path)
os.chdir(temp_path)


def download(path, url):
    response = requests.get(url, allow_redirects=True)
    with open(path, "w", encoding='utf-8') as f:
        f.write(response.text)


CERT_path = "./CERTHole.temp"
KADhosts_path = "./KADhosts.txt"

download(CERT_path, "https://hole.cert.pl/domains/domains.txt")
download(KADhosts_path,
         "https://raw.githubusercontent.com/FiltersHeroes/KADhosts/master/KADhosts.txt")

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

with open(CERT_path, "r", encoding='utf-8') as CERT, \
        NamedTemporaryFile(dir='.', delete=False) as f_out:
    lines = []
    for line in CERT:
        if not "\n" in line:
            line = line + "\n"
        lines.append(line.replace("www.", ""))
    for line in sorted(set(lines)):
        f_out.write(str(line).encode())
    os.rename(f_out.name, CERT_path)

offline_path = pj(main_path, "exclusions", "CERT_offline.txt")

differ = Differ()
novelties = []
with open(KADhosts_path, "r", encoding='utf-8') as KADhosts, \
        open(CERT_path, "r", encoding='utf-8') as CERT:
    for line in differ.compare(KADhosts.readlines(), CERT.readlines()):
        if line.startswith("+"):
            novelties.append(line.replace("+ ", ""))


if os.path.isfile(offline_path):
    novelties_tmp = []
    with open(offline_path, "r", encoding='utf-8') as offline_list:
        for line in differ.compare(novelties, offline_list.readlines()):
            if line.startswith("-"):
                if not "\n" in line:
                    line = line + "\n"
                novelties_tmp.append(line.replace("- ", ""))

if len(novelties_tmp) > 0:
    novelties = novelties_tmp
    novelties_tmp = []

skip_path = pj(script_path, "CERT_skip.txt")

if os.path.isfile(skip_path):
    with open(skip_path, "r", encoding='utf-8') as skip_list:
        for line in differ.compare(novelties, skip_list.readlines()):
            if line.startswith("-"):
                if not "\n" in line:
                    line = line + "\n"
                novelties_tmp.append(line.replace("- ", ""))

if len(novelties_tmp) > 0:
    novelties = novelties_tmp
    novelties_tmp = []


regex_list = []

if os.path.isfile(offline_path):
    with open(offline_path, "r", encoding='utf-8') as offline_list:
        for line in offline_list:
            line = "^(.*\.)?" + re.escape(line.strip())+"$"
            regex_list.append(re.compile(line))

if os.path.isfile(skip_path):
    with open(skip_path, "r", encoding='utf-8') as skip_list:
        for line in skip_list:
            line = "^(.*\.)?" + re.escape(line.strip())+"$"
            regex_list.append(re.compile(line))

CERT_novelties_path = pj(main_path, "sections", "CERT_novelties.txt")

with open(CERT_novelties_path, "w+", encoding='utf-8') as f_out:
    for entry in novelties:
        for regex in regex_list:
            entry = regex.sub(r'', entry)
        if entry.strip():
            f_out.write(str("||"+entry.strip("\n")+"^$all"+"\n"))

shutil.rmtree(temp_path)
