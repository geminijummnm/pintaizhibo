#!/bin/bash
set -euo pipefail  # 启用严格错误处理

# 环境初始化
WORKSPACE="$(pwd)"
M3U_DIR="${WORKSPACE}/m3u"
SOURCES_DIR="${WORKSPACE}/sources"

echo "🛠️ 初始化工作区"
mkdir -p "${M3U_DIR}"
echo "M3U输出目录: ${M3U_DIR}"

# 文件处理器
process_url_file() {
    local url_file="$1"
    local base_name
    base_name=$(basename "${url_file}" .url)
    local m3u_file="${M3U_DIR}/${base_name}.m3u"
    
    echo "🔍 处理文件: ${url_file}"
    
    # 读取URL
    local m3u_url
    m3u_url=$(grep -oP '=\K.*' "${url_file}" || echo "")
    
    if [[ -z "${m3u_url}" ]]; then
        echo "⚠️ 无效文件格式: ${url_file}"
        return 1
    fi
    
    # 获取M3U数据
    echo "🌐 请求URL: ${m3u_url}"
    if ! response=$(curl -sS -f -L --retry 3 -w "%{http_code}" "${m3u_url}" 2>&1); then
        echo "❌ 请求失败: ${response}"
        return 2
    fi
    
    http_code="${response: -3}"
    content="${response%???}"
    
    if [[ "${http_code}" != "200" ]]; then
        echo "❌ HTTP错误代码: ${http_code}"
        return 3
    fi
    
    # 生成M3U
    echo "#EXTM3U" > "${m3u_file}"
    jq -r '.zhubo[] | "#EXTINF:-1,\(.title)\n\(.address)"' <<< "${content}" >> "${m3u_file}"
    
    # 结果验证
    local line_count
    line_count=$(wc -l < "${m3u_file}")
    if [[ "${line_count}" -gt 1 ]]; then
        echo "✅ 生成成功: ${m3u_file} (${line_count} 行)"
    else
        echo "⚠️ 空文件: ${m3u_file}"
        rm -f "${m3u_file}"
    fi
}

# 主流程
echo "🔎 扫描源文件"
find "${SOURCES_DIR}" -name '*.url' -print0 | while IFS= read -r -d $'\0' file; do
    process_url_file "${file}" || continue
done

echo "🏁 全部处理完成"
