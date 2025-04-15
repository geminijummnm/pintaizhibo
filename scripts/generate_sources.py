import os
import re
import requests
from urllib.parse import unquote  # 新增URL解码

def sanitize_filename(name):
    """清理文件名并URL解码"""
    decoded = unquote(name)  # 处理%编码字符
    return re.sub(r'[\\/*?:"<>|]', '_', decoded).strip()

def main():
    base_url = os.getenv('BASE_URL', 'http://api.vipmisss.com:81/mf/').rstrip('/') + '/'
    json_url = os.getenv('JSON_URL', 'http://api.vipmisss.com:81/mf/json.txt')
    
    # 创建多级目录
    output_dir = os.path.join('sources', 'url')
    os.makedirs(output_dir, exist_ok=True)

    try:
        response = requests.get(json_url, headers={'User-Agent': 'Mozilla/5.0'}, timeout=15)
        response.raise_for_status()
        data = response.json()
    except Exception as e:
        print(f"❌ 数据获取失败: {str(e)}")
        exit(1)

    success_count = 0
    for platform in data.get('pingtai', []):
        title = sanitize_filename(platform.get('title', '未命名'))
        address = platform.get('address', '').lstrip('/')
        
        if not address:
            continue
        
        # 生成完整URL并验证
        full_url = f"{base_url}{address}"
        if not full_url.startswith(('http://', 'https://')):
            continue
        
        # 写入文件
        file_path = os.path.join(output_dir, f"{title}.url")
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(f"{title}={full_url}")
            success_count += 1
        except Exception as e:
            print(f"❌ 写入失败: {file_path} ({str(e)})")

    print(f"🎉 生成完成: {success_count}个文件 -> sources/url/")

if __name__ == '__main__':
    main()
