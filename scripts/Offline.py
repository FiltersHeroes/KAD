#!/usr/bin/env python3
# coding=utf-8
"""MIT License

Copyright (c) 2025 Filters Heroes

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."""

# import libraries
from bs4 import BeautifulSoup
import certifi
import urllib3
import sys
import re
import time

# specify the url
subdomains_file = sys.argv[1]
http = urllib3.PoolManager(
    cert_reqs='CERT_REQUIRED',
    ca_certs=certifi.where(),
)
with open(subdomains_file, "r") as a_file:
    for line_page in a_file:
        try:
            # query the website and return the html to the variable ‘page’
            page = http.request('GET', line_page.strip())

            time.sleep(3)

            if page.status != 404:
                # parse the html using Beautiful Soup and store in variable `soup`
                soup = BeautifulSoup(page.data, "html5lib")
                if soup.title:
                    data = soup.title.get_text()
                else:
                    data = "Off"
            else:
                data = "Off"

            text = r'Strona zablokowana|Домен припаркован|Blocked|you found a glitch|Nie znaleziono obiektu|Strona jest zablokowana|Blokada administracyjna|jest utrzymywana na serwerach'
            if re.findall(text, data, flags=re.IGNORECASE):
                print(line_page.strip()+" | ", data)
            elif page.status == 404:
                print(line_page.strip()+" | Status",page.status)
            else:
                print(line_page.strip()+ " | Aktywna?")
        except urllib3.exceptions.NewConnectionError and urllib3.exceptions.MaxRetryError:
             print(line_page.strip()+" | ", 'Offline')
