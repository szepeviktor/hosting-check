#!/bin/bash

# Hosting (webspace) checker

# Depends:  apt-get install lftp bind9-host
# Depends2: apt-get install curl bind9-host
# Extra:    pip install ansi2html
# Version:  0.2
# Author:   Viktor Szépe <viktor@szepe.net>
# URL:      https://github.com/szepeviktor/hosting-check

## SETTINGS
#  ========
#
## URL with trailing slash
HC_SITE="http://SITE.URL/"
## FTP access
HC_FTP_HOST="FTPHOST"
HC_FTP_WEBROOT="/public_html"
HC_FTP_USER="FTPUSER"
HC_FTP_PASSWORD='FTPPASSWORD'
HC_FTP_ENABLE_TLS="1"
HC_MAILSERVER_IP="MAIN_SMTP_IP"
HC_TIMEZONE="Europe/Budapest"


[ -r .hcrc ] && . .hcrc

#######################

HC_FTP_USERPASS="${HC_FTP_USER},${HC_FTP_PASSWORD}"
HC_SECRETKEY="$(echo "$RANDOM" | md5sum | cut -d' ' -f1)"
HC_DOMAIN="$(sed -r 's|^.*[./]([^./]+\.[^./]+).*$|\1|' <<< "$HC_SITE")"
HC_HOST="$(sed -r 's|^(([a-z]+:)?//)?([a-z0-9.-]+)/.*$|\3|' <<< "$HC_SITE")"
HC_LOG="hc_${HC_HOST//[^a-z]}.vars.log"
HC_DIR="hosting-check/"
HC_UA='Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:24.0) Gecko/20140419 Firefox/24.0 hosting-check/0.2'
HC_CABUNDLE="/etc/ssl/certs/ca-certificates.crt"
## curl or lftp
HC_CURL="1"
which lftp &> /dev/null && HC_CURL="0"

error() {
    echo "$(tput sgr0)$(tput bold)$(tput setaf 7)$(tput setab 1)[hosting-check]$(tput sgr0) $*" >&2
}

fatal() {
    error "$*"
    exit 11
}

msg() {
    echo "$(tput sgr0)$(tput dim)$(tput setaf 0)$(tput setab 2)[hosting-check]$(tput sgr0) $*"
}

codeblock() {
    echo "$(tput sgr0)$(tput bold)$(tput setaf 0)$(tput setab 7)$*$(tput sgr0)"
}

notice() {
    echo "$(tput sgr0)$(tput dim)$(tput setaf 0)$(tput setab 3)[hosting-check]$(tput sgr0) $*"
}

do_ftp() {
    #echo "[DBG] lftp -e $* -u $HC_FTP_USERPASS $HC_FTP_HOST" >&2
    lftp -e "set cmd:interactive off; set net:timeout 5; set net:max-retries 1; set net:reconnect-interval-base 2; set dns:order 'inet inet6'; $*" \
        -u "$HC_FTP_USERPASS" "$HC_FTP_HOST" > /dev/null
}

do_curl() {
    [ -r "$HC_CABUNDLE" ] || fatal "can NOT find certificate authority bundle (${HC_CABUNDLE})"

    #echo "[DBG] curl -v --user '${HC_FTP_USERPASS/,/:}' $*" >&2
    curl -sS --cacert "$HC_CABUNDLE" --connect-timeout 5 --retry 1 --retry-delay 2 --ipv4 \
        --user "${HC_FTP_USERPASS/,/:}" "$@"
}

## generate files
generate() {
    local UNPACKDIR

    UNPACKDIR="$(mktemp --directory)"
    if ! mkdir "${UNPACKDIR}/${HC_DIR}"; then
        fatal "hc directory creation failure"
    fi

    echo -n "hc" > "${UNPACKDIR}/${HC_DIR}ping.html"

    cat << CSS > "${UNPACKDIR}/${HC_DIR}text-css.css"
html {
    color: #222;
    font-size: 1em;
    line-height: 1.4;
}
CSS

    cat << HTML > "${UNPACKDIR}/${HC_DIR}text-html.html"
<!doctype html>
<html lang="hu-HU">
    <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <title>hc</title>
    </head>
    <body>
        <p>Hello world! This is HTML5 Boilerplate.</p>
    </body>
</html>
HTML

    cat << PHP > "${UNPACKDIR}/${HC_DIR}wp-settings.php"
<?php
//dump placeholder
PHP

    cat << HTACCESS > "${UNPACKDIR}/${HC_DIR}.htaccess"
## OPcache
#php_value opcache.enable 0
#php_value opcache.validate_timestamps 1
#php_value opcache.revalidate_freq 0

## APC
#php_value apc.cache_by_default 0

## New Relic
#php_value newrelic.enabled 0

<IfModule mod_setenvif.c>
    SetEnvIf Secret-Key ^%%%SECRETKEY%%%$ hc_allow

    ## Apache < 2.3
    <IfModule !mod_authz_core.c>
        Order deny,allow
        Deny from all
        Allow from env=hc_allow
    </IfModule>

    ## Apache ≥ 2.3
    <IfModule mod_authz_core.c>
        Require env hc_allow
    </IfModule>
</IfModule>
HTACCESS

    # all mime type files
    mime_type "${UNPACKDIR}/${HC_DIR}"

    # PHP query
    if ! cp ./hc-query.php "${UNPACKDIR}/${HC_DIR}hc-query.php"; then
        rm -r "$UNPACKDIR"
        fatal "please download hc-query.php also"
    fi

    # return temp dir
    echo "$UNPACKDIR"
}

