import urllib.request
import json
import os

headers = {'User-Agent': 'RemindaAcademicApp/1.0 (contact@getreminda.com)'}
out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'logos'))
os.makedirs(out_dir, exist_ok=True)

def download_wiki_file(title, out_name):
    url = f'https://en.wikipedia.org/w/api.php?action=query&titles={urllib.parse.quote(title)}&prop=imageinfo&iiprop=url&format=json'
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        pages = data['query']['pages']
        for pid in pages:
            if 'imageinfo' in pages[pid]:
                img_url = pages[pid]['imageinfo'][0]['url']
                print(f'Fetching {title} from {img_url}...')
                img_req = urllib.request.Request(img_url, headers=headers)
                out_path = os.path.join(out_dir, out_name)
                with urllib.request.urlopen(img_req, timeout=15) as img_resp, open(out_path, 'wb') as f:
                    f.write(img_resp.read())
                print(f'SAVED: {out_name} ({os.path.getsize(out_path)} bytes)')
                return True
    return False

files = {
    'File:University of Mindanao Logo.png': 'um.png',
    'File:Holy Cross of Davao College logo.png': 'hcdc.png',
    'File:SM Supermalls logo.svg': 'sm.png',
    'File:Gaisano Grand Malls logo.svg': 'gmall.png',
    'File:Southern Philippines Medical Center seal.png': 'spmc.png',
}

for title, out_name in files.items():
    try:
        download_wiki_file(title, out_name)
    except Exception as e:
        print(f'Error {title}: {e}')
