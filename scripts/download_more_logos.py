import urllib.request
import json
import os
import time

headers = {'User-Agent': 'RemindaAcademicApp/1.0 (contact@getreminda.com)'}
out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'logos'))
os.makedirs(out_dir, exist_ok=True)

def download_file_by_title(title, out_name):
    # Try en.wikipedia first
    url = f'https://en.wikipedia.org/w/api.php?action=query&titles={urllib.parse.quote(title)}&prop=imageinfo&iiprop=url&format=json'
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            pages = data.get('query', {}).get('pages', {})
            for pid in pages:
                if 'imageinfo' in pages[pid]:
                    img_url = pages[pid]['imageinfo'][0]['url']
                    out_path = os.path.join(out_dir, out_name)
                    img_req = urllib.request.Request(img_url, headers=headers)
                    with urllib.request.urlopen(img_req, timeout=15) as img_resp, open(out_path, 'wb') as f:
                        f.write(img_resp.read())
                    print(f'SAVED from Wikipedia: {out_name} ({os.path.getsize(out_path)} bytes)')
                    return True
    except Exception as e:
        pass

    # Try commons
    url = f'https://commons.wikimedia.org/w/api.php?action=query&titles={urllib.parse.quote(title)}&prop=imageinfo&iiprop=url&format=json'
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            pages = data.get('query', {}).get('pages', {})
            for pid in pages:
                if 'imageinfo' in pages[pid]:
                    img_url = pages[pid]['imageinfo'][0]['url']
                    out_path = os.path.join(out_dir, out_name)
                    img_req = urllib.request.Request(img_url, headers=headers)
                    with urllib.request.urlopen(img_req, timeout=15) as img_resp, open(out_path, 'wb') as f:
                        f.write(img_resp.read())
                    print(f'SAVED from Commons: {out_name} ({os.path.getsize(out_path)} bytes)')
                    return True
    except Exception as e:
        pass

    print(f'FAILED to find: {title}')
    return False

targets = {
    'File:Holy Cross of Davao College logo.png': 'hcdc.png',
    'File:University of San Carlos logo.png': 'usc.png',
    'File:Saint Louis University Philippines logo.svg': 'slu.png',
    'File:Xavier University – Ateneo de Cagayan seal.svg': 'xavier.png',
    'File:Notre Dame of Dadiangas University logo.png': 'nddu.png',
    'File:West Visayas State University seal.png': 'wvsu.png',
    'File:Far Eastern University seal.svg': 'feu.png',
    'File:Southern Philippines Medical Center seal.png': 'spmc.png',
    'File:SM Supermalls logo.svg': 'sm.svg',
    'File:Gaisano Grand Malls logo.svg': 'gmall.svg',
}

for title, out_name in targets.items():
    download_file_by_title(title, out_name)
    time.sleep(0.5)
