hosting-check
=============

Hosting (webspace) checker

### Contribution

You are more than welcome to test drive this script and attach the output in an [issue](https://github.com/szepeviktor/hosting-check/issues/new).

This **shell script** runs on a server/vps/Virtualbox and checks any FTP/PHP/MySQL hosting service/webspace.

## Installation

1. download: `git clone https://github.com/szepeviktor/hosting-check.git && cd hosting-check`
1. perms:    `chmod +x hosting-check.sh generate-rc.sh`
1. settings: `./generate-rc.sh` will ask you
1. db vars:  you can have a WordPress installation
1. start:    `./hosting-check.sh`

## Output

- HTML with clickable [links](http://online1.hu/)
- a <span style="color:orange;">coloured</span> text file for console
- Bash parsable key-value pairs

## Stress tests (seconds)

| Hosting company | PHP    | steps  | shuffle | AES    |
| --------------- | ------ | ------:| -------:| ------:|
| AMD FX-6300     | 5.4.28 |  4.426 |   4.233 |  4.187 |
| td              | 5.4    |  9.112 |  12.053 |  7.854 |
| sh              | 5.3    | 11.160 |   8.667 |  1.397 |
| mc              | 5.3    |  7.810 |   7.396 |  5.288 |
