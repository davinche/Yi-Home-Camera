#!/bin/sh
dr=`dirname $0`

log() {
    d=$(date +"%Y-%m-%d|%H:%M:%S")
    echo "$d - $@" >> /home/hd1/test/log.txt
    sync
}

get_config() {
    key=$1
    grep "^$1" /home/hd1/test/yi.config | cut -d "=" -f2
}

disable() {
    disableFile=$1
    [ ! -f "${disableFile}.off" ] && mv "$disableFile" "${disableFile}.off"
}

enable() {
    enableFile=$1
    if [ -f "${enableFile}.off" ]; then
        rm "$enableFile" 2>/dev/null
        mv "${enableFile}.off" "$enableFile"
    fi
}

disableScript() {
    script=$1
    disable "$script"
    echo "#!/bin/sh" > "$script"
    chmod 775 ${script}
}

enableScript() {
    script=$1
    enable "$script"
    chmod 775 ${script}
}

# -----------------------------------------------------------------------------
# Setup -----------------------------------------------------------------------
# -----------------------------------------------------------------------------

bootstrap() {
    disable /home/timeout.g726
    disable /home/welcome.g726
}

setupRootPassword() {
    root_pwd=$(get_config ROOT_PASSWORD)
    [ $? -eq 0 ] &&  echo "root:$root_pwd" | chpasswd
}

setupCloud() {
    if [ "$(get_config CLOUD)" == "yes" ]; then
        enableScript /home/watch_process
        enableScript /home/cloud
    else
        disableScript /home/watch_process
        disableScript /home/cloud
    fi
}

setupTimezone() {
    log "seting timezone..."
    TZ=$(get_config TZ)
    TZDisplay=$(($(echo "$TZ" | sed "s/UTC//")*-1))
    if [ $TZDisplay -gt -1 ]; then
        TZDisplay="+${TZDisplay}"
    fi
    echo "UTC${TZDisplay}" > /etc/TZ
}

setupTelnet() {
    if [ "$(get_config TELNET)" == "yes" ]; then
        log "seting up telnet..."
        echo "#!/bin/sh" > /etc/init.d/S88telnet
        echo "telnetd &" >> /etc/init.d/S88telnet
        chmod 755 /etc/init.d/S88telnet
    else
        rm /etc/init.d/S88telnet 2>/dev/null
    fi
}

setupFTP() {
    if [ "$(get_config FTP)" == "yes" ]; then
        log "setting up FTP..."
        echo "#!/bin/sh" > /etc/init.d/S89ftp
        echo "tcpsvd -vE 0.0.0.0 21 ftpd -w / &" >> /etc/init.d/S89ftp
        chmod 755 /etc/init.d/S89ftp
    else
        rm /etc/init.d/S89ftp 2>/dev/null
    fi
}

setupHTTP() {
    if [ "$(get_config HTTP)" == "yes" ]; then
        log "setting up HTTP..."
        if ! cmp $dr/server /home/web/server; then
            mv /home/web/server /home/web/server.backup
            cp $dr/server /home/web/server
            ln -s /home/hd1/record /home/web/
        fi
    fi
}

setupRTSP() {
    if [ "$(get_config RTSP)" == "yes" ]; then
        log "setting up RTSP..."
        versionLetter=`sed -n 's/version=1.8.5.1\(.\)_.*/\1/p' /home/version`

        case $versionLetter in
            M|N) file='M'
                ;;
            J|K|L) file='K'
                ;;
            B|E|F|H|I) file='I'
                ;;
            *) file='None'
                ;;
        esac

        if [ $file != 'None' ]; then
            filename="${dr}/rtspsvr${file}"
            log "rtsp: $filename"
            if test -f $filename; then
                if ! cmp $filename /home/rtspsvr; then
                    test -f /home/rtspsvr && mv /home/rtspsvr /home/rtspsvr.backup
                    cp $filename /home/rtspsvr
                fi
            fi
        else
            log 'rtsp: firmware not supported'
        fi
    fi
}

setupNetwork() {
    cp /home/hd1/test/wpa_supplicant.conf /home/wpa_supplicant.conf
    if [ "$(get_config DHCP)" != "yes" ]; then
        echo "#!/bin/sh" > /etc/init.d/S90Networking
        echo "ifconfig ra0 down" >> /etc/init.d/S90Networking
        echo "ifconfig ra0 $(get_config IP) netmask $(get_config NETMASK)" >> /etc/init.d/S90Networking
        echo "route add default gw $(get_config GATEWAY)" >> /etc/init.d/S90Networking
        echo "ifconfig ra0 up" >> /etc/init.d/S90Networking
        chmod 755 /etc/init.d/S90Networking
    else
        rm /etc/init.d/S90Networking 2>/dev/null
    fi

    ns=$(get_config NAMESERVER)
    if [ -n "$ns" ]; then
        echo "nameserver $ns" > /etc/resolv.conf
    fi

    ntp_server=$(get_config NTP_SERVER)
    if [ -n "$ntp_server" ]; then
        echo "#!/bin/sh" > /etc/init.d/S91NTP
        echo "sleep 30" >> /etc/init.d/S91NTP
        echo "ntpd -q -p ${ntp_server}" >> /etc/init.d/S91NTP
        chmod 755 /etc/init.d/S91NTP
    else
        rm /etc/init.d/S91NTP 2>/dev/null
    fi
}

setupRecord() {
    if [ "$(get_config RECORD)" != "yes" ]; then
        disable /home/mp4record
    fi
}

complete() {
    log "complete..."
    mv $dr/equip_test.sh $dr/equip_test-moved.sh
    reboot
}

bootstrap
setupRootPassword
setupCloud
setupTimezone
setupTelnet
setupFTP
setupHTTP
setupRTSP
setupNetwork
setupRecord
complete
