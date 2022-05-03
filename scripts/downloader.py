#!/usr/bin/env python3
# coding=utf-8
# pylint: disable=C0103
# pylint: disable=missing-function-docstring
# pylint: disable=missing-module-docstring
import requests

def download(path, url):
    response = requests.get(url, allow_redirects=True)
    with open(path, "w", encoding='utf-8') as f:
        f.write(response.text)
