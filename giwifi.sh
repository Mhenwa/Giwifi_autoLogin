#!/bin/sh

# 用法:
#   sh giwifi.sh 账号 密码 [base_url]
# 例子:
#   sh giwifi.sh 12345678901 123456 http://10.100.100.2

UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36'
BASE_URL="${3:-http://10.100.100.2}"
LOGIN_URL="$BASE_URL/gportal/web/login?has_reload=1"
POST_URL="$BASE_URL/gportal/Web/loginAction"

TMP_DIR="/tmp/giwifi.$$"
COOKIE="$TMP_DIR/cookie.txt"
HTML="$TMP_DIR/login.html"
RAW="$TMP_DIR/raw.txt"
PADDED="$TMP_DIR/padded.bin"
RESP="$TMP_DIR/resp.txt"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMP_DIR" || exit 1

if [ $# -lt 2 ]; then
    echo "Usage: sh $0 <user_account> <user_password> [base_url]" >&2
    exit 1
fi

USER_ACCOUNT="$1"
USER_PASSWORD="$2"

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "missing command: $1" >&2
        exit 1
    }
}

need_cmd wget
need_cmd sed
need_cmd grep
need_cmd openssl
need_cmd hexdump
need_cmd awk
need_cmd tr

log() {
    echo "[giwifi] $*"
}

get_input_value() {
    name="$1"
    sed -n "s/.*name=\"$name\" value=\"\\([^\"]*\\)\".*/\\1/p" "$HTML" | head -n 1
}

urlencode() {
    local s="$1"
    local out=""
    local c
    while [ -n "$s" ]; do
        c="$(printf '%s' "$s" | cut -c1)"
        s="$(printf '%s' "$s" | cut -c2-)"
        case "$c" in
            [a-zA-Z0-9.~_-])
                out="${out}${c}"
                ;;
            ' ')
                out="${out}%20"
                ;;
            *)
                hex="$(printf '%s' "$c" | hexdump -ve '1/1 "%.2x"')"
                while [ -n "$hex" ]; do
                    out="${out}%$(printf '%s' "$hex" | cut -c1-2)"
                    hex="$(printf '%s' "$hex" | cut -c3-)"
                done
                ;;
        esac
    done
    printf '%s' "$out"
}

zeropad_file_16() {
    infile="$1"
    outfile="$2"
    size="$(wc -c < "$infile" | tr -d ' ')"
    rem=$((size % 16))
    cp "$infile" "$outfile"
    if [ "$rem" -ne 0 ]; then
        pad=$((16 - rem))
        i=0
        while [ "$i" -lt "$pad" ]; do
            printf '\000' >> "$outfile"
            i=$((i + 1))
        done
    fi
}

fetch_page() {
    log "fetch login page: $LOGIN_URL"
    wget -q -O "$HTML" \
        --save-cookies "$COOKIE" \
        --keep-session-cookies \
        --header="User-Agent: $UA" \
        "$LOGIN_URL"
}

build_form() {
    sign="$(get_input_value sign)"
    sta_vlan="$(get_input_value sta_vlan)"
    sta_port="$(get_input_value sta_port)"
    sta_ip="$(get_input_value sta_ip)"
    nas_ip="$(get_input_value nas_ip)"
    nas_name="$(get_input_value nas_name)"
    last_url="$(get_input_value last_url)"
    request_ip="$(get_input_value request_ip)"
    device_mode="$(get_input_value device_mode)"
    device_type="$(get_input_value device_type)"
    device_os_type="$(get_input_value device_os_type)"
    is_mobile="$(get_input_value is_mobile)"
    iv="$(get_input_value iv)"
    login_type="$(get_input_value login_type)"
    account_type="$(get_input_value account_type)"

    [ -n "$sign" ] || { echo "failed to parse sign" >&2; exit 1; }
    [ -n "$iv" ] || { echo "failed to parse iv" >&2; exit 1; }
    [ "${#iv}" -eq 16 ] || { echo "bad iv length: ${#iv}" >&2; exit 1; }

    body="sign=$(urlencode "$sign")"
    body="$body&sta_vlan=$(urlencode "$sta_vlan")"
    body="$body&sta_port=$(urlencode "$sta_port")"
    body="$body&sta_ip=$(urlencode "$sta_ip")"
    body="$body&nas_ip=$(urlencode "$nas_ip")"
    body="$body&nas_name=$(urlencode "$nas_name")"
    body="$body&last_url=$(urlencode "$last_url")"
    body="$body&request_ip=$(urlencode "$request_ip")"
    body="$body&device_mode=$(urlencode "$device_mode")"
    body="$body&device_type=$(urlencode "$device_type")"
    body="$body&device_os_type=$(urlencode "$device_os_type")"
    body="$body&is_mobile=$(urlencode "$is_mobile")"
    body="$body&iv=$(urlencode "$iv")"
    body="$body&login_type=$(urlencode "$login_type")"
    body="$body&account_type=$(urlencode "$account_type")"
    body="$body&user_account=$(urlencode "$USER_ACCOUNT")"
    body="$body&user_password=$(urlencode "$USER_PASSWORD")"

    printf '%s' "$body" > "$RAW"
    printf '%s' "$iv" > "$TMP_DIR/iv.txt"
}

encrypt_body() {
    iv_ascii="$(cat "$TMP_DIR/iv.txt")"
    iv_hex="$(printf '%s' "$iv_ascii" | hexdump -ve '1/1 "%.2x"')"
    key_hex="$(printf '%s' '1234567887654321' | hexdump -ve '1/1 "%.2x"')"

    zeropad_file_16 "$RAW" "$PADDED"

    openssl enc -aes-128-cbc -K "$key_hex" -iv "$iv_hex" -nopad -base64 -A \
        -in "$PADDED"
}

do_login() {
    iv="$(cat "$TMP_DIR/iv.txt")"
    enc="$(encrypt_body)"

    log "post login action: $POST_URL"
    wget -q -O "$RESP" \
        --load-cookies "$COOKIE" \
        --keep-session-cookies \
        --header="User-Agent: $UA" \
        --header="X-Requested-With: XMLHttpRequest" \
        --header="Origin: $BASE_URL" \
        --header="Referer: $LOGIN_URL" \
        --header="Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        --post-data="data=$(urlencode "$enc")&iv=$(urlencode "$iv")" \
        "$POST_URL"

    cat "$RESP"
    echo
}

fetch_page
build_form
do_login