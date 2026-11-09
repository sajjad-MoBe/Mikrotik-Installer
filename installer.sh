#!/bin/bash
set -e
_ask() {
	local _redo=0

	read resp
	case "$resp" in
	!)	echo "Type 'exit' to return to setup."
		sh
		_redo=1
		;;
	!*)	eval "${resp#?}"
		_redo=1
		;;
	esac
	return $_redo
}
ask() {
	local _question="$1" _default="$2"
	while :; do
		printf %s "$_question "
		[ -z "$_default" ] || printf "[%s] " "$_default"
		_ask && : ${resp:=$_default} && break
	done
}
ask_until() {
	resp=
	while [ -z "$resp" ] ; do
		ask "$1" "$2"
	done
}
yesno() {
	case $1 in
	[Yy]) return 0;;
	esac
	return 1
}
ask_yesno() {
	while true; do
		ask "$1" "$2"
		case "$resp" in
			Y|y|N|n) break;;
		esac
	done
	yesno "$resp"
}


MSG_ARCH="Arch:"
MSG_BOOTMODE="BootMode:"
MSG_STORAGE_DEVICE="Storage Device:"
MSG_ADDRESS="IP Address:"
MSG_GATEWAY="Gateway:"
MSG_NETWORK="Network:"
MSG_DNS="Domain Name Server:"
MSG_SELECT_VERSION="Select the version you want to install:"
MSG_LTS="long-term (v7)"
MSG_STABLE="stable (v7)"
MSG_LTS6="long-term (v6)"
MSG_STABLE6="stable (v6)"
MSG_PLEASE_CHOOSE="Please choose an option:"
MSG_UNSUPPORTED_ARCH="Error: Unsupported architecture: "
MSG_INVALID_OPTION="Error: Invalid option!"
MSG_ARM64_NOT_SUPPORT_V6="arm64 does not support v6 version for now."
MSG_SELECTED_VERSION="Selected version:"
MSG_FILE_DOWNLOAD="Download file: "
MSG_DOWNLOAD_ERROR="Error: No wget nor curl is installed. Cannot download."
MSG_EXTRACT_ERROR="Error: No unzip nor gunzip is installed. Cannot uncompress."
MSG_DOWNLOAD_FAILED="Error: Download failed!"
MSG_OPERATION_ABORTED="Error: Operation aborted."
MSG_WARNING="Warn: All data on /dev/%s will be lost!"
MSG_REBOOTING="Ok, rebooting..."
MSG_ADMIN_PASSWORD="Admin Password:"
MSG_ERROR_MOUNT="Error: Failed to mount partition"
MSG_ERROR_LOOP="Error: Failed to setup loop device"
MSG_AUTO_RUN_FILE_CREATED="autorun.scr file created."
MSG_AUTO_RUN_FILE_NOT_CREATED="Warn: autorun.scr file create failed"
MSG_CONFIRM_CONTINUE="Do you want to continue? [y/n]"
AUTO_MODE=0
[[ "${AUTO,,}" == "true" ]] && AUTO_MODE=1


show_system_info() {
    ARCH=$(uname -m)
    BOOT_MODE=$( [ -d "/sys/firmware/efi" ] && echo "UEFI" || echo "BIOS" )
    echo "$MSG_ARCH $ARCH"
    echo "$MSG_BOOTMODE $BOOT_MODE"
}

