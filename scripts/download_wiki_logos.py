import urllib.request
import os
import time

headers = {
    'User-Agent': 'RemindaAcademicApp/1.0 (https://getreminda.com; info@getreminda.com) PythonUrllib/3.10'
}

wiki_files = {
    'um.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/University_of_Mindanao_Logo.png',
    'addu.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/Ateneo_de_Davao_University_seal.svg',
    'usep.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/University_of_Southeastern_Philippines_seal.svg',
    'hcdc.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/Holy_Cross_of_Davao_College_logo.png',
    'feu.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/Far_Eastern_University_seal.svg',
    'up.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/University_of_the_Philippines_seal.svg',
    'dlsu.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/De_La_Salle_University_Seal.svg',
    'ust.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/Seal_of_the_University_of_Santo_Tomas.svg',
    'jollibee.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/Jollibee_2011_logo.svg',
    'mcdo.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/McDonald%27s_Golden_Arches.svg',
    'sm.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/SM_Supermalls_logo.svg',
    'gmall.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/Gaisano_Grand_Malls_logo.svg',
    'spmc.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/Southern_Philippines_Medical_Center_seal.png',
    'deped.png': 'https://commons.wikimedia.org/wiki/Special:FilePath/Department_of_Education_(DepEd).svg',
}

out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'logos'))
os.makedirs(out_dir, exist_ok=True)

for fname, url in wiki_files.items():
    fpath = os.path.join(out_dir, fname)
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=15) as response, open(fpath, 'wb') as out_file:
            out_file.write(response.read())
        print(f'Successfully downloaded {fname} ({os.path.getsize(fpath)} bytes)')
    except Exception as e:
        print(f'Failed {fname}: {e}')
    time.sleep(1)
