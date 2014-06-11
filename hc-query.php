<?php

/**
 * Hosting (webspace) checker PHP query class + main
 * v0.2
 */

// not in PHP 5.2
//namespace HostingCheck;


define('LOGDIRNAME', 'log');
define('LOGFILENAME', 'error.log');
define('LOGTEMPLATE', "//date_default_timezone_set('Europe/Budapest');
ini_set('error_log', '%s');
ini_set('log_errors', 1);
/*
ini_set('upload_tmp_dir', '%s/tmp');
ini_set('session.save_path', '%s/session');
mkdir('%s/tmp', 0700);
mkdir('%s/session', 0700);
*/

//define('WP_MAX_MEMORY_LIMIT', '255M');
define('WP_POST_REVISIONS', 10);
define('WP_DEBUG', true);

/**  production only  **/
//define('WP_DEBUG', false);
define('DISALLOW_FILE_EDIT', true);
//define('WP_CACHE', true);
define('DISABLE_WP_CRON', true);
define('AUTOMATIC_UPDATER_DISABLED', true);
define('WP_USE_EXT_MYSQL', false);
/* different UID
define('FS_METHOD', 'direct');
define('FS_CHMOD_DIR', (0775 & ~ umask()));
define('FS_CHMOD_FILE', (0664 & ~ umask()));
*/
error_log('logging-test');\n");



class Query {

private function expand_shorthand($val) {
    if (empty($val)) {
        return '0';
    }

    $units = array( 'k', 'm', 'g');
    $unit = strtolower(substr($val, -1));
    $power = array_search($unit, $units);

    if ($power === FALSE) {
        $bytes = (int)$val;
    } else {
        //       (int)substr($val, 0, -1)
        $bytes = (int)$val * pow(1024, $power + 1);
    }
    return $bytes;
}

//////////////// ^_Private, v_Public ///////////////

public function fail() {
    print '0';
    exit;
}

public function version() {
    $current = explode('.', phpversion());

    //  = 100*major number       + minor number
    return (int)$current[0] * 100 + (int)$current[1];
}

public function memory() {
    $max_mem = ini_get('memory_limit');
    if ($max_mem === FALSE || empty($max_mem)) {
        return '0';
    }

    return $this->expand_shorthand($max_mem);
}

public function exectime() {
    $max_exec = ini_get('max_execution_time');
    if ($max_exec === FALSE || empty($max_exec)) {
        return '0';
    }

    return $max_exec;
}

public function sapi() {
    return php_sapi_name();
}

public function apachemods() {
    if (! function_exists('apache_get_modules')) {
        return '0';
    }

    $modules = apache_get_modules();

    return implode(',', $modules);
}

public function extensions() {
    //$extensions = array_merge(get_loaded_extensions(false), get_loaded_extensions(true));
    $extensions = get_loaded_extensions(false);

    return implode(',', $extensions);
}

public function timezone() {
    $tz = ini_get('date.timezone');
    if ($tz === FALSE || empty($tz)) {
        return '0';
    // elseif (date_default_timezone_get())
    //   print date_default_timezone_get();
    }

    return $tz;
}

public function mysqli($type = '') {
    // ABSPATH = pwd -> "ABSPATH . 'wp-settings.php'" must exist
    define('ABSPATH', dirname(__FILE__) . '/');

    if (file_exists(dirname(ABSPATH) . '/wp-config.php')) {
        // webroot
        $wp_config = dirname(ABSPATH) . '/wp-config.php';
    } elseif (file_exists(dirname(dirname(ABSPATH)) . '/wp-config.php' )
        && ! file_exists(dirname(dirname(ABSPATH)) . '/wp-settings.php')) {
        // above!
        $wp_config = dirname(dirname(ABSPATH)) . '/wp-config.php';
    } else {
        return '0';
    }

    if (! file_exists(ABSPATH . 'wp-settings.php')) {
        return '0';
    }

    require($wp_config);

    if (! function_exists('mysqli_real_connect')
        || ! defined('DB_HOST')
        || DB_HOST === '') {
        return '0';
    }

    $dbh = mysqli_init();
    if (! mysqli_real_connect($dbh, DB_HOST, DB_USER, DB_PASSWORD)) {
        return '0';
    };

    if ($type === 'wpoptions') {
        $result = mysqli_query($dbh, "USE `" . DB_NAME . "`;");
        $version_query = "SELECT option_name, option_value FROM `" . $table_prefix . "options` WHERE autoload = 'yes';";
    } else {
        // normal operation
        $version_query = "SHOW VARIABLES LIKE 'version'";
    }
    $result = mysqli_query($dbh, $version_query);

    if (! $result) {
        mysqli_close($dbh);
        return '0';
    }

    if ($type === 'wpoptions') {
        $total_length = 0;
        while( $row = mysqli_fetch_row($result)) {
            $total_length += strlen($row[0] . $row[1]) + 2;
        }

        return $total_length;
    } else {
        // normal operation
        $version_array = mysqli_fetch_row($result);
        mysqli_free_result($result);
        mysqli_close($dbh);

        if (empty($version_array[1])) {
            return '0';
        }

        return $version_array[1];
    }
}

public function wpoptions() {
    return $this->mysqli('wpoptions');
}

public function logfile() {
    $docroot = @$_SERVER['DOCUMENT_ROOT'];
    if (empty($docroot)) {
        return '0';
    }

    // is it an alias?
    if (isset($_SERVER['DOCUMENT_ROOT'])
        && isset($_SERVER['SCRIPT_FILENAME'])
        && strpos($_SERVER['SCRIPT_FILENAME'], $_SERVER['DOCUMENT_ROOT']) !== 0) {

        // 'hosting-check' . '/hc-query.php'
        $me = basename(dirname($_SERVER['SCRIPT_FILENAME'])) . '/hc-query.php';
        // ends with
        if (substr($_SERVER['SCRIPT_FILENAME'], -strlen($me)) === $me) {
            $docroot = substr($_SERVER['SCRIPT_FILENAME'], 0, -strlen($me));
        }
    }

    $docroot = rtrim($docroot, '/');

    // above webroot
    $logpath = dirname($docroot);
    if (! chdir($logpath)) {
        // revert
        $logpath = $docroot;
    }

    if (!file_exists($logpath . '/' . LOGDIRNAME)) {
        // create log dir
        if (! mkdir($logpath . '/' . LOGDIRNAME, 0700)) {
            return '0';
        }
    }

    $logfile = $logpath . '/' . LOGDIRNAME . '/' . LOGFILENAME;
    if (! touch($logfile)) {
        return '0';
    }

    chmod($logfile, 0600);
    return sprintf(LOGTEMPLATE, $logfile, $logpath, $logpath, $logpath, $logpath);
}

public function safe() {
    // REMOVED as of PHP 5.4.0
    if (version_compare(PHP_VERSION, '5.4.0', '<')) {

        if (get_magic_quotes_gpc() === 1
            || ini_get('safe_mode') === 1
            || ini_get('register_globals') === 1) {
            return '0';
        }
    }
    return 'OK';
}

public function uid() {
    // webserver UID
    $uid = posix_getuid();
    if (posix_geteuid() !==  $uid) {
        return '0';
    }
    // FTP UID
    if (getmyuid() !== $uid) {
        return '0';
    }
    return $uid;
}

public function http() {
    if (function_exists('stream_socket_client')
        || (function_exists('curl_init') && function_exists('curl_exec'))) {
        return 'OK';
    }
    return '0';
}

//class
}


/** main **/

// hide errors
//error_reporting(E_ALL|E_STRICT);
error_reporting(0);

$phpq = new Query;

//DBG  $_GET['q'] = $argv[1];
if (empty($_GET['q'])) {
    $phpq->fail();
}

$method = preg_replace('/[^a-z]/', '', $_GET['q']);

if (!method_exists($phpq, $method)) {
    $phpq->fail();
}

print $phpq->$method();
