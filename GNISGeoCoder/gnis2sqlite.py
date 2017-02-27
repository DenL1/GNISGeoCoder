#!/usr/bin/python

#  13-February-2017
#
#  GNISGeoCoder
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

import sqlite3
from datetime import datetime, date
import sys
import logging

#import sys;
#sys.defaultencoding('utf_8')

# CSV header:
# FEATURE_ID 0|FEATURE_NAME 1|FEATURE_CLASS 2|STATE_ALPHA 3|STATE_NUMERIC 4|COUNTY_NAME 5|COUNTY_NUMERIC 6|PRIMARY_LAT_DMS 7|PRIM_LONG_DMS 8|PRIM_LAT_DEC 9|PRIM_LONG_DEC 10|SOURCE_LAT_DMS 11|SOURCE_LONG_DMS 12|SOURCE_LAT_DEC 13|SOURCE_LONG_DEC 14|ELEV_IN_M 15|ELEV_IN_FT 16|MAP_NAME 17|DATE_CREATED 18|DATE_EDITED 19

conn = sqlite3.connect('gnis_NAmer.sqlite3')
conn.text_factory = str # utf8

c = conn.cursor() # instantiates a SQL interface to the connection

c.execute('drop table if exists Tgnis;')
c.execute('create table Tgnis (name TEXT, category TEXT, state TEXT, lat REAL, lon REAL);')

def mysplit (string,delim):
    quote = False
    retval = []
    current = ""
    for char in string:
        if char == '"':
            quote = not quote
        elif char == delim and not quote:
            retval.append(current)
            current = ""
        else:
            current += char
    retval.append(current)
    return retval

##
## Parse USA GNIS
##
sys.stderr.write("\nParsing 'gnis_US.csv' U.S. GNIS...\n")

# Read lines from file, skipping first line CSV column header
data = open("gnis_US.csv", "r").readlines()[1:]

# Parse values
for entry in data:
    vals = mysplit(entry.strip(),'|')

    ## Fix up of extra WS (one case in .csv)
    if vals[2] == "Part of  a Lake":
        vals[2] = "Part of a Lake"
    
    try:
        sql = "insert into Tgnis values(?,?,?,?,?);"
        c.execute(sql, (vals[1],vals[2],vals[3],vals[9],vals[10]) )

    except Exception as e:
        sys.stderr.write("\nError: Exception at FEATURE ID: "+vals[0]+", error: "+str(e)+"\n")

##
## OH CANADA!
##
sys.stderr.write("\nParsing 'gnis_CA.csv' Canada GNIS...\n")
dataCa = open("gnis_CA.csv", "r").readlines()[1:]

for entry in dataCa:
    vals = mysplit(entry.strip(),',')
#    sys.stderr.write("Inserting FEATURE_ID: "+str(vals[0])+"     \r")
    try:
        sql = "insert into Tgnis values(?,?,?,?,?);"
        c.execute(sql, (vals[1],vals[4],vals[10],vals[7],vals[8]) ) # Canada
    except Exception as e:
        sys.stderr.write("\nError: Exception at FEATURE ID: "+vals[0]+", error: "+str(e)+"\n")

##
## Create INDEX
##
sys.stderr.write("\nBuild Index...\n")

try:
    sql1 = "CREATE INDEX INDEX_name on Tgnis (name);"
    c.execute(sql1);
    sql2 = "CREATE INDEX INDEX_latlon on Tgnis (lat,lon);"
    c.execute(sql2);
except Exception as e:
    sys.stderr.write("\nError: Exception at INDEX, error: "+str(e)+"\n")

##
## Commit DB
##
conn.commit()

##
## Vacuum up (probably unnecessary)
##
sys.stderr.write("\nVacuum...\n")
try:
    sql = "VACUUM;"
    c.execute(sql);
except Exception as e:
    sys.stderr.write("\nError: Exception at VACUUM, error: "+str(e)+"\n")

conn.close()

sys.stderr.write("\nDone.\n")
