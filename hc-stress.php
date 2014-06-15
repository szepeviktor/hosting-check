<?php

function unow() {
    return microtime(true);
    list($usec, $sec) = explode(' ', microtime());
    return ((float)$usec + (float)$sec);
}

function stress_steps() {
    $steps_start = unow();
    $steps = 0;
    for ($i = 0; $i < 100000000; $i += 1) {
        $steps += $i;
    }
    return unow() - $steps_start;
}

function stress_shuffle() {
    $shuffle_start = unow();
    $hash = 0;
    for ($i = 0; $i < 2000000; $i += 1) {
        // XOR
        $hash ^= md5(substr(str_shuffle('0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'), 0, rand(1,10)));
    }
    return unow() - $shuffle_start;
}

function stress_aes() {
    $aes_start = unow();
    $data = md5(substr(str_shuffle('0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'), 0, rand(1,10)));
    $keyhash = md5('secret key');
    $ivsize = mcrypt_get_iv_size(MCRYPT_RIJNDAEL_256, MCRYPT_MODE_CBC);
    $iv = mcrypt_create_iv($ivsize, MCRYPT_DEV_URANDOM);
    $cipherdata = '';

    for ($i = 0; $i < 10000; $i += 1) {
        // XOR
        $cipherdata ^= mcrypt_encrypt(MCRYPT_RIJNDAEL_256, $keyhash, $data, MCRYPT_MODE_CBC, $iv);
    }
    return unow() - $aes_start;
}


if (php_sapi_name() !== 'cli' && ini_get('max_execution_time') < 20) {
    if (! ini_set('max_execution_time', 20)) {
        die('can NOT run for 20 seconds!');
    }
}

//error_reporting(E_ALL|E_STRICT);
error_reporting(0);

// ab -c3 -n3 http://...../hc-stress.php
// ab -c5 -n5 http://...../hc-stress.php
// ab -c10 -n10 http://...../hc-stress.php
// ab -c20 -n20 http://...../hc-stress.php
// ab -c30 -n30 http://...../hc-stress.php

// big files seq. read

// disk access time

// iteration ratio:  steps:shuffle:eas ~ 10000:200:1
printf('steps time:   %10.3f' . PHP_EOL, stress_steps());
printf('shuffle time: %10.3f' . PHP_EOL, stress_shuffle());
printf('aes time:     %10.3f' . PHP_EOL, stress_aes());



/*
for($i = 0; $i < 9999; $i++) {
    $conn = mysql_connect(...);
    $db = mysql_select_db(...);
    $res = mysql_query(...);
    $data = mysql_fetch_assoc($res);
    mysql_close();
}
*/