log_vars() {
    local VAR_NAME="$1"
    local VALUE="$2"

    # escape double quotes
    echo "${VAR_NAME}=\"${VALUE//\"/\\\"}\"" >> "$HC_LOG"
}

log_end() {
    echo -e "## --END-- ## $(date -R)\n" >> "$HC_LOG"
}

wgetrc() {
	cat <<-WGETRC
		user_agent=${UA}
		header=Secret-Key: ${HC_SECRETKEY}
		timeout=n
		tries=n
	WGETRC
}

wget_def(){
#TODO  WGETRC="<(wgetrc)" wget "$@"
    wget --user-agent="$UA" --header="Secret-Key: ${HC_SECRETKEY}" "$@"
}

php_query() {
    local QUERY="$1"

    wget_def -qO- "${HC_SITE}${HC_DIR}hc-query.php?q=${QUERY}"
}

dnsquery() {
    ## error 1:  empty host
    ## error 2:  invalid answer
    ## error 3:  invalid query type
    ## error 4:  not found

    local TYPE="$1"
    local HOST="$2"
    local ANSWER
    local IP

    # empty host
    [ -z "$HOST" ] && return 1

    # first record only
    IP="$(LC_ALL=C host -t "$TYPE" "$HOST" 2> /dev/null | head -n 1)"
    if ! [ -z "$IP" ] && [ "$IP" = "${IP/ not found:/}" ] && [ "$IP" = "${IP/ has no /}" ]; then
        case "$TYPE" in
            A)
                ANSWER="${IP#* has address }"
                if grep -q "^\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}\$" <<< "$ANSWER"; then
                    echo "$ANSWER"
                else
                    # invalid IP
                    return 2
                fi
            ;;
            MX)
                ANSWER="${IP#* mail is handled by *[0-9] }"
                if grep -q "^[a-z0-9A-Z.-]\+\$" <<< "$ANSWER"; then
                    echo "$ANSWER"
                else
                    # invalid hostname
                    return 2
                fi
            ;;
            PTR)
                ANSWER="${IP#* domain name pointer }"
                if grep -q "^[a-z0-9A-Z.-]\+\$" <<< "$ANSWER"; then
                    echo "$ANSWER"
                else
                    # invalid hostname
                    return 2
                fi
            ;;
            TXT)
                ANSWER="${IP#* domain name pointer }"
                if grep -q "^[a-z0-9A-Z.-]\+\$" <<< "$ANSWER"; then
                    echo "$ANSWER"
                else
                    # invalid hostname
                    return 2
                fi
            ;;
            *)
                # invalid type
                return 3
            ;;
        esac
        return 0
    else
        # not found
        return 4
    fi
}

## check SSL certificate with openssl
## usage: ssl_check "service_name" "port_number" "additional_arguments"
ssl_check() {
    local SSL_NAME="$1"
    local SSL_PORT="$2"
    local SSL_ARGS="$3"
    local NOCERT_REGEX='[A-Za-z0-9+/=]\{64\}'

    notice "${SSL_NAME}:  echo QUIT|openssl s_client -CAfile '${HC_CABUNDLE}' -connect ${HC_FTP_HOST}:${SSL_PORT} ${SSL_ARGS}|grep -v '${NOCERT_REGEX}'"
}


################################
##       CHECKS               ##
################################

## site URL
siteurl() {
    [ "$HC_SITE" = "http://SITE.URL/" ] && fatal "please fill in the SETTINGS / HC_SITE"
    [ "$HC_FTP_HOST" = "FTPHOST" ] && fatal "please fill in the SETTINGS / HC_FTP_HOST"
    [ "$HC_FTP_USERPASS" = "FTPUSER,FTPPASSWORD" ] && fatal "please fill in the SETTINGS / HC_FTP_USERPASS"
    msg "site URL: ${HC_SITE}"
    log_vars "SITEURL" "$HC_SITE"
}

