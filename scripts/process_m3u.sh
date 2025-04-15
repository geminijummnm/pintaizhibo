#!/bin/bash
set -euo pipefail

# 硬编码绝对路径（与工作流一致）
WORKSPACE="/home/runner/work/pintaizhibo"
REPO_DIR="${WORKSPACE}/pintaizhibo"
URL_DIR="${REPO_DIR}/sources/url"
M3U_DIR="${WORKSPACE}/m3u"
TMP_FILE="${WORKSPACE}/_temp.json"

# 初始化日志
echo "🔍 路径验证："
echo "工作区根目录 | ${WORKSPACE}"
echo "M3U输出目录  | ${M3U_DIR}"
echo "URL文件目录  | ${URL_DIR}"

# 清理旧文件
find "${M3U_DIR}" -name "*.m3u" -delete
rm -f "${TMP_FILE}" || true

process_url_file() {
    local url_file="$1"
    echo "🔍 处理文件: ${url_file}"

    # 文件名安全处理（保留中文）
    local raw_title=$(basename "${url_file}" .url)
    local safe_title=$(echo "${raw_title}" | sed 's/[\/\\:*?"<>| ]/_/g')
    local m3u_file="${M3U_DIR}/${safe_title}.m3u"

    # 处理文件名冲突
    if [[ -f "${m3u_file}" ]]; then
        echo "⚠️ 文件名冲突，添加时间戳后缀"
        m3u_file="${M3U_DIR}/${safe_title}_$(date +%s).m3u"
    fi

    # 读取URL
    local m3u_url=$(grep -oP '=\K.*' "${url_file}" || echo "")
    if [[ -z "${m3u_url}" ]]; then
        echo "❌ 无效URL，跳过文件"
        return 1
    fi

    # 带重试的请求（最多3次）
    for i in {1..3}; do
        echo "🔗 第 ${i} 次尝试请求: ${m3u_url}"
        if http_code=$(curl -sS -L -o "${TMP_FILE}" -w "%{http_code}" "${m3u_url}"); then
            [[ "$http_code" == "200" ]] && break
        fi
        sleep 2
    done

    # 处理响应
    if [[ "$http_code" != "200" ]]; then
        echo "❌ 请求失败: HTTP ${http_code}"
        return 2
    fi

    # 生成M3U文件
    echo "#EXTM3U" > "${m3u_file}"
    if jq -r '.zhubo[] | "#EXTINF:-1,\(.title)\n\(.address)"' "${TMP_FILE}" >> "${m3u_file}"; then
        line_count=$(wc -l < "${m3u_file}")
        if [[ "$line_count" -gt 1 ]]; then
            echo "✅ 生成成功: ${m3u_file} (${line_count}行)"
        else
            echo "⚠️ 空文件已删除: ${m3u_file}"
            rm -f "${m3u_file}"
        fi
    else
        echo "❌ JSON解析失败"
        return 3
    fi
}

export M3U_DIR TMP_FILE
export -f process_url_file

echo "🚀 开始批量处理URL文件"
find "${URL_DIR}" -name '*.url' -print0 | xargs -0 -I {} bash -c '
    echo "=================================================================="
    process_url_file "{}"
    echo "=================================================================="
'

echo "✅ 所有文件处理完成"