confirm_storage() {
    if [[ -z "$STORAGE" ]]; then
        STORAGE=$(ls /sys/block | grep -vE '^(zram|loop|ram|sr|fd|dm-)' | head -1)
    fi
    if [[ "$AUTO_MODE" -eq 1 ]]; then
        [[ -n "$STORAGE" ]] || { echo "Error: Could not detect a storage device in AUTO mode."; exit 1; }
    else
        ask_until "$MSG_STORAGE_DEVICE" "$STORAGE"
        STORAGE=$resp
    fi
}
confirm_address() {
    ETH=$(ip route show default | grep '^default' | sed -n 's/.* dev \([^\ ]*\) .*/\1/p')
    MAC=$(cat /sys/class/net/$ETH/address  | tr 'a-z' 'A-Z')
    ADDRESS=$(ip addr show $ETH | grep global | cut -d' ' -f 6 | head -n 1)
    GATEWAY=$(ip route list | grep default | cut -d' ' -f 3)
    if [ -f "/etc/resolv.conf" ]; then
        DNS=$(grep '^nameserver' /etc/resolv.conf | awk '{print $2}' | head -n 1)
    fi
    [ -z "$DNS" ] && DNS="8.8.8.8"
    if [[ "$AUTO_MODE" -eq 0 ]]; then
        ask_until "$MSG_ADDRESS" "$ADDRESS"
        ADDRESS=$resp
        ask_until "$MSG_GATEWAY" "$GATEWAY"
        GATEWAY=$resp
    elif [[ -z "$ETH" || -z "$ADDRESS" || -z "$GATEWAY" ]]; then
        echo "Error: Could not detect interface, IP address, or gateway in AUTO mode."
        exit 1
    fi
    ADDRESS_NETWORK=$(detect_address_network "$ADDRESS" "$GATEWAY") || {
        echo "Error: Could not determine the address network."
        exit 1
    }
    echo "$MSG_NETWORK $ADDRESS_NETWORK"
    if [[ "$AUTO_MODE" -eq 0 ]]; then
        ask_until "$MSG_DNS" "$DNS"
        DNS=$resp
    fi
}

