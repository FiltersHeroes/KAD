#!/usr/bin/env python3
# coding=utf-8
# pylint: disable=C0103
# pylint: disable=no-member
# pylint: disable=anomalous-backslash-in-string
# pylint: disable=missing-class-docstring
# pylint: disable=missing-function-docstring
# pylint: disable=line-too-long
#
import os
import re
import json
import shutil
import importlib.util
from tempfile import NamedTemporaryFile
import git
from downloader import download


pj = os.path.join
pn = os.path.normpath
script_path = os.path.dirname(os.path.realpath(__file__))
main_path = pn(script_path+"/..")
config_path = pj(main_path, ".SFLB.config")
temp_path = pj(main_path, "temp")


class conf():
    def __init__(self):
        if os.path.isfile(config_path):
            with open(config_path, "r", encoding="utf8") as cf:
                for lineConf in cf:
                    cfProperty = lineConf.strip().split()[
                        0].replace("@", "")
                    if matchC := re.search(r'@'+cfProperty+' (.*)$', lineConf):
                        self[cfProperty] = matchC.group(1)

    def __setitem__(self, key, value):
        setattr(self, key, value)

    def __getitem__(self, key):
        return getattr(self, key)


git_repo = git.Repo(os.path.dirname(os.path.realpath(
    config_path)), search_parent_directories=True)

if "CI" in os.environ and "git_repo" in locals():
    with git_repo.config_writer() as cw:
        if hasattr(conf(), 'CIusername'):
            cw.set_value("user", "name", conf().CIusername).release()
        if hasattr(conf(), 'CIemail'):
            cw.set_value("user", "email", conf().CIemail).release()

if not os.path.exists(temp_path):
    os.mkdir(temp_path)

CERT_NOVELTIES_PATH = pj(main_path, "sections", "CERT_novelties.txt")
PRZEKRETY_PATH = pj(main_path, "sections", "przekrety_CERT.txt")
LWS_NOVELTIES_PATH = pj(main_path, "sections", "LWS_novelties.txt")
PODEJRZANE_PATH = pj(main_path, "sections", "podejrzane_inne_oszustwa.txt")


def combineFiles(file1, file2):
    if os.path.exists(file1):
        if os.stat(file1).st_size != 0:
            with open(file1, "r", encoding='utf-8') as file1_content, open(file2, "r", encoding='utf-8') as file2_content, NamedTemporaryFile(dir=temp_path, delete=False, mode="w", encoding='utf-8') as combined_temp:
                for lineF2 in file2_content:
                    combined_temp.write(lineF2)
                for lineF1 in file1_content:
                    combined_temp.write(lineF1)
            os.replace(combined_temp.name, file2)
            git_repo.index.add(file2)
            if file1 == LWS_NOVELTIES_PATH:
                git_repo.index.commit("Nowości z LWS")
        os.remove(file1)


os.replace(CERT_NOVELTIES_PATH, PRZEKRETY_PATH)
combineFiles(LWS_NOVELTIES_PATH, PODEJRZANE_PATH)


shutil.rmtree(temp_path)

SFLB_path = pn(main_path+"/../ScriptsPlayground/scripts/SFLB.py")
if "CI" in os.environ:
    SFLB_path = "/usr/bin/SFLB.py"
spec = importlib.util.spec_from_file_location(
    "SFLB", SFLB_path)
SFLB = importlib.util.module_from_spec(spec)
spec.loader.exec_module(SFLB)

SFLB.main([pj(main_path, "KAD.txt")], "", "")
SFLB.push([pj(main_path, "KAD.txt")])

os.chdir(pn(main_path+"/.."))

if "CI" in os.environ:
    with git_repo.config_reader() as cr:
        url = cr.get_value('remote "origin"', 'url')
        if url.startswith('http'):
            git.Repo.clone_from(
                "https://github.com/FiltersHeroes/KADhosts.git", pj(os.getcwd(), "KADhosts"))
        else:
            git.Repo.clone_from(
                "git@github.com:FiltersHeroes/KADhosts.git", pj(os.getcwd(), "KADhosts"))

os.chdir(pn("./KADhosts"))
SFLB.main([pj(os.getcwd(), "KADhosts.txt"), pj(
    os.getcwd(), "KADhole.txt"), pj(os.getcwd(), "KADomains.txt"), pj(os.getcwd(), "KADdnsmasq.txt")], "", "")
SFLB.push([pj(os.getcwd(), "KADhosts.txt")])
