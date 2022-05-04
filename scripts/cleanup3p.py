#!/usr/bin/env python3
# coding=utf-8
# pylint: disable=missing-function-docstring
# pylint: disable=missing-module-docstring
import os
from tempfile import NamedTemporaryFile

def cleanup3p(tp_path):
    with open(tp_path, "r", encoding='utf-8') as tp_f, \
            NamedTemporaryFile(dir='.', delete=False) as f_out:
        lines = []
        for line in tp_f:
            if not "\n" in line:
                line = line + "\n"
            lines.append(line.replace("www.", "").lower())
        for line in sorted(set(lines)):
            f_out.write(str(line).encode())
        os.rename(f_out.name, tp_path)
