import os
import re
import requests

def sanitize_filename(name):
    """清理文件名但保留中文"""
    return re.sub(r'[\\/*?:"<>|]', '_', name)

def main():
    base_url = os.getenv('BASE_URL', 'http://api.vipmisss.com:81/mf/')
    json_url = os.getenv('JSON_URL', 'http://api.vipmisss.com:81/mf/json.txt')
    
    try:
        response = requests.get(json_url, timeout=10)
        data = response.json()
    except Exception as e:
        print(f"❌ 数据获取失败: {e}")
        exit(1)

    os.makedirs('sources', exist_ok=True)
    
    for platform in data['pingtai']:
        title = platform['title']
        safe_title = sanitize_filename(title)
        url = f"{base_url}{platform['address']}"
        
        with open(f'sources/{safe_title}.url', 'w', encoding='utf-8') as f:
            f.write(f"{title}={url}")

if __name__ == '__main__':
    main()
