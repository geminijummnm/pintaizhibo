#!/bin/bash
set -euo pipefail

# 路径配置
WORKSPACE="$(pwd)"
URL_DIR="${WORKSPACE}/sources/url"  # 明确指定URL文件目录
M3U_DIR="${WORKSPACE}/m3u"
mkdir -p "${M3U_DIR}"

echo "🛠️ 初始化验证"
echo "URL目录: ${URL_DIR}"
echo "M3U目录: ${M3U_DIR}"
echo "目录结构:"
tree -L 3

process_url_file() {
    local url_file="$1"
    echo "🔍 处理文件: ${url_file}"
    
    # 获取安全文件名
    local title=$(basename "${url_file}" .url | tr ' ' '_')
    local m3u_file="${M3U_DIR}/${title}.m3u"
    
    # 读取URL
    local m3u_url=$(grep -oP '=\K.*' "${url_file}" || echo "")
    if [[ -z "${m3u_url}" ]]; then
        echo "⚠️ 跳过空URL文件: ${url_file}"
        return 1
    fi

    # 临时文件
    local tmp_file="${WORKSPACE}/_temp.json"
    
    # 带重试的请求
    for i in {1..3}; do
        http_code=$(curl -sS -o "${tmp_file}" -w "%{http_code}" -L "${m3u_url}")
        [[ "${http_code}" == "200" ]] && break
        echo "⏳ 请求失败(HTTP ${http_code}), 第${i}次重试..."
        sleep 2
    done

    # 验证响应
    if [[ "${http_code}" != "200" ]]; then
        echo "❌ 最终失败: HTTP ${http_code}"
        return 2
    fi
    
    # 生成M3U
    echo "#EXTM3U" > "${m3u_file}"
    if jq -r '.zhubo[] | "#EXTINF:-1,\(.title)\n\(.address)"' "${tmp_file}" >> "${m3u_file}"; then
        line_count=$(wc -l < "${m3u_file}")
        [[ "${line_count}" -gt 1 ]] && echo "✅ 生成: ${m3u_file} (${line_count}行)" || {
            echo "⚠️ 删除空文件: ${m3u_file}"
            rm -f "${m3u_file}"
        }
    else
        echo "❌ JSON解析失败，原始内容:"
        head -n 3 "${tmp_file}"
        return 3
    fi
}

export -f process_url_file

echo "🔎 开始处理"
find "${URL_DIR}" -name '*.url' -print0 | xargs -0 -I {} bash -c '
    echo "=================================================================="
    process_url_file "{}"
    echo "=================================================================="
'

echo "🏁 全部完成"
