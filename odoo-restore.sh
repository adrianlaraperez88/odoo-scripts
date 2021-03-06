#!/bin/bash
if [ -z "$USER" ]; then
    echo "ERROR: Instalation error, USER is not defined"
    exit 1
fi
if [ -z "$HOME" ]; then
    echo "ERROR: Instalation error, HOME is not defined"
    exit 1
fi
if [ -z "$HOST" ]; then
    echo "ERROR: Instalation error, HOST is not defined"
    exit 1
fi
if [ -z "$FILESTORE" ]; then
    echo "ERROR: Instalation error, FILESTORE is not defined"
    exit 1
fi

file="$1"
FILE_DB="$file.dump"
FILE_TAR="$file.tar.gz"

database="$2"

show_help(){
   echo "ERROR: $1"
   echo "Usage: $0 <backup_file> <new_database_name>"
   exit 1
}

if [ -z "$file" ]; then show_help "No filename selected"; fi
if [ -z "$database" ]; then show_help "No database name defined"; fi
if [ ! -f "$FILE_DB" ]; then echo "Database file '$FILE_DB' not found"; exit 2; fi
if [ ! -f "$FILE_TAR" ]; then echo "Filestore file '$FILE_TAR' not found"; exit 2; fi

$HOME/bin/odoo-status
if [ $? -eq 0 ]; then echo "ERROR: Odoo service is running"; exit 3; fi

FILE_DB_PATH=`realpath "$FILE_DB"`
FILE_TAR_PATH=`realpath "$FILE_TAR"`
ORIGINAL_DB=`echo "$file" | cut -c 17-`
read -s -p "Enter DB Password for user '$USER': " db_password
echo

NOW=`date '+%Y%m%d_%H%M%S'`
logfile="${NOW}-${ORIGINAL_DB}-restore.log"
echo "BACKUP: ORIGINAL DATABASE = $ORIGINAL_DB, NEW DATABASE: $database, TIME = $NOW" > $logfile

if PGPASSWORD="$db_password" /usr/bin/psql -h $HOST -U "$USER" -l -F'|' -A "template1" | grep "|$USER|" | cut -d'|' -f1 | egrep -q "^$database\$"; then
    echo -n "Removing database: $database ... "
    PGPASSWORD="$db_password" /usr/bin/psql -h $HOST -U "$USER" template1 -c "DROP DATABASE \"$database\"" >> $logfile 2>&1
    error=$?; if [ $error -eq 0 ]; then echo "OK"; else echo "ERROR: $error"; fi
fi

echo -n "Create database: $database ... "
PGPASSWORD="$db_password" /usr/bin/psql -h $HOST -U "$USER" template1 -c "CREATE DATABASE \"$database\" WITH OWNER \"$USER\"" >> $logfile 2>&1
error=$?; if [ $error -eq 0 ]; then echo "OK"; else echo "ERROR: $error"; fi

echo "Restoring database: $database:"
echo "------------------------------"
PGPASSWORD="$db_password" /usr/bin/pg_restore --username "$USER" --host $HOST --dbname "$database" --no-owner "$FILE_DB"
error=$?;
echo "------------------------------"
echo "   RESULT: $error"

echo -n "Remove filestore $HOME/$FILESTORE/$database ... "
rm -rf "$HOME/$FILESTORE/$database"
error=$?; if [ $error -eq 0 ]; then echo "OK"; else echo "ERROR: $error"; fi

echo -n "Restore filestore ... "
cd $HOME/backup
/bin/tar -xzf "$FILE_TAR_PATH" >> $logfile 2>&1
error=$?; if [ $error -eq 0 ]; then echo "OK"; else echo "ERROR: $error"; fi

echo -n "Rename filestore: $ORIGINAL_DB -> $database ... "
mv "$HOME/backup/$FILESTORE/$ORIGINAL_DB" "$HOME/$FILESTORE/$database" >> $logfile 2>&1
error=$?; if [ $error -eq 0 ]; then echo "OK"; else echo "ERROR: $error"; fi