ipv4_to_int() {
    local a b c d
    IFS=. read -r a b c d <<< "$1"
    [[ "$a$b$c$d" =~ ^[0-9]+$ ]] || return 1
    (( 10#$a <= 255 && 10#$b <= 255 && 10#$c <= 255 && 10#$d <= 255 )) || return 1
    printf '%u' "$(( (10#$a << 24) | (10#$b << 16) | (10#$c << 8) | 10#$d ))"
}

int_to_ipv4() {
    local value=$1
    printf '%u.%u.%u.%u' \
        "$(( (value >> 24) & 255 ))" \
        "$(( (value >> 16) & 255 ))" \
        "$(( (value >> 8) & 255 ))" \
        "$(( value & 255 ))"
}

detect_address_network() {
    local address=${1%/*} prefix=${1#*/} prefix_num address_int gateway_int mask subnet broadcast
    [[ "$1" == */* && "$prefix" =~ ^[0-9]+$ ]] || return 1
    prefix_num=$((10#$prefix))
    (( prefix_num <= 32 )) || return 1
    address_int=$(ipv4_to_int "$address") || return 1
    gateway_int=$(ipv4_to_int "$2") || return 1
    mask=$(( (0xFFFFFFFF << (32 - prefix_num)) & 0xFFFFFFFF ))
    subnet=$(( address_int & mask ))
    broadcast=$(( subnet | (0xFFFFFFFF ^ mask) ))

    # When the provider routes through an out-of-subnet gateway, RouterOS
    # needs that gateway as the address network to create the connected route.
    if (( gateway_int < subnet || gateway_int > broadcast )); then
        printf '%s' "$2"
    else
        int_to_ipv4 "$subnet"
    fi
}

http_get() {
    local url=$1
    local dest_file=$2
    if command -v curl >/dev/null 2>&1; then
        if [ -z "$dest_file" ]; then
            curl -Ls "$url"
        else
            curl -L -# -o "$dest_file" "$url" || { echo "$MSG_DOWNLOAD_FAILED"; exit 1; }
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [ -z "$dest_file" ]; then
            wget --no-check-certificate -qO- "$url"
        else
            wget --no-check-certificate -O "$dest_file" "$url" || { echo "$MSG_DOWNLOAD_FAILED"; exit 1; }
        fi
    else
        echo "$MSG_DOWNLOAD_ERROR"
        exit 1
    fi
}

extract_zip() {
    local zip_file=$1
    local dest_file=$2
    if command -v unzip >/dev/null 2>&1; then
        unzip -p "$zip_file" > "$dest_file" || { echo "$MSG_EXTRACT_ERROR"; exit 1; }
    elif command -v gunzip >/dev/null 2>&1; then
        gunzip -c "$zip_file" > "$dest_file" || { echo "$MSG_EXTRACT_ERROR"; exit 1; }
    else
        echo "$MSG_EXTRACT_ERROR"
        exit 1
    fi
}


select_version() {
    if [[ -n "$VERSION" ]]; then
        if set_version_family "$VERSION" && image_exists "$VERSION"; then
            echo "$MSG_SELECTED_VERSION $VERSION"
            return
        fi
        echo "Version $VERSION was not found on the official MikroTik download server."
        VERSION=
    fi

    V7_STABLE=$(http_get "https://upgrade.mikrotik.com/routeros/NEWESTa7.stable" | cut -d' ' -f1)
    V7_LTS=$(http_get "https://upgrade.mikrotik.com/routeros/NEWESTa7.long-term" | cut -d' ' -f1)
    if [[ "$ARCH" != "aarch64" ]]; then
        V6_STABLE=$(http_get "https://upgrade.mikrotik.com/routeros/NEWEST6.stable" | cut -d' ' -f1)
        V6_LTS=$(http_get "https://upgrade.mikrotik.com/routeros/NEWEST6.long-term" | cut -d' ' -f1)
    fi

    if [[ "$AUTO_MODE" -eq 1 ]]; then
        VERSION=$V7_STABLE
        set_version_family "$VERSION" || exit 1
        image_exists "$VERSION" || { echo "Error: Latest stable image is unavailable in AUTO mode."; exit 1; }
        echo "$MSG_SELECTED_VERSION $VERSION"
        return
    fi

    while true; do
        case $ARCH in
            x86_64|i386|i486|i586|i686)
                echo "$MSG_SELECT_VERSION"
                echo "1. $MSG_STABLE - $V7_STABLE"
                echo "2. $MSG_LTS - $V7_LTS"
                echo "3. $MSG_STABLE6 - $V6_STABLE"
                echo "4. $MSG_LTS6 - $V6_LTS"
                echo "5. Enter a specific version"
                read -p "$MSG_PLEASE_CHOOSE [1-5] " version_choice
                ;; 
            aarch64)
                echo "$MSG_SELECT_VERSION"
                echo "1. $MSG_STABLE - $V7_STABLE"
                echo "2. $MSG_LTS - $V7_LTS"
                echo "3. Enter a specific version"
                read -p "$MSG_PLEASE_CHOOSE [1-3] " version_choice
                ;; 
            *)
                echo "$MSG_UNSUPPORTED_ARCH $ARCH"
                exit 1
                ;;
        esac
        case $version_choice in
            1) 
                VERSION=$V7_STABLE
                V7=1
                ;;
            2) 
                VERSION=$V7_LTS
                V7=1
                ;;
            3)
                if [[ "$ARCH" == "aarch64" ]]; then
                    ask_until "Enter RouterOS v7 version (for example 7.24.6):" ""
                    VERSION=$resp
                    set_version_family "$VERSION" || continue
                else
                    VERSION=$V6_STABLE
                    V7=0
                fi
                ;;
            4)
                if [[ "$ARCH" == "aarch64" ]]; then
                    echo "$MSG_ARM64_NOT_SUPPORT_V6"
                    continue
                fi
                VERSION=$V6_LTS
                V7=0
                ;;
            5)
                if [[ "$ARCH" == "aarch64" ]]; then
                    ask_until "Enter RouterOS v7 version (for example 7.24.6):" ""
                else
                    ask_until "Enter RouterOS version (for example 7.24.6 or 6.49.18):" ""
                fi
                VERSION=$resp
                set_version_family "$VERSION" || continue
                ;;
            *)
                echo "$MSG_INVALID_OPTION"
                continue
                ;;
        esac
        if ! image_exists "$VERSION"; then
            echo "Version $VERSION is not available for this architecture on the official MikroTik download server."
            continue
        fi
        echo "$MSG_SELECTED_VERSION $VERSION"
        break
    done
}

image_url_for_version() {
    case $ARCH in
        x86_64|i386|i486|i586|i686)
            printf 'https://download.mikrotik.com/routeros/%s/chr-%s.img.zip' "$1" "$1"
            ;;
        aarch64)
            printf 'https://download.mikrotik.com/routeros/%s/chr-%s-arm64.img.zip' "$1" "$1"
            ;;
        *) return 1 ;;
    esac
}

image_exists() {
    local url
    url=$(image_url_for_version "$1") || return 1
    if command -v curl >/dev/null 2>&1; then
        curl -fsIL --max-time 20 "$url" >/dev/null 2>&1
    elif command -v wget >/dev/null 2>&1; then
        wget --spider -q --timeout=20 "$url" >/dev/null 2>&1
    else
        return 1
    fi
}

set_version_family() {
    if [[ ! "$1" =~ ^[0-9]+\.[0-9]+([.][0-9]+)?([a-zA-Z0-9.-]*)?$ ]]; then
        echo "Error: Invalid RouterOS version: $1"
        return 1
    fi
    case "$1" in
        7.*) V7=1 ;;
        6.*)
            if [[ "$ARCH" == "aarch64" ]]; then
                echo "$MSG_ARM64_NOT_SUPPORT_V6"
                return 1
            fi
            V7=0
            ;;
        *) echo "Error: Unsupported version $1 (use a v6.x or v7.x version)"; return 1 ;;
    esac
}

download_image(){
    IMG_URL=$(image_url_for_version "$VERSION") || { echo "$MSG_UNSUPPORTED_ARCH $ARCH"; exit 1; }
    echo "$MSG_FILE_DOWNLOAD $(basename "$IMG_URL")"
    http_get "$IMG_URL" "/tmp/chr.img.zip"
    cd /tmp
    extract_zip "chr.img.zip" chr.img
}

create_autorun() {
    LOOP=$(losetup -f)
    if losetup -P "$LOOP" chr.img; then
        sleep 1
        MNT=/tmp/chr
        mkdir -p $MNT
        PARTITION=$([ "$V7" == 1 ] && echo "p2" || echo "p1")
        if mount "${LOOP}${PARTITION}" "$MNT"; then
            confirm_address
            RANDOM_ADMIN_PASS="$(head -c 512 /dev/urandom | tr -dc 'a-z' | head -c 1)$(head -c 512 /dev/urandom | tr -dc '0-9' | head -c 1)$(head -c 512 /dev/urandom | tr -dc 'a-z0-9' | head -c 3)"
            if [[ "$AUTO_MODE" -eq 0 ]]; then
                ask_until "$MSG_ADMIN_PASSWORD" "$RANDOM_ADMIN_PASS"
                RANDOM_ADMIN_PASS=$resp
            fi
            cat <<EOF > "$MNT/rw/autorun.scr"
/tool mac-server set allowed-interface-list=none 
/tool mac-server mac-winbox set allowed-interface-list=none 
/tool mac-server ping set enabled=no
/ip neighbor discovery-settings set discover-interface-list=none 
/tool bandwidth-server set enabled=no 
/ip dns set allow-remote-requests=no
/user set admin password="$RANDOM_ADMIN_PASS"
/ip dns set servers=$DNS
/ip address add address=$ADDRESS network=$ADDRESS_NETWORK interface=[/interface ethernet get [find mac-address=$MAC] name]
/ip route add gateway=$GATEWAY
EOF
            if [[ "$AUTO_MODE" -eq 0 ]]; then
                cat "$MNT/rw/autorun.scr"
            fi
            echo "$MSG_AUTO_RUN_FILE_CREATED"
            umount $MNT
            losetup -d "$LOOP"
        else
            losetup -d "$LOOP"
            echo "$MSG_ERROR_MOUNT $PARTITION"
            echo "$MSG_AUTO_RUN_FILE_NOT_CREATED"
        fi
    else
        echo "$MSG_ERROR_LOOP"
        echo "$MSG_AUTO_RUN_FILE_NOT_CREATED"
    fi
}


write_reboot() {
	confirm_storage
    printf "$MSG_WARNING\n" "$STORAGE"
	if [[ "$AUTO_MODE" -eq 0 ]]; then
	    ask_yesno "$MSG_CONFIRM_CONTINUE"
	    if [ $? -ne 0 ]; then
	        echo "$MSG_OPERATION_ABORTED"
	        exit 1
	    fi
	fi
    sync
    dd if=chr.img of=/dev/$STORAGE bs=4M conv=fsync
    if [[ "$AUTO_MODE" -eq 1 ]]; then
        echo "RouterOS admin password: $RANDOM_ADMIN_PASS"
        echo "The server is rebooting in 3 seconds."
        sleep 3
    fi
    echo "$MSG_REBOOTING"
    echo 1 > /proc/sys/kernel/sysrq 2>/dev/null || true
    echo b > /proc/sysrq-trigger 2>/dev/null || true
    reboot -f
}

show_system_info
select_version
download_image
create_autorun
write_reboot
exit 0
