#!/bin/bash
set -euo pipefail

# 初始化路径变量
WORKSPACE="$(pwd)"
SOURCES_DIR="${WORKSPACE}/sources"
M3U_DIR="${WORKSPACE}/m3u"

echo "🛠️ 初始化工作区"
mkdir -p "${M3U_DIR}"
echo "M3U输出目录: ${M3U_DIR}"

process_url_file() {
    local url_file="$1"
    echo "🔍 处理文件: ${url_file}"
    
    # 验证文件存在性
    if [ ! -f "${url_file}" ]; then
        echo "❌ 文件不存在: ${url_file}"
        return 1
    fi
    
    # 提取标题和URL
    local title=$(basename "${url_file}" .url)
    local m3u_url=$(grep -oP '=\K.*' "${url_file}" || echo "")
    
    if [ -z "${m3u_url}" ]; then
        echo "⚠️ 未找到有效URL: ${url_file}"
        return 2
    fi
    
    # 发送请求
    echo "🌐 请求URL: ${m3u_url}"
    local http_code
    http_code=$(curl -sS -o response.txt -w "%{http_code}" -L --retry 3 "${m3u_url}")
    
    # 验证HTTP状态码
    if [ "${http_code}" != "200" ]; then
        echo "❌ HTTP错误代码: ${http_code}"
        return 3
    fi
    
    # 生成M3U文件（修复路径错误）
    local m3u_file="${M3U_DIR}/${title}.m3u"  # 关键修复：使用正确路径
    echo "#EXTM3U" > "${m3u_file}"
    
    # 使用jq解析JSON
    if ! jq -r '.zhubo[] | "#EXTINF:-1,\(.title)\n\(.address)"' response.txt >> "${m3u_file}"; then
        echo "❌ JSON解析失败: ${m3u_url}"
        return 4
    fi
    
    # 验证文件内容
    local line_count=$(wc -l < "${m3u_file}")
    if [ "${line_count}" -le 1 ]; then
        echo "⚠️ 空文件: ${m3u_file}"
        rm -f "${m3u_file}"
    else
        echo "✅ 成功生成: ${m3u_file} (${line_count} 行)"
    fi
}

export -f process_url_file

# 主流程
echo "🔎 扫描源文件"
find "${SOURCES_DIR}" -name '*.url' -print0 | xargs -0 -I {} bash -c 'process_url_file "$@"' _ {}

echo "🏁 全部处理完成"
