import urllib.request
import json

headers = {'User-Agent': 'RemindaAcademicApp/1.0 (contact@getreminda.com)'}
url = 'https://en.wikipedia.org/w/api.php?action=query&titles=University_of_Mindanao&prop=images&format=json'
req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        print(data)
except Exception as e:
    print(e)
