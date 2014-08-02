Hosting checker
===============

Shared hosting service (webspace) checker based on my personal demands

This **shell script** runs on your terminal (Linux, Cygwin, OS X) and checks any FTP/PHP/MySQL hosting service/webspace
by uploading PHP code and downloading its output. No SSH access is needed for the hosting service, it runs on a separate terminal.

#### You can use it to

- choose hosting provider
- fix errors in an existing site
- prepare for traffic spikes
- reduce spam

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
- concurrent HTTP connections
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
- server CPU info
- CPU **stress test**
- disk benchmarks
- MySQL benchmark (TODO)
- total size of WordPress "autoload" options
- and a lot of [manual checks](https://github.com/szepeviktor/hosting-check/blob/master/hosting-check.sh#L1267) (notices, links)

## Output types

- HTML with [clickable links](http://online1.hu/)
- a <span style="color:orange;">coloured</span> text file for console
- Bash parsable key-value pairs

## Installation

1. download: `git clone https://github.com/szepeviktor/hosting-check.git && cd hosting-check`
1. install:  lftp (curl is not a full-featured fallback)
1. settings: `./generate-rc.sh` will question you
1. db vars:  you can have a WordPress installation (wp-config.php will be read)
1. start:    `./hosting-check.sh`

### Cygwin

On Cygwin use [apt-cyg](https://github.com/transcode-open/apt-cyg) and install lftp beside ncurses,
wget, bind-utils, util-linux and whois.

`apt-cyg install  ncurses wget lftp bind-utils util-linux whois`

To clone this GitHub repo you need

`apt-cyg install  git libcurl4`

## Stress tests

| Hosting company | PHP | steps  | shuffle | AES    |
| --------------- | --- | ------:| -------:| ------:|
| AMD FX-6300     | 5.4 |  1.139 |   1.074 |  1.169 |
| ole             | 5.4 |  1.677 |   1.809 |  0.479 |
| td              | 5.4 |  0.818 |   0.889 |  0.653 |
| sh              | 5.3 |  2.823 |   2.048 |  0.329 |
| wpe             | 5.3 |  2.962 |   2.500 |  0.963 |
| mc-cluster      | 5.3 |  1.983 |   1.924 |  1.095 |
| pan             | 5.5 |  1.696 |   1.425 |  0.494 |
| for             | 5.4 |  1.344 |   1.015 |  0.279 |

**steps** counts from 1 to 25 million, **shuffle** shuffles and calculates md5 sum of a string half million times,
**AES** encrypts an md5 sum 2500 times. You can find the source in [hc-query.php](https://github.com/szepeviktor/hosting-check/blob/master/hc-query.php#L82-L117)

Company names are hidden intentionally. Times are in seconds.

### Contribution

You are more than welcome to test drive this script and attach the output in an [issue](https://github.com/szepeviktor/hosting-check/issues/new).

