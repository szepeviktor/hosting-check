hosting-check
=============

Shared hosting service (webspace) checker

This **shell script** runs on a terminal (Linux, Cygwin, OS X) and checks any FTP/PHP/MySQL hosting service/webspace.

## Checks

- domain name (only .hu TLD by parsing domain.hu website)
- website IP, reverse hostname
- nameserver hostnames, IPs, locations, "Domi" domain check
- MX hostname, IP, reverse hostname and its IP
- SPF record
- FTP TLS certificate (lftp with gnutls has a bug)
- webserver name, Apache modules
- keep-alive support
- MIME types (from the [HTML5 Boilerplate](https://github.com/h5bp/html5-boilerplate/) project)
- HTTP compression
- HTTP Cache-Control header
- PHP version
- PHP memory limit
- PHP excution time limit
- PHP HTTP functions (for downloading)
- PHP Safe Mode, magic quotes, register globals
- PHP user ID and FTP user ID comparison
- PHP Server API
- PHP extensions
- PHP time zone
- MySQL version
- set up PHP error logging
- CPU stress test (halfdone)
- disk benchmark (halfdone)
- MySQL benchmark (TODO)
- concurrent HTTP connections (TODO)
- total size of WordPress "autoload" options
- and a lot of manual checks (notices, links)

## Output types

- HTML with [clickable links](http://online1.hu/)
- a <span style="color:orange;">coloured</span> text file for console
- Bash parsable key-value pairs

## Installation

1. download: `git clone https://github.com/szepeviktor/hosting-check.git && cd hosting-check`
1. perms:    `chmod +x hosting-check.sh generate-rc.sh`
1. install:  lftp (curl is a not full featured fallback)
1. settings: `./generate-rc.sh` will question you
1. db vars:  you can have a WordPress installation
1. start:    `./hosting-check.sh`

## Stress tests (seconds)

| Hosting company | PHP    | steps  | shuffle | AES    |
| --------------- | ------ | ------:| -------:| ------:|
| AMD FX-6300     | 5.4.28 |  4.426 |   4.233 |  4.187 |
| td              | 5.4    |  9.112 |  12.053 |  7.854 |
| sh              | 5.3    | 11.160 |   8.667 |  1.397 |
| mc              | 5.3    |  7.810 |   7.396 |  5.288 |

### Contribution

You are more than welcome to test drive this script and attach the output in an [issue](https://github.com/szepeviktor/hosting-check/issues/new).
