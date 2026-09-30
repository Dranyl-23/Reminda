import urllib.request
import json
import os

headers = {'User-Agent': 'RemindaAcademicApp/1.0 (contact@getreminda.com)'}
out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'logos'))
os.makedirs(out_dir, exist_ok=True)

queries = [
    ('mcm.png', 'Mapua Malayan Colleges Mindanao'),
    ('pwc.png', "Philippine Women's College of Davao"),
    ('ddc.png', 'Davao Doctors College'),
    ('brokenshire.png', 'Brokenshire College'),
    ('uic.png', 'University of the Immaculate Conception'),
    ('spc.png', 'San Pedro College'),
]

for out_name, title in queries:
    url = f'https://en.wikipedia.org/w/api.php?action=query&titles={urllib.parse.quote(title)}&prop=pageimages&format=json&pithumbsize=400'
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            pages = data.get('query', {}).get('pages', {})
            for pid in pages:
                thumb = pages[pid].get('thumbnail', {})
                if 'source' in thumb:
                    img_url = thumb['source']
                    img_req = urllib.request.Request(img_url, headers=headers)
                    out_path = os.path.join(out_dir, out_name)
                    with urllib.request.urlopen(img_req, timeout=15) as img_resp, open(out_path, 'wb') as f:
                        f.write(img_resp.read())
                    print(f'SUCCESS: {out_name} ({title}) -> {os.path.getsize(out_path)} bytes')
    except Exception as e:
        print(f'ERROR {title}: {e}')
