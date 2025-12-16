#!/bin/bash

DB_PATH=$1

sqlite3 $DB_PATH .schema > /tmp/remote_schema.sql

diff db/schema.sql /tmp/remote_schema.sql

if [ $? -ne 0 ]; then
  echo "SCHEMA DIFFERENT"
  exit 1
fi

echo "SCHEMA OK"
