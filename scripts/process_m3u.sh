#!/bin/bash
set -euo pipefail

# 使用工作流传递的环境变量
WORKSPACE="${WORKSPACE:-/home/runner/work/pintaizhibo}"  # 从环境变量读取
REPO_DIR="${WORKSPACE}/pintaizhibo"
URL_DIR="${REPO_DIR}/sources/url"
M3U_DIR="${WORKSPACE}/m3u"
TMP_FILE="${WORKSPACE}/_temp.json"

# 初始化验证
echo "🔍 路径验证："
echo "工作区根目录 | ${WORKSPACE}"
echo "M3U输出目录  | ${M3U_DIR}"
echo "临时文件     | ${TMP_FILE}"

# 清理旧文件（保留目录结构）
find "${M3U_DIR}" -name "*.m3u" -delete
rm -f "${TMP_FILE}" 2>/dev/null || true

process_url_file() {
    local url_file="$1"
    echo "🔍 处理文件: ${url_file}"
    
    # 文件名安全处理（保留中文）
    local raw_title=$(basename "${url_file}" .url)
    local safe_title=$(echo "${raw_title}" | sed 's/[\/\\:*?"<>| ]/_/g')
    local m3u_file="${M3U_DIR}/${safe_title}.m3u"
    
    # 写入权限测试
    touch "${m3u_file}.test" && rm "${m3u_file}.test"

    # 读取URL并请求
    local m3u_url=$(grep -oP '=\K.*' "${url_file}" || echo "")
    [[ -z "${m3u_url}" ]] && { echo "⚠️ 无效URL，跳过处理"; return 2; }

    # 带重试的请求
    for i in {1..3}; do
        if curl -sS -L -o "${TMP_FILE}" --fail "${m3u_url}"; then
            break
        else
            echo "⏳ 请求失败, 第${i}次重试..."
            sleep 2
        fi
    done

    # 生成M3U文件
    echo "#EXTM3U" > "${m3u_file}"
    if jq -r '.zhubo[] | "#EXTINF:-1,\(.title)\n\(.address)"' "${TMP_FILE}" >> "${m3u_file}"; then
        line_count=$(wc -l < "${m3u_file}")
        if [[ "${line_count}" -gt 1 ]]; then
            echo "✅ 生成成功: ${m3u_file}"
        else
            echo "⚠️ 空文件已删除: ${m3u_file}"
            rm -f "${m3u_file}"
        fi
    else
        echo "❌ JSON解析失败"
        return 1
    fi
}

export M3U_DIR TMP_FILE
export -f process_url_file

echo "🚀 开始处理URL文件"
find "${URL_DIR}" -name '*.url' -print0 | xargs -0 -I {} bash -c '
    echo "=================================================================="
    process_url_file "{}"
    echo "=================================================================="
'

echo "✅ 所有文件处理完成"