## DNS servers
dns_servers() {
    local NSS
    local NS1
    local NS2
    local DOMI

    if ! dnsquery A "$HC_DOMAIN" > /dev/null; then
        fatal "NOT a live domain (${HC_DOMAIN})"
    fi

    ## host names
    NSS="$(LC_ALL=C host -t NS "$HC_DOMAIN" 2> /dev/null)"
    if ! [ $? = 0 ] || ! [ "$NSS" = "${NSS/ not found:/}" ]; then
        fatal "no nameservers found"
    fi

    NS1="$(head -n1 <<< "$NSS")"
    NS2="$(head -n2 <<< "$NSS" | tail -n +2)"
    NS1="${NS1#* name server }"
    NS2="${NS2#* name server }"
    log_vars "NS1" "$NS1"
    log_vars "NS2" "$NS2"

    ## IP addresses
    NS1="$(dnsquery A "$NS1")"
    if ! [ $? = 0 ]; then
        error "first nameserver problem (${NS1})"
        return
    fi
    NS2="$(dnsquery A "$NS2")"
    if ! [ $? = 0 ]; then
        error "second nameserver problem (${NS2})"
        return
    fi
    notice "first nameserver (${NS1})"
    notice "second nameserver (${NS2})"
    log_vars "NS1IP" "$NS1"
    log_vars "NS2IP" "$NS2"

    ## compare first two octets
    if [ "${NS1%.*.*}" = "${NS2%.*.*}" ]; then
        error "nameservers are in the SAME data center"
    else
        msg "nameservers OK"
    fi

    ## Hungarian "Domi"
    DOMI="$(whois --host whois.nic.hu --port 77 "$HC_DOMAIN")"
    if [ $? = 0 ] && ! [ "${DOMI#M-OK }" = "$DOMI" ]; then
        msg "Domi OK (${DOMI})"
    else
        error "Domi ERROR (${DOMI})"
        notice "Domi documentation:  http://www.domain.hu/domain/regcheck/hibak.html"
    fi

    notice "check DNS:  http://dnscheck.pingdom.com/?domain=${HC_DOMAIN}"
    notice "check DNS:  http://www.dnsinspect.com/${HC_DOMAIN}"
    notice "check DNS:  http://intodns.com/${HC_DOMAIN}"
}

## DNS mail exchangers
dns_email(){
    local MXA
    local MXREV
    local MXREVA
    local SPF_RECORDS

    # not local!
    HC_MX="$(dnsquery MX "$HC_DOMAIN")"
    if [ $? = 0 ]; then
        notice "first MX (${HC_MX})"
    else
        error "NO MX record"
        HC_MX=""
        return
    fi

    # IP of MX
    MXA="$(dnsquery A "$HC_MX")"
    if ! [ $? = 0 ]; then
        error "NO IP of first MX"
        return
    fi
    notice "first MX IP (${MXA})"
    notice "valli:  http://multirbl.valli.org/lookup/${MXA}.html"
    notice "anti-abuse:  http://www.anti-abuse.org/multi-rbl-check-results/?host=${MXA}"

    # PTR of IP
    MXREV="$(dnsquery PTR "$MXA")"
    if ! [ $? = 0 ]; then
        error "NO PTR of first MX IP"
        return
    fi
    if [ "$HC_MX" = "$MXREV" ]; then
        msg "MX PTR is the same"
    else
        notice "MX has other PTR / vanity MX (${MXREV})"
    fi

    # IP of PTR
    MXREVA="$(dnsquery A "$MXREV")"
    if ! [ $? = 0 ]; then
        error "NO reverse MX IP"
        return
    fi
    if [ "$MXA" = "$MXREVA" ]; then
        msg "reverse MX IP OK"
    else
        error "MX IP is different from reverse MX IP (${MXREVA})"
    fi

    # SPF, DKIM records
    SPF_RECORDS="$(LC_ALL=C host -t TXT "$HC_DOMAIN" 2> /dev/null)"
    if ! [ $? = 0 ] || ! [ "$SPF_RECORDS" = "${SPF_RECORDS/ has no /}" ]; then
        error "no SPF found"
    fi
    if [ "$SPF_RECORDS" = "${SPF_RECORDS/v=spf/}" ] || [ "$SPF_RECORDS" = "${SPF_RECORDSS/v=DKIM/}" ]; then
        error "SPF record with HARDFAIL: \"v=spf1 mx a ip4:${HC_MAILSERVER_IP} -all\""
        notice "SPF syntax:  http://www.openspf.org/SPF_Record_Syntax"
        notice "SPF check:  http://mxtoolbox.com/spf.aspx"
        notice "DKIM record:  http://domainkeys.sourceforge.net/ http://www.dkim.org/"
        notice "DKIM check:  http://dkimcore.org/tools/"
        notice "email check:  http://www.brandonchecketts.com/emailtest.php"
    else
        msg "SPF, DKIM OK (${SPF_RECORDS})"
    fi
}

## IP address
dns_ip() {
    local REV_HOSTNAME

    ## not local!
    HC_IP="$(dnsquery A "$HC_HOST")"
    if [ $? = 0 ]; then
        notice "IP address (${HC_IP})"
        log_vars "IPADDRESS" "$HC_IP"
    else
        fatal "has NO valid IP address"
    fi

    REV_HOSTNAME="$(dnsquery PTR "$HC_IP")"
    if [ $? = 0 ]; then
        # remove trailing dot for certificate vaildation
        REV_HOSTNAME="${REV_HOSTNAME%.}"
        notice "reverse hostname (${REV_HOSTNAME})"
        log_vars "REVHOSTNAME" "$REV_HOSTNAME"
    else
        error "NO reverse hostname (${REV_HOSTNAME})"
    fi
}

