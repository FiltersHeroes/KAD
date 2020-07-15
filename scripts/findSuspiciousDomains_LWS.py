# import libraries
from bs4 import BeautifulSoup
import certifi
import urllib3
import re

# specify the url
quote_page = 'https://www.legalniewsieci.pl/aktualnosci/podejrzane-sklepy-internetowe'

# query the website and return the html to the variable ‘page’
http = urllib3.PoolManager(
    cert_reqs='CERT_REQUIRED',
    ca_certs=certifi.where()
)
page = http.request('GET', quote_page)

# parse the html using beautiful soup and store in variable `soup`
soup = BeautifulSoup(page.data, "html5lib")

data = soup.find_all('div', class_="ul-unsafe")

for div in data:
    links = div.find_all('a', rel="nofollow")
    for a in links:
        a['href'] = re.sub('http(s)?:\/\/', '', a['href'])
        a['href'] = re.sub('\/(.*)', '', a['href'])
        a['href'] = re.sub('^www[0-9]\.', '', a['href'])
        a['href'] = re.sub('^www\.', '', a['href'])
        print(a['href'])
