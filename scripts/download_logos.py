import urllib.request
import os

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

logos = {
    'um.png': 'https://upload.wikimedia.org/wikipedia/en/0/0e/University_of_Mindanao_Logo.png',
    'cjc.png': 'https://cjc.edu.ph/wp-content/uploads/2021/04/cjc-logo-1.png',
    'dssc.png': 'https://dssc.edu.ph/assets/images/logo.png',
    'addu.png': 'https://upload.wikimedia.org/wikipedia/en/thumb/0/02/Ateneo_de_Davao_University_seal.svg/500px-Ateneo_de_Davao_University_seal.svg.png',
    'usep.png': 'https://upload.wikimedia.org/wikipedia/en/thumb/1/1b/University_of_Southeastern_Philippines_seal.svg/500px-University_of_Southeastern_Philippines_seal.svg.png',
    'hcdc.png': 'https://upload.wikimedia.org/wikipedia/en/5/52/Holy_Cross_of_Davao_College_logo.png',
    'spc.png': 'https://spcdavao.edu.ph/wp-content/uploads/2020/09/cropped-spc-seal-trans-192x192.png',
    'uic.png': 'https://uic.edu.ph/wp-content/uploads/2020/09/UIC-Logo.png',
    'feu.png': 'https://upload.wikimedia.org/wikipedia/en/thumb/6/69/Far_Eastern_University_seal.svg/500px-Far_Eastern_University_seal.svg.png',
    'up.png': 'https://upload.wikimedia.org/wikipedia/en/thumb/3/3d/University_of_the_Philippines_seal.svg/500px-University_of_the_Philippines_seal.svg.png',
    'dlsu.png': 'https://upload.wikimedia.org/wikipedia/en/thumb/c/c2/De_La_Salle_University_Seal.svg/500px-De_La_Salle_University_Seal.svg.png',
    'ust.png': 'https://upload.wikimedia.org/wikipedia/en/thumb/2/24/Seal_of_the_University_of_Santo_Tomas.svg/500px-Seal_of_the_University_of_Santo_Tomas.svg.png',
    'jollibee.png': 'https://upload.wikimedia.org/wikipedia/en/thumb/8/84/Jollibee_2011_logo.svg/500px-Jollibee_2011_logo.svg.png',
    'mcdo.png': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/McDonald%27s_Golden_Arches.svg/500px-McDonald%27s_Golden_Arches.svg.png',
    'sm.png': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/25/SM_Supermalls_logo.svg/500px-SM_Supermalls_logo.svg.png',
    'gmall.png': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Gaisano_Grand_Malls_logo.svg/500px-Gaisano_Grand_Malls_logo.svg.png',
    'spmc.png': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Southern_Philippines_Medical_Center_seal.png/500px-Southern_Philippines_Medical_Center_seal.png',
    'deped.png': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Department_of_Education_%28DepEd%29.svg/500px-Department_of_Education_%28DepEd%29.svg.png',
}

out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'logos'))
os.makedirs(out_dir, exist_ok=True)

for fname, url in logos.items():
    fpath = os.path.join(out_dir, fname)
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as response, open(fpath, 'wb') as out_file:
            out_file.write(response.read())
        print(f'Successfully downloaded {fname} ({os.path.getsize(fpath)} bytes)')
    except Exception as e:
        print(f'Failed {fname}: {e}')
