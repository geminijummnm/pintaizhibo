import os
import json
import requests
from urllib.parse import quote

def sanitize_filename(name):
    return quote(name.replace('/', '_').replace('\\', '_'), safe='')

def main():
    base_url = os.getenv('BASE_URL', 'http://api.vipmisss.com:81/mf/')
    json_url = os.getenv('JSON_URL', 'http://api.vipmisss.com:81/mf/json.txt')
    
    response = requests.get(json_url)
    data = response.json()
    
    os.makedirs('sources', exist_ok=True)
    
    for platform in data['pingtai']:
        title = platform['title']
        safe_title = sanitize_filename(title)
        url = f"{base_url}{platform['address']}"
        
        with open(f'sources/{safe_title}.url', 'w') as f:
            f.write(f"{title}={url}")

if __name__ == '__main__':
    main()
