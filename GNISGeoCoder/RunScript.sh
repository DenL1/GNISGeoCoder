#!/bin/sh

#  RunScript.sh
#  GNISGeoCoder
#
#  Created by Dennis on 2/22/17.
#
#  Create by Dennis E. Lindsey
#  The author disclaims copyright to this source code.
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any damages
# arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely.
#
# Build Phase -> Run Script for Target "GNIS SQL3 DB"
#
# This script does code generation for SQLite3 DB file gnis_NAmer.sqlite3 that is build into the app bundle.
#

# set -e  ## exit 1 on error

SRC="${SRCROOT}/${PROJECT}"

if [ -e "${SRC}/gnis_NAmer.sqlite3" ] && [ "${SRC}/gnis2sqlite.py" -ot "${SRC}/gnis_NAmer.sqlite3" ] && [ "${SRC}/gnis_CA.csv.gz" -ot "${SRC}/gnis_NAmer.sqlite3" ] && [ "${SRC}/gnis_US.csv.gz" -ot "${SRC}/gnis_NAmer.sqlite3" ] && [ "${SRC}/RunScript.sh" -ot "${SRC}/gnis_NAmer.sqlite3" ];
then
    echo "No gnis_NAmer.sqlite3 build needed."
    exit 0
fi

## Print message that compiling DB, (note leading "warning:" must be all lowercase)
echo "warning: Building 'gnis_NAmer.sqlite3' DB project file (may take several minutes)"

## do work in clean out dir <shift><cmd>K
pushd "${TEMP_FILE_DIR}"

## Github limits 25MB files, so US GINS broken into 4 parts
/bin/rm -f gnis_US.csv
for ii in {1..5}; do
 gzip -d -c "${SRC}/gnis_US.csv.part_${ii}of5.gz" >> gnis_US.csv
done

gzip -d -c "${SRC}/gnis_CA.csv.gz" > gnis_CA.csv
/bin/rm -f 'gnis_NAmer.sqlite3' 'gnis_NAmer.sqlite3-journal'

## Build 'gnis_NAmer.sqlite3' python script
"${SRC}/gnis2sqlite.py"

## Move into source
/bin/mv -f gnis_NAmer.sqlite3 "${SRC}/gnis_NAmer.sqlite3"

## Clean up
/bin/rm -f gnis_US.csv
/bin/rm -f gnis_CA.csv

popd
