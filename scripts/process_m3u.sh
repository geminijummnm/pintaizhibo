#!/bin/bash
set -euo pipefail

# 硬编码绝对路径
WORKSPACE="/home/runner/work/pintaizhibo"
REPO_DIR="${WORKSPACE}/pintaizhibo"
URL_DIR="${REPO_DIR}/sources/url"
M3U_DIR="${WORKSPACE}/m3u"
TMP_FILE="${WORKSPACE}/_temp.json"

# 初始化验证
echo "🔍 路径验证："
echo "工作区根目录 | ${WORKSPACE}"
echo "M3U输出目录  | ${M3U_DIR}"
echo "临时文件     | ${TMP_FILE}"
echo "仓库目录结构："
tree -L 3 "${REPO_DIR}"

# 清理旧文件
find "${M3U_DIR}" -name "*.m3u" -delete
rm -f "${TMP_FILE}" 2>/dev/null || true

process_url_file() {
    local url_file="$1"
    echo "🔍 处理文件: ${url_file}"
    
    # 文件名安全处理（保留中文）
    local raw_title=$(basename "${url_file}" .url)
    local safe_title=$(echo "${raw_title}" | sed 's/[\/\\:*?"<>| ]/_/g')
    local m3u_file="${M3U_DIR}/${safe_title}.m3u"
    
    # 文件名冲突检测
    if [[ -f "${m3u_file}" ]]; then
        echo "⚠️ 文件名冲突，添加时间戳后缀"
        m3u_file="${M3U_DIR}/${safe_title}_$(date +%s).m3u"
    fi

    # 写入权限测试
    echo "📝 测试写入: ${m3u_file}"
    touch "${m3u_file}.test" && rm "${m3u_file}.test"

    # 读取URL
    local m3u_url=$(grep -oP '=\K.*' "${url_file}" || echo "")
    [[ -z "${m3u_url}" ]] && { echo "⚠️ 无效URL，跳过处理"; return 2; }

    # 带重试的请求
    local http_code="000"
    for i in {1..3}; do
        echo "🔗 请求第 ${i} 次: ${m3u_url}"
        http_code=$(curl -sS -o "${TMP_FILE}" -w "%{http_code}" -L "${m3u_url}" || echo "000")
        [[ "${http_code}" == "200" ]] && break
        sleep 2
    done

    # 生成M3U文件
    if [[ "${http_code}" == "200" ]]; then
        echo "#EXTM3U" > "${m3u_file}"
        if jq -r '.zhubo[] | "#EXTINF:-1,\(.title)\n\(.address)"' "${TMP_FILE}" >> "${m3u_file}"; then
            line_count=$(wc -l < "${m3u_file}")
            if [[ "${line_count}" -gt 1 ]]; then
                echo "✅ 生成成功: ${m3u_file} (${line_count}行)"
                return 0
            else
                echo "⚠️ 空文件已删除: ${m3u_file}"
                rm -f "${m3u_file}"
                return 1
            fi
        else
            echo "❌ JSON解析失败，原始内容:"
            head -c 200 "${TMP_FILE}"
            return 4
        fi
    else
        echo "❌ 最终请求失败: HTTP ${http_code}"
        return 3
    fi
}

export M3U_DIR TMP_FILE
export -f process_url_file

echo "🚀 开始批量处理"
find "${URL_DIR}" -name '*.url' -print0 | xargs -0 -I {} bash -c '
    echo "=================================================================="
    process_url_file "{}"
    echo "=================================================================="
'

echo "✅ 所有文件处理完成"