## domain name
domain() {
    local DOT_HU
    local HC_DOMAINNAME="${HC_DOMAIN%.*}"
    local HC_DOMAINTLD="${HC_DOMAIN##*.}"

    if [ "$HC_DOMAINTLD" = hu ]; then
        ## query domain.hu, convert to UTF-8, look for "class=domainnev", trim
        DOTHU="$(wget -qO- "http://www.domain.hu/domain/domainsearch/?domain=${HC_DOMAINNAME}&tld=${HC_DOMAINTLD}" \
            | iconv -c -f LATIN2 -t UTF-8 \
            | sed -n 's|.*<h3>.*class=domainnev>'"$HC_DOMAIN"'<.*domain név \(.\+\)</h3>.*|\1|p' \
            | sed -r -e 's/<[^>]+>|^\s+|\s+$|\.$//g' -e 's/.*/\L&/')"
        if [ -z "$DOTHU" ]; then
            error "domain registration could NOT be found at NIC"
        else
            notice "domain registration status (${DOTHU})"
        fi
    fi
}

## webserver info
webserver() {
    local WEBSERVER
    local APACHE_MODS

    WEBSERVER="$(wget_def -O /dev/null -S "$HC_SITE" 2>&1 | grep -i "^\s*Server:")"
    notice "webserver (${WEBSERVER#"${WEBSERVER%%[![:space:]]*}"})"  #"
    log_vars "WEBSERVER" "${WEBSERVER##*: }"

    grep -iq "apache" <<< "$WEBSERVER" || return

    APACHE_MODS="$(php_query apachemods)"
    if [ -z "$APACHE_MODS" ]; then
        error "Apache webserver but NO Apache modules"
    elif [ "$APACHE_MODS" = 0 ]; then
        notice "Apache module listing is disabled"
    else
        msg "Apache modules: ${APACHE_MODS}"
    fi
    log_vars "APACHEMODS" "$APACHE_MODS"
}

## keep alive response header
keep_alive() {
    local KEEPA

    if KEEPA="$(wget_def -O /dev/null -S "$HC_SITE" 2>&1 \
        | grep -i "^\s*Connection: Keep-Alive\$")"; then
        msg "keep alive OK"
    else
        #TODO prepend to .htaccess + check with 3 requests
        error "NO keep alive"
        notice "set keep alive header in .htaccess + test:  Header set Connection Keep-Alive"
    fi
}


