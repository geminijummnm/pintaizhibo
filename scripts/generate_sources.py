import os
import re
import requests
import json

def sanitize_filename(name):
    """清理非法字符但保留中文"""
    return re.sub(r'[\\/*?:"<>|]', '_', name).strip()

def main():
    base_url = os.getenv('BASE_URL', 'http://api.vipmisss.com:81/mf/').rstrip('/') + '/'
    json_url = os.getenv('JSON_URL', 'http://api.vipmisss.com:81/mf/json.txt')
    
    print(f"🔄 正在获取数据源: {json_url}")

    try:
        # 添加请求头避免反爬虫
        headers = {'User-Agent': 'Mozilla/5.0'}
        response = requests.get(json_url, headers=headers, timeout=15)
        response.raise_for_status()
        data = response.json()
        print("✅ 成功获取JSON数据")
    except Exception as e:
        print(f"❌ 数据获取失败: {str(e)}")
        print(f"原始响应内容: {response.text[:200]}") if 'response' in locals() else ""
        exit(1)

    os.makedirs('sources', exist_ok=True)
    success_count = 0

    for idx, platform in enumerate(data.get('pingtai', []), 1):
        title = platform.get('title', f'未命名_{idx}')
        address = platform.get('address', '')
        if not address:
            print(f"⚠️ 跳过无效条目: {title} (无address字段)")
            continue
        
        # 清理URL路径
        address = address.lstrip('/')
        full_url = f"{base_url}{address}"
        
        # 验证URL格式
        if not full_url.startswith(('http://', 'https://')):
            print(f"❌ 非法URL格式: {full_url}")
            continue
        
        safe_title = sanitize_filename(title)
        file_path = os.path.join('sources', f"{safe_title}.url")
        
        try:
            # 写入文件并验证内容
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(f"{title}={full_url}")
            success_count += 1
            print(f"📄 生成文件: {file_path}")
        except Exception as e:
            print(f"❌ 文件写入失败: {file_path} ({str(e)})")

    print(f"\n🎉 完成! 成功生成 {success_count}/{len(data.get('pingtai', []))} 个源文件")

if __name__ == '__main__':
    main()
