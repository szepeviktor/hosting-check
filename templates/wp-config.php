<?php

// DB crendtials
// this files looks like a real wp-config.php

//# Variable="DB_NAME"
//# Default=""
//# Name="MySQL database name"
//# Description='Name of database belonging to the site'
//# Validator='^.\{1,50\}$'
//# Output="<?php\ndefine('%s', '%s');"
define('DB_NAME', '');

//# Variable="DB_USER"
//# Default=""
//# Name="MySQL user name"
//# Description='Name of the database user having access to the database'
//# Validator='^.\{1,50\}$'
//# Output="define('%s', '%s');"
define('DB_USER', '');

//# Variable="DB_PASSWORD"
//# Default=""
//# Name="MySQL password"
//# Description='Use a complex and long enough password'
//# Validator='^.\{5,50\}$'
//# Output="define('%s', '%s');"
define('DB_PASSWORD', '');

//# Variable="DB_HOST"
//# Default="localhost"
//# Name="MySQL server's host name"
//# Description='Database server host name is usually "localhost"'
//# Validator='^.\{1,50\}$'
//# Output="define('%s', '%s');"
define('DB_HOST', 'localhost');

//# Variable="DB_CHARSET"
//# Default="utf8"
//# Name="MySQL character set"
//# Description='Character set should be "utf8"'
//# Validator='^.\{4,50\}$'
//# Output="define('%s', '%s');"
define('DB_CHARSET', 'utf8');

//# Variable="DB_COLLATE"
//# Default=""
//# Name="MySQL connection collation"
//# Description='Database connection collation could be empty'
//# Validator='^'
//# Output="define('%s', '%s');"
define('DB_COLLATE', '');

//# Variable="table_prefix"
//# Default="wp_"
//# Name="WordPress table prefix"
//# Description='The table prefix should NOT be "wp_"'
//# Validator='^.\+_$'
//# Output="\$%s = '%s';"
$table_prefix = 'wp_';

//# Variable="WPLANG"
//# Default="hu_HU"
//# Name="WordPress language"
//# Description='List of WordPress languages:  http://wpcentral.io/internationalization/'
//# Validator='^[a-z]\{2\}_[A-Z]\{2\}$'
//# Output="define('%s', '%s');"
define('WPLANG', 'hu_HU');
