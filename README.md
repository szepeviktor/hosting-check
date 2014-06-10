hosting-check
=============

Hosting (webspace) checker


You are more than welcome to test drive this script and attach the output in an [issue](https://github.com/szepeviktor/hosting-check/issues/new).
This script runs on a server/vps and checks any FTP/PHP/MySQL webspace.

## Installation

1. download: `git clone https://github.com/szepeviktor/hosting-check.git && cd hosting-check`
1. perms:    `chmod +x hosting-check.sh`
1. rc file:  `cp templates/.hcrc .`
1. settings: `nano .hcrc`
1. db:       have WordPress installed or fill in and upload `templates/wp-config.php` to webroot
1. start:    `./hosting-check.sh` in your shell

## Output

- HTML with clickable [links](http://online1.hu/)
- a <span style="color:orange;">coloured</span> text file for console
- Bash parsable key-value pairs
