#!/usr/bin/env python3
# coding=utf-8
# pylint: disable=missing-function-docstring
# pylint: disable=missing-module-docstring
import os
import re
from tempfile import NamedTemporaryFile

def cleanup3p(tp_path):
    with open(tp_path, "r", encoding='utf-8') as tp_f, \
            NamedTemporaryFile(dir='.', delete=False, mode="w", encoding='utf-8') as f_out:
        lines = []
        for line in tp_f:
            lines.append(re.sub(r"^www\.", "", line).lower().strip())
        for line in sorted(set(lines)):
            f_out.write(f"{line}\n")
        os.rename(f_out.name, tp_path)
