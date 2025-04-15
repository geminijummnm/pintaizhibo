#!/bin/bash

mkdir -p m3u

process_url() {
    local title="$1"
    local url="$2"
    local safe_title=$(echo "$title" | tr -cd '[:alnum:]-_')
    
    echo "#EXTM3U" > "m3u/${safe_title}.m3u"
    curl -s "$url" | jq -r '.zhubo[] | "#EXTINF:-1,\(.title)\n\(.address)"' >> "m3u/${safe_title}.m3u"
}

export -f process_url

cat sources/*.url | parallel --colsep '=' 'process_url {1} {2}'
