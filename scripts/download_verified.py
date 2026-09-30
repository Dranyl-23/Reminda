import urllib.request
import os

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

verified_urls = {
    'cjc.png': 'https://www.cjc.edu.ph/wp-content/uploads/2023/04/final-cjc-logo-1.png',
    'dssc.png': 'https://dssc.edu.ph/wp-content/uploads/2025/10/cropped-dssc-logo.png',
    'addu.png': 'https://www.addu.edu.ph/wp-content/uploads/2026/07/cropped-AdDU-Seal-scaled-1-270x270.png',
    'usep.png': 'https://www.usep.edu.ph/wp-content/uploads/2019/04/usep-logo.png',
}

out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'logos'))
os.makedirs(out_dir, exist_ok=True)

for fname, url in verified_urls.items():
    fpath = os.path.join(out_dir, fname)
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=15) as resp, open(fpath, 'wb') as f:
            f.write(resp.read())
        print(f'SUCCESS: {fname} -> {os.path.getsize(fpath)} bytes')
    except Exception as e:
        print(f'ERROR: {fname} -> {e}')