## create list:  wget -qO- https://github.com/h5bp/html5-boilerplate/raw/master/.htaccess \
##     | grep AddType | sed 's/^.*AddType\s*\([^ ]*\)\s*\(.*\)$/\1 \2/'
mime_type() {
    local ARG="$1"
    local -a MIMES
    local MTYPE
    local MFILE

    MIMES=( \
        audio/mp4 audio-m4a.m4a \
        audio/ogg audio-ogg.ogg \
        application/json app-json.json \
        application/ld+json app-ldjson.jsonld \
        application/javascript app-javascript.js \
        video/mp4 video-mp4.mp4 \
        video/ogg video-ogv.ogv \
        video/webm video-webm.webm \
        video/x-flv video-flv.flv \
        application/font-woff font-woff.woff \
        application/vnd.ms-fontobject font-eot.eot \
        application/x-font-ttf font-ttf.ttf \
        font/opentype font-otf.otf \
        image/svg+xml font-svgz.svgz \
        application/octet-stream app-safari-ext.safariextz \
        application/x-chrome-extension app-chrome-ext.crx \
        application/x-opera-extension app-opera-ext.oex \
        application/x-web-app-manifest+json app-webapp-json.webapp \
        application/x-xpinstall app-firefox-ext.xpi \
        application/xml app-xml.xml \
        image/webp image-webp.webp \
        image/x-icon image-icon.ico \
        image/x-icon image-icon.cur \
        text/cache-manifest text-cache-manifest.appcache \
        text/vtt text-vtt.vtt \
        text/x-component text-htc.htc \
        text/x-vcard text-vcard.vcf \
    )
#TODO? text-html.html, text-css.css, image-gif.gif, image-jpeg.jpg, image-png.png

    # generate files
    if ! [ -z "$ARG" ]; then
        for (( i = 0; i + 1  < ${#MIMES[*]}; i += 2 )); do
            MFILE="${MIMES[$((i + 1))]}"
            echo "$RANDOM" > "${ARG}${MFILE}"
        done
        return
    fi

    for (( i = 0; i + 1  < ${#MIMES[*]}; i += 2 )); do
        MTYPE="${MIMES[$i]}"
        MFILE="${MIMES[$((i + 1))]}"
        if wget_def -O /dev/null -S "${HC_SITE}${HC_DIR}${MFILE}" 2>&1 \
            | grep -qi "^\s*Content-Type: ${MTYPE}\$"; then
            msg "MIME type ${MTYPE} OK"
        else
            #TODO prepend to .htaccess + check again
            error "INCORRECT MIME type for ${MTYPE}"
        fi
    done
    notice "Apache settings:  https://github.com/h5bp/html5-boilerplate/raw/master/.htaccess"
}

## gzip compression
## FIX: h5bp .htaccess
content_compression() {
    local CCOMPR

    if CCOMPR="$(wget_def -O /dev/null -S --header="Accept-Encoding: gzip" "${HC_SITE}${HC_DIR}text-css.css" 2>&1 \
        | grep -i "^\s*Content-Encoding: gzip\$")"; then
        msg "gzip compression OK"
    else
        #TODO prepend to .htaccess + check compression
        error "NO gzip compression"
        notice "Apache settings:  https://github.com/h5bp/html5-boilerplate/raw/master/.htaccess"
    fi
}

## cache control max-age header 11 days - 3 years
## FIX: h5bp .htaccess
content_cache() {
    local CCACHE

    if CCACHE="$(wget_def -O /dev/null -S "${HC_SITE}${HC_DIR}text-css.css" 2>&1 \
        | grep -i "^\s*Cache-Control:.*max-age=[0-9]\{7,9\}\b")"; then
        msg "cache control header OK"
    else
        #TODO prepend to .htaccess + check again
        error "NO cache control header"
        notice "Apache settings:  https://github.com/h5bp/html5-boilerplate/raw/master/.htaccess"
    fi
}

## min. PHP >= 5.4
php_version() {
    local PHP_VERSION

    PHP_VERSION="$(php_query version)"

    # major * 100 + minor
    if [ "$PHP_VERSION" -ge 504 ]; then
        msg "PHP version OK"
    else
        error "PHP 5.4 is twice as FAST (${PHP_VERSION})"
        notice "upgrade PHP"
    fi
    log_vars "PHPVERSION" "$PHP_VERSION"
}

## max PHP memory (>= 256MB)
php_memory() {
    local PHP_MEMORY

    PHP_MEMORY="$(php_query memory)"

    if [ "$PHP_MEMORY" -lt $((256 * 1024 * 1024)) ]; then
        error "LOW PHP memory limit (${PHP_MEMORY})"
        notice "ini_set('memory_limit', '256M');"
    else
        msg "PHP memory limit OK"
    fi
    log_vars "PHPMEMORY" "$PHP_MEMORY"
}

## max PHP execution time (>= 30)
php_exectime() {
    local PHP_EXECTIME

    PHP_EXECTIME="$(php_query exectime)"

    if [ "$PHP_EXECTIME" -ge 30 ]; then
        msg "PHP execution time limit OK"
    else
        error "PHP needs at least 30 seconds (${PHP_EXECTIME})"
        notice "ini_set('max_execution_time', 30);"
    fi
    log_vars "PHPEXECTIME" "$PHP_EXECTIME"
}

## PHP download file
## -----------------
## fopen, gzopen, readfile, file_get_contents - ini_get('allow_url_fopen')
## stream_socket_client function_exists()
## curl_init function_exists()
## function_exists( 'stream_socket_client' )
## function_exists( 'curl_init' ) || ! function_exists( 'curl_exec'
## -----------------
php_http() {
    local PHP_HTTP

    PHP_HTTP="$(php_query http)"

    if [ "$PHP_HTTP" = OK ]; then
        msg "PHP HTTP functions OK"
    else
        error "PHP can NOT download files"
    fi
}

## PHP magic quotes + safe mode + register globals
php_safe() {
    local PHP_SAFE

    PHP_SAFE="$(php_query safe)"

    if [ "$PHP_SAFE" = OK ]; then
        msg "PHP Safe mode etc. OK"
    else
        error "PHP magic quotes || safe mode || register globals ON"
    fi
}

## PHP user ID + FTP user ID
php_uid() {
    local PHP_UID

    PHP_UID="$(php_query uid)"

    if [ "$PHP_UID" = 0 ]; then
        error "PHP/FTP UID missmatch"
    else
        msg "PHP/FTP UID OK (${PHP_UID})"
        log_vars "PHPUID" "$PHP_UID"
    fi
}

## known Server API
php_sapi() {
    local PHP_SAPI

    PHP_SAPI="$(php_query sapi)"

    # complete pattern!
    if grep -q "apache2handler\|cgi-fcgi" <<< "$PHP_SAPI"; then
        msg "PHP Server API OK"
    else
        error "UNKNOWN PHP Server API (${PHP_SAPI})"
    fi
    log_vars "PHPSAPI" "$PHP_SAPI"
}

## must-use and extra PHP extensions
php_extensions() {
    local -a MU_EXTS
    local -a EXTRA_EXTS
    local PHP_EXTS

    MU_EXTS=( \
        pcre "PCRE/preg_match" \
        gd "PHP graphics directly" \
        curl "CURL library" \
        mysqli "MySQL Improved" \
    )

    EXTRA_EXTS=( \
        suhosin "Suhosin advanced protection system" \
        apc "APC opcode cache" \
        xcache "XCacahe" \
        memcache "Memcache (old)" \
        memcached "Memcached" \
        "Zend OPcache" "Zend OPcache" \
        mysql "MySQL (old)" \
        mysqlnd "MySQL Native Driver" \
        pdo_mysql "PHP Data Objects MySQL" \
        imagick "ImageMagick" \
    )

    PHP_EXTS="$(php_query extensions)"

    for (( i = 0; i + 1  < ${#MU_EXTS[*]}; i += 2 )); do
        ENAME="${MU_EXTS[$i]}"
        EDESC="${MU_EXTS[$((i + 1))]}"
            #&& msg "PHP Extension ${EDESC} OK" \
        grep -q "\b${ENAME}\b" <<< "$PHP_EXTS" \
            || error "MISSING PHP extension: ${EDESC}"
    done

    for (( i = 0; i + 1  < ${#EXTRA_EXTS[*]}; i += 2 )); do
        XNAME="${EXTRA_EXTS[$i]}"
        XDESC="${EXTRA_EXTS[$((i + 1))]}"
        grep -q "\b${XNAME}\b" <<< "$PHP_EXTS" \
            && notice "PHP Extension: ${XDESC} OK"
    done

    msg "All PHP Extensions: ${PHP_EXTS}"
    log_vars "PHPEXTENSIONS" "$PHP_EXTS"
}

## timezone
php_timezone() {
    local PHP_TZ

    PHP_TZ="$(php_query timezone)"

    ## unspecific check
    #    ! [ -z "$PHP_TZ" ] && ! [ "$PHP_TZ" = 0 ]
    if [ "$PHP_TZ" = "$HC_TIMEZONE" ]; then
        msg "PHP timezone OK (${PHP_TZ})"
        log_vars "PHPTIMEZONE" "$PHP_TZ"
    else
        error "PHP timezone NOT set (${PHP_TZ})"
        notice "date_default_timezone_set('${HC_TIMEZONE}');"
    fi
}

## MySQL server version
php_mysqli() {
    local PHP_SQL

    PHP_SQL="$(php_query mysqli)"

    if [ -z "$PHP_SQL" ] || [ "$PHP_SQL" = 0 ]; then
        error "can NOT determine MySQL server version"
    else
        notice "MySQL server version: ${PHP_SQL}"
        log_vars "MYSQLVERSION" "$PHP_SQL"
    fi
}

## PHP error reporting
php_logfile() {
    local LOGFILE

    LOGFILE="$(php_query logfile)"

    if [ -z "$LOGFILE" ] || [ "$LOGFILE" = 0 ]; then
        error "LOG dir/file creation failure"
        notice "create log dir and file manually, give 0777 permissions"
    else
        msg "error reporting OK ()"
        notice "copy this snippet to wp-config.php:"
        codeblock "$LOGFILE"
    fi
}

## size of WordPress autoload options
wordpress() {
    notice "WordPress autoload options ($(php_query wpoptions)) bytes"
}

## test SSL in FTP server: 0 - no SSL, 1 - invalid cert, 2 - valid cert
ftp_ssl() {
    local FTPSSL=""
    local FTP_LIST="recls [^.]*"

    ## not local!
    FTPSSL_COMMAND=""

    if [ "$HC_CURL" = 1 ]; then
        FTPSSL="0"
        FTPSSL_COMMAND="curl ftp://"
        log_vars "FTPSSL" "$FTPSSL"
        log_vars "FTPSSLCOMMAND" "$FTPSSL_COMMAND"
        notice "curl: FTP SSL connect level (${FTPSSL})"
#FIXME lftp fails to validate a valid cert
        ssl_check "FTPS" "21" "-starttls ftp"
        return
    fi

#TODO support SFTP

    ## without SSL
    if do_ftp "set ftp:ssl-allow off; ${FTP_LIST}; exit"; then
        FTPSSL="0"
        FTPSSL_COMMAND="set ftp:ssl-allow off;"
        msg "FTP connect without SSL OK"
    else
        notice "FTP can NOT connect without SSL"
    fi

    ## SSL with invalid certificate
    if [ "$HC_FTP_ENABLE_TLS" = 1 ] \
        && do_ftp "set ftp:ssl-force on; set ssl:verify-certificate off; ${FTP_LIST}; exit"; then
        FTPSSL="1"
        FTPSSL_COMMAND="set ssl:verify-certificate off;"
        msg "FTP connect with invalid SSL cert OK"
    else
        notice "FTP can NOT connect with invalid SSL cert"
        ssl_check "FTPS" "21" "-starttls ftp"
    fi

    ## SSL with valid certificate
    if [ "$HC_FTP_ENABLE_TLS" = 1 ] \
        && do_ftp "set ftp:ssl-force on; set ftp:ssl-allow on; ${FTP_LIST}; exit"; then
        FTPSSL="2"
        FTPSSL_COMMAND="set ftp:ssl-allow on;"
        msg "FTP connect with SSL OK"
    else
        notice "FTP can NOT connect with SSL"
        ssl_check "FTPS" "21" "-starttls ftp"
    fi

    if [ -z "$FTPSSL" ]; then
        fatal "FTP connection FAILED"
    else
        log_vars "FTPSSL" "$FTPSSL"
        log_vars "FTPSSLCOMMAND" "$FTPSSL_COMMAND"
        notice "FTP SSL connect level (${FTPSSL})"
    fi
    if [ "$FTPSSL" = 0 ]; then
        notice "ProFTPd  http://www.proftpd.org/docs/contrib/mod_tls.html"
    fi
}

## upload hosting check files
ftp_upload() {
    local UNPACKDIR
    local FILELIST
    local RET

    UNPACKDIR="$(generate)"
    if ! [ $? = 0 ]; then
        fatal "can NOT create temporary dir (${UNPACKDIR})"
    fi

    ## insert secret key
    sed -i "s/%%%SECRETKEY%%%/${HC_SECRETKEY}/g" "${UNPACKDIR}/${HC_DIR}.htaccess" \
        || fatal "secret key insertion failure"
#TODO move to generate()

    if [ "$HC_CURL" = 1 ]; then
        # wp-config.php
        if [ -r ./wp-config.php ]; then
            if ! do_curl -T "{./wp-config.php}" "ftp://${HC_FTP_HOST}${HC_FTP_WEBROOT}/wp-config.php"; then
                fatal "wp-config.php upload failure"
            fi
        fi

        FILELIST="$(find "${UNPACKDIR}/${HC_DIR}" -type f -printf "%p,")"
        do_curl --ftp-create-dirs -T "{${FILELIST%,}}" "ftp://${HC_FTP_HOST}${HC_FTP_WEBROOT}/${HC_DIR}"
        RET="$?"
    else
        # wp-config.php
        if [ -r ./wp-config.php ]; then
            if ! do_ftp "${FTPSSL_COMMAND} cd '${HC_FTP_WEBROOT}'; put ./wp-config.php; exit"; then
                fatal "wp-config.php upload failure"
            fi
        fi

        do_ftp "${FTPSSL_COMMAND} cd '${HC_FTP_WEBROOT}'; mirror -R '${UNPACKDIR}/' .; exit"
        RET="$?"
    fi

    rm -r "$UNPACKDIR" \
        || error "can NOT remove local unpack dir ($?)"

    if [ "$RET" = 0 ]; then
        notice "uploading files OK"
    else
        fatal "can NOT upload hosting check files (${RET})"
    fi
}

## availability of uploaded files
ftp_ping() {
    local PING

    PING="$(wget_def -qO- --tries=1 --timeout=5 --max-redirect=0 "${HC_SITE}${HC_DIR}ping.html" | tr -c -d '[[:print:]]')"

    if [ "$PING" = hc ]; then
        notice "uploaded files are available"
    else
        fatal "could NOT download uploaded files (${PING})"
    fi
}

## delete hosting check files
ftp_destruct() {
    local -a FILES

    if [ "$HC_CURL" = 1 ]; then
        while read FILE; do
            [ -z "${FILE//./}" ] && continue
            FILES+=( -Q "-DELE ${FILE}" )
        done <<< "$(do_curl "ftp://${HC_FTP_HOST}${HC_FTP_WEBROOT}/${HC_DIR}" -l 2> /dev/null)"
        if ! [ $? = 0 ]; then
            error "curl: can NOT get file list"
            error "self distruct failed, DELETE '${HC_DIR}' MANUALLY!"
            notice "curl --user '${HC_FTP_USERPASS/,/:}' 'ftp://${HC_FTP_HOST}${HC_FTP_WEBROOT}/'"
            return
        fi

        ## delete all files one-by-one
        do_curl "ftp://${HC_FTP_HOST}${HC_FTP_WEBROOT}/${HC_DIR}" "${FILES[@]}" > /dev/null
        if ! [ $? = 0 ]; then
            error "curl: can NOT delete files"
            error "self distruct failed, DELETE '${HC_DIR}' MANUALLY!"
            notice "curl --user '${HC_FTP_USERPASS/,/:}' 'ftp://${HC_FTP_HOST}${HC_FTP_WEBROOT}/'"
            return
        fi

        ## delete dir
        do_curl "ftp://${HC_FTP_HOST}${HC_FTP_WEBROOT}/" -Q "-RMD ${HC_DIR}" > /dev/null
        if ! [ $? = 0 ]; then
            error "curl: can NOT delete ${HC_DIR} dir"
            error "self distruct failed, DELETE '${HC_DIR}' MANUALLY!"
            notice "curl --user '${HC_FTP_USERPASS/,/:}' 'ftp://${HC_FTP_HOST}${HC_FTP_WEBROOT}/'"
            return
        fi
        msg "self destruct OK"
    else
        # delete .htaccess separately
        if do_ftp "${FTPSSL_COMMAND} cd '${HC_FTP_WEBROOT}'; rm -f '${HC_DIR}.htaccess'; rm -r '${HC_DIR}'; exit"; then
            msg "self destruct OK"
        else
            error "self distruct failed, DELETE '${HC_DIR}' MANUALLY!"
            notice "lftp -e '${FTPSSL_COMMAND} cd ${HC_FTP_WEBROOT}' -u '$HC_FTP_USERPASS' '$HC_FTP_HOST'"
        fi
    fi
}

# todos
manual() {
    if ! [ -z "$HC_MX" ]; then
        ssl_check "SMTPS" "465"
        ssl_check "IMAPS" "993"
        ssl_check "POP3S" "995"
        ssl_check "SMTP-TLS" "25" "-starttls smtp"
        ssl_check "IMAP-TLS" "143" "-starttls imap"
        ssl_check "POP3-TLS" "110" "-starttls pop3"
    fi

    ## email
    notice "register RBLmon:  https://www.rblmon.com/accounts/register/"
    notice "register DNS whitelist:  http://www.dnswl.org/request.pl"
    notice "set up email:  abuse@ postmaster@ webmaster@ spam@ hostmaster@ admin@"

    ## sql
    notice "set up phpmyadmin-cli:  https://github.com/fdev/phpmyadmin-cli"
    notice "check MySQL table engine:  SHOW ENGINES;"
    notice "phpmyadmin-cli -l PMA_URL --password=DB_PASSWORD -u DB_USER -e 'SHOW ENGINES;' DB_NAME|tail -n+2|csvtool cat -u TAB -|cut -f1"

    ## web
    notice "certificate check: https://www.ssllabs.com/ssltest/analyze.html?d=${HC_HOST}&s=${HC_IP}"
    notice "W3C validator:  http://validator.w3.org/check?group=1&uri=${HC_SITE}"
    notice "check Latin Extended-A characters: font files, webfonts (őűŐŰ€) and !cufon"
#TODO  slimerjs + automated glyph detection  http://lists.nongnu.org/archive/html/freetype/2014-06/threads.html
    notice "waterfall:  https://www.webpagetest.org/"
    notice "emulate mod_pagespeed:  https://www.webpagetest.org/compare"
    notice "PageSpeed:  http://developers.google.com/speed/pagespeed/insights/?url=${HC_SITE}"
    notice "check hAtom:  http://www.google.com/webmasters/tools/richsnippets?q=${HC_SITE}"
    notice "check included Javascripts"
    notice "check FOUC"
    notice "Javascript errors (slimerjs), 404s (slimerjs/gositemap.sh)"
    notice "minify CSS, JS, optimize images (progressive JPEGs)"
    notice "set up WMT:  https://www.google.com/webmasters/tools/home?hl=en"
    notice "set up Google Analytics:  https://www.google.com/analytics/web/?hl=en&pli=1"
    notice "Google Analytics/Universal Analytics: js, demographics, goals, Remarketing Tag"
    notice "set up page cache"
    notice "check main keyword Google SERP snippet:  https://www.google.hu/search?hl=hu&q=site:${HC_SITE}"

    ## monitoring
    notice "no ISP cron, remote WP-cron:  8,38 * * * *  www-data  /usr/bin/wget -qO- ${HC_SITE}wp-cron.php"
    notice "add site URL to serverwatch/PING"
    notice "add site URL to serverwatch/no-page-cache_do-wp-DB"
    notice "add domain name to serverwatch/DNS"
    notice "add domain name to serverwatch/frontpage"
#TODO  frontpage good regex: '</html>'
#TODO  bad regex: 'sql\| error\| notice\|warning\|unknown\|denied\|exception'
    notice "check root files:  ${HC_SITE}robots.txt  ${HC_SITE}sitemap.xml ${HC_SITE}sitemap_index.xml"
    notice "set up tripwire:  https://github.com/lucanos/Tripwire"
    notice "register pingdom:  https://www.pingdom.com/free/"
#TODO  can-send-email-test/day
#TODO  download-error-log/hour, rotate-error-log/week

    ## tips from  woorank.com + webcheck.me etc.
}

## a dirty hack
detect_success() {
    [ -r "${HC_LOG}" ] || return

    tail -n 2 "${HC_LOG}" | grep -q "^## --END-- ##" \
        || fatal "fatal error occurred"
}

## convert console output to colored HTML
tohtml() {
    [ -r "${HC_LOG}" ] || return
    which ansi2html &> /dev/null || return

    cat "${HC_LOG}.txt" \
        | ansi2html --title="$HC_DOMAIN" --linkify --font-size=13px --light-background -s xterm \
        | sed 's/\x1B(B\b//g' > "${HC_LOG}.html"
    notice "elinks ${HC_LOG}.html"
}

######################################################

## this { ... } is needed for capturing the output
{
    ## site URL
    siteurl

    ## domain
    domain

    ## DNS
    dns_ip
    dns_servers
    dns_email

    ## FTP
    ftp_ssl
    ftp_upload
    ftp_ping

    ## web server
    webserver
    keep_alive
    mime_type
    content_compression
    content_cache

    ## PHP
    php_version
    php_memory
    php_exectime
    php_http
    php_safe
    php_uid
    php_sapi
    php_extensions
    php_timezone
    php_mysqli
    php_logfile
#TODO disk seq.r/w + disk access - 100MB files ?quota
#TODO php benchmark - CPU limit
#TODO mysqli benchmark
#TODO concurrent connections - ab -c X -n Y

    ## manual todos
    manual

    ## WP
    wordpress

    ## self destruct
    ftp_destruct

    ## END of log
    log_end

# duplicate to console
} 2>&1 | tee "${HC_LOG}.txt"

detect_success

## nice HTML output
tohtml
