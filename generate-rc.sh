#!/bin/bash

trim() {
    #  http://www.cyberciti.biz/faq/bash-remove-whitespace-from-string/
    local OUTPUT="$1"

    ### trim leading whitespaces
    OUTPUT="${OUTPUT##*([[:blank:]])}"

    ### trim trailing whitespaces
    echo "${OUTPUT%%*([[:blank:]])}"
}

error() {
    echo "$(tput sgr0)$(tput bold)$(tput setaf 7)$(tput setab 1)[hosting-check]$(tput sgr0) $*" >&2
}

msg() {
    echo "$(tput sgr0)$(tput dim)$(tput setaf 0)$(tput setab 2)[hosting-check]$(tput sgr0) $*"
}

title() {
    local TITLE="$1"

    echo
    echo "$TITLE"
    for (( i=0; i < ${#TITLE}; i++ )); do
        echo -n "="
    done
    echo
}

strip_hash() {
    local STRING="$1"
    sed -r 's/^(\/\/)?#\s+//' <<< "$STRING"
}

reset_file() {
    local FILE="$1"
    echo -n > "$FILE"
}

process_template() {
    local TEMPLATE="$1"
    local CONFIG_FILE="$2"
    local PROMPT_COLOR="$3"
    local VALUE_PROMPT="$(tput sgr0)$(tput dim)$(tput setaf 0)$(tput setab ${PROMPT_COLOR})%s$(tput sgr0): "
    local Variable
    local Default
    local Name
    local Description
    local Validator
    local Output
    local VALUE

    [ -r "$TEMPALTE" ] && return 1
    reset_file "$CONFIG_FILE"

    while read -r LINE <&3; do
        LINE="$(strip_hash "$LINE")"

        case "${LINE%%=*}" in
            Variable|Default|Name|Description|Validator|Output)
                eval "$LINE"
                ;;
            *)
                continue
                ;;
        esac

        # got Output, start rendering
        if ! [ -z "$Variable" ] \
            && ! [ -z "$Validator" ] \
            && ! [ -z "$Output" ]; then

            echo "$Description"

            unset VALUE
            while : ; do
                read -p "$(printf "$VALUE_PROMPT" "$Name")" -e -i "$Default" VALUE
                VALUE="$(trim "$VALUE")"

                if grep -q "$Validator" <<< "$VALUE"; then
                    break
                else
                    error "Validation error ($VALUE)"
                fi
            done

            # append to config file
            printf "$Output\n" "${Variable}" "${VALUE}" >> "$CONFIG_FILE"

            unset Variable
            unset Validator
            unset Output
        fi
    done 3< "$TEMPLATE"

    return 0
}

continue_db() {
    local QUESTION="$1"

    while : ; do
        read -p "$(tput sgr0)$(tput dim)$(tput setaf 0)$(tput setab 6)${QUESTION}$(tput sgr0) " \
            -e -i "y" ANSWER
        if grep -q '^y$\|^n$' <<< "$ANSWER"; then
            break
        else
            error "Validation error ($ANSWER)"
        fi
    done

    [ "$ANSWER" = n ] && exit 0
}

## example template entry
## "$VALUE" contains the previously entered value

# Variable="HC_FTP_HOST"
# Default="$(sed -r 's|^(([a-z]+:)?//)?([a-z0-9.-]+)/.*$|\3|' <<< "$VALUE")"
# Name='Site URL'
# Description='Host name of the FTP server'
# Validator='^[a-zA-Z0-9-.]\{13,50\}$'
# Output='%s="%s"'
#

title 'Please enter FTP and other SETTINGS'
process_template "templates/.hcrc" "./.hcrc" 3
msg "Configuration file (.hcrc) generated OK."

continue_db "Continue with Database credentials? [Y/N]"

title 'Please enter MySQL database credentials  http://codex.wordpress.org/Editing_wp-config.php'
process_template "templates/wp-config.php" "./wp-config.php" 6
msg "Database configuration file (wp-config.php) generated OK."
msg "Generated wp-config.php will be uploaded to the webroot directory."
