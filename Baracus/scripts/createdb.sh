#!/bin/bash

# createdb creates a PostgreSQL database.
# 
# Usage:
#   createdb [OPTION]... [DBNAME] [DESCRIPTION]
# 
# Options:
#   -D, --tablespace=TABLESPACE  default tablespace for the database
#   -e, --echo                   show the commands being sent to the server
#   -E, --encoding=ENCODING      encoding for the database
#   -l, --locale=LOCALE          locale settings for the database
#       --lc-collate=LOCALE      LC_COLLATE setting for the database
#       --lc-ctype=LOCALE        LC_CTYPE setting for the database
#   -O, --owner=OWNER            database user to own the new database
#   -T, --template=TEMPLATE      template database to copy
#   --help                       show this help, then exit
#   --version                    output version information, then exit
# 
# Connection options:
#   -h, --host=HOSTNAME          database server host or socket directory
#   -p, --port=PORT              database server port
#   -U, --username=USERNAME      user name to connect as
#   -w, --no-password            never prompt for password
#   -W, --password               force password prompt
# 
# By default, a database with the same name as the current user is created.
# 
# Report bugs to <pgsql-bugs@postgresql.org>.

sudo -u postgres createdb -O dancer -p 5162 baracus
