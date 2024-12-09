#!/usr/bin/env python3
# coding=utf-8
# pylint: disable=anomalous-backslash-in-string
# pylint: disable=missing-function-docstring
# import libraries
import re
from bs4 import BeautifulSoup
import requests

def main():
    # specify the url
    quote_page = 'https://www.legalniewsieci.pl/aktualnosci/podejrzane-sklepy-internetowe'

    # query the website and return the html to the variable ‘page’
    page = requests.get(quote_page).text

    # parse the html using beautiful soup and store in variable `soup`
    soup = BeautifulSoup(page, "html.parser")

    data = soup.find_all('div', class_="ul-unsafe")

    domains = []
    domain_pat = re.compile(r"^https?:\/\/(?:[^@\n]+@)?(?:www\.)?([^:\/\n?]+)")
    for div in data:
        links = div.find_all('a', rel="nofollow")
        for a in links:
            a['href'] = re.sub('http(s)?:\/\/', '', a['href'])
            a['href'] = re.sub('\/(.*)', '', a['href'])
            a['href'] = re.sub('^www[0-9]\.', '', a['href'])
            a['href'] = re.sub('^www\.', '', a['href'])
            if domain_pat.match(a['href']):
                domains.append(a['href'])

    return domains
