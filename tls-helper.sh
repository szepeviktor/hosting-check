#!/bin/bash

## Hosting checker certificate debugger and simple login script
##
## to log in to FTP:  ./tls-helper.sh login

## needs:
## lftpgnutls3 - lftp compiled with GnuTLS v3 from Debian wheezy source package
## lftpgnutls3-src - lftp compiled with GnuTLS v3 from upstream source
## lftpopenssl - lftp compiled with OpenSSL
## gnutls-cli - compiled with GnuTLS v3
## openssl


# HC_FTP_HOST  HC_FTP_USER  HC_FTP_PASSWORD
. .hcrc

CACERTS="/etc/ssl/certs/ca-certificates.crt"

h1() {
    echo "$(tput sgr0)$(tput dim)$(tput setaf 0)$(tput setab 2)  $*  $(tput sgr0)"
}

ret() {
    echo "$(tput sgr0)$(tput bold)$(tput setaf 7)$(tput setab 1)  $*  $(tput sgr0)"
}

start_header() {
    h1 "START tls helper --------"
    h1 "START tls helper --------"
    h1 "START tls helper --------"
    echo
}

do_lftp() {
    local LFTP="$1"

    "$LFTP" --version | head -n 1
    "$LFTP" --version | tail -n 1
    echo "========================"
    "$LFTP" -u "${HC_FTP_USER},${HC_FTP_PASSWORD}" \
        -e "debug; set ssl:ca-file ${CACERTS}; set ftp:ssl-force 1; ls" "${HC_FTP_HOST}"
}

lftp_stock() {
    h1 "stock lftp"
    do_lftp lftp
    ret $?
}

lftp_gnutls3() {
    h1 "lftp + GnuTLS 3"
    do_lftp ./lftpgnutls3
    ret $?
}

lftp_gnutls3_src() {
    h1 "lftp + GnuTLS 3 from source"
    do_lftp ./lftpgnutls3-src
    ret $?
}

lftp_openssl() {
    h1 "lftp + openssl"
    (sleep 4; killall lftpopenssl) &
    do_lftp ./lftpopenssl
    ret $?
}

gnutls_cli() {
    h1 "gnutls-cli GnuTLS 3"
    gnutls-cli --version | head -n1
    echo "========================"
    ret "AUTH TLS"
    ret "Ctrl + D"
    (sleep 9; killall gnutls-cli) &
    gnutls-cli --verbose --crlf --x509cafile ${CACERTS} --starttls --port 21 "${HC_FTP_HOST}"
    ret $?
}

openssl_cli() {
    h1 "openssl"
    echo QUIT|openssl s_client -CAfile ${CACERTS} -connect "${HC_FTP_HOST}":21 -starttls ftp -showcerts
    ret $?
}

just_login() {
#    ./lftpopenssl -u "${HC_FTP_USER},${HC_FTP_PASSWORD}" \
    lftp -u "${HC_FTP_USER},${HC_FTP_PASSWORD}" \
        -e "debug; set ssl:ca-file ${CACERTS}" "${HC_FTP_HOST}"
}

####################################

if [ "$1" = login ]; then
    just_login
    exit 0
fi

start_header

lftp_stock
lftp_gnutls3
lftp_gnutls3_src
lftp_openssl

gnutls_cli
openssl_cli

