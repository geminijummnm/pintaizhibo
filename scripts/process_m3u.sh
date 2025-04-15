#!/bin/bash

# 设置中文环境
export LC_ALL=C.UTF-8

process_file() {
    local file="$1"
    local title=$(basename "$file" .url)
    
    echo "生成: $title.m3u"
    
    mkdir -p m3u
    echo "#EXTM3U" > "m3u/${title}.m3u"
    
    while IFS='=' read -r line_title url; do
        curl -s "$url" | jq -r '.zhubo[] | "#EXTINF:-1,\(.title)\n\(.address)"' >> "m3u/${title}.m3u"
    done < "$file"
}

export -f process_file

# 处理所有.url文件
find sources/ -name "*.url" -exec bash -c 'process_file "$0"' {} \;
