#!/bin/bash

#TODO: read everything from templates

read_value() {
    local VARIABLE="$1"
    local DEFAULT_VALUE="$2"
    local VALUE_NAME="$3"
    local MESSAGE="$4"
    local VALUE_PROMPT="$(tput sgr0)$(tput dim)$(tput setaf 0)$(tput setab 3)${VALUE_NAME}$(tput sgr0): "

    echo "$MESSAGE"

    # write only
    if [ -z "$VALUE_NAME" ]; then
        VALUE="$DEFAULT_VALUE"
    else
        read -p "$VALUE_PROMPT" -e -i "$DEFAULT_VALUE" VALUE
    fi

    # read only
    if ! [ -z "$VARIABLE" ]; then
        echo "${VARIABLE}=\"${VALUE}\"" >> "$CONFIG_FILE"
    fi
}

read_db_value() {
    local VARIABLE="$1"
    local DEFAULT_VALUE="$2"
    local VALUE_NAME="$3"
    local MESSAGE="$4"
    local VALUE_PROMPT="$(tput sgr0)$(tput dim)$(tput setaf 0)$(tput setab 2)${VALUE_NAME}$(tput sgr0): "

    echo "$MESSAGE"

    read -p "$VALUE_PROMPT" -e -i "$DEFAULT_VALUE" VALUE

    # hard coded
    if [ "$VARIABLE" = table_prefix ]; then
        echo "\$table_prefix = '${VALUE}';" >> "$CONFIG_FILE"
    else
        echo "define('${VARIABLE}', '${VALUE}');" >> "$CONFIG_FILE"
    fi
}

echo 'Please enter FTP and other SETTINGS'
CONFIG_FILE="./.hcrc"
echo -n > "$CONFIG_FILE"

read_value "HC_SITE" "" "Site URL" 'Site URL begins with protocol (http://) end with a slash ("/")'
#FIXME validation/grep -E 'https?://.*/$'

HC_FTP_HOST="$(sed -r 's|^(([a-z]+:)?//)?([a-z0-9.-]+)/.*$|\3|' <<< "$VALUE")"
read_value "HC_FTP_HOST" "$HC_FTP_HOST" "FTP hostname" 'Host name of the FTP server'
#grep '^[a-zA-Z0-9-.]\{5,50\}$'

read_value "" "" "FTP username" 'Enter the FTP user name'
#grep '^.\{1,50\}$'
HC_FTP_USER="$VALUE"
read_value "" "" "FTP password" 'Enter the FTP password'
#grep '^.\{5,50\}$'
HC_FTP_PASS="$VALUE"
read_value "HC_FTP_USERPASS" "${HC_FTP_USER},${HC_FTP_PASS}" ""

read_value "HC_FTP_ENABLE_TLS" "1" "FTP TLS detection" 'Enter "1" to enable TLS detection in FTP connections, "0" to disable'
#grep '^0$|^1$'
read_value "HC_FTP_WEBROOT" "/public_html" "Document root" 'Relative webroot directory should begin with "/"'
#grep '^/.*$'
HC_FTP_WEBROOT="$VALUE"
read_value "HC_MAILSERVER_IP" "" "Main mailserver" "IP address of the mailserver you use besides the hosting's one"
#grep '^\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}$'
read_value "HC_TIMEZONE" "Europe/Budapest" "Time zone" 'Local time zone for PHP'
#grep '^[A-Z][a-zA-Z_]*/[A-Z][a-zA-Z_]*$'

echo 'Please enter MySQL database credentials'
echo 'http://codex.wordpress.org/Editing_wp-config.php'
CONFIG_FILE="./wp-config.php"
echo -n > "$CONFIG_FILE"

read_db_value "DB_NAME" "" "MySQL database name" 'Name of database belonging to the site'
#grep '^.\{1,50\}$'
read_db_value "DB_USER" "" "MySQL user name" 'Name of the database user having access to the database'
#grep '^.\{1,50\}$'
read_db_value "DB_PASSWORD" "" "MySQL password" 'Use a complex and long enough password'
#grep '^.\{5,50\}$'
read_db_value "DB_HOST" "localhost" "MySQL server's host name" 'Database server host name is usually "localhost"'
#grep '^.\{1,50\}$'
read_db_value "DB_CHARSET" "utf8" "MySQL character set" 'Character set should be "utf8"'
#grep '^.\{4,50\}$'
read_db_value "DB_COLLATE" "" "MySQL connection collation" 'Database connection collation could be empty'
#grep '^.*$'
read_db_value "table_prefix" "wp_" "WordPress table prefix" 'The table prefix should NOT be "wp_"'
#grep '^.\+_$'
read_db_value "WPLANG" "hu_HU" "WordPress language" 'List of WordPress languages:  http://wpcentral.io/internationalization/'
#grep '^[a-z]\{2\}_[A-Z]\{2\}$'

#TODO auto upload
echo "Now upload your wp-config.php to the webroot (${HC_FTP_WEBROOT}) directory, or above it"
