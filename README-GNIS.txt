
February 17, 2017

GNISGeoCoder


Purpose:
========
The heart of this software is a UITextField class named "GeoCoderTextField" that performs two 
forward-geocode searches. One using the GNIS (Geographic Names Information System) for the USA 
and Canada, and the other using Google's geocode search API (Google API key may be required). 
The GNIS database is compiled into a SQLite3 DB file which is stored in the app bundle for 
offline use. The Google geocoder API requires internet access.

The GeoCoderTextField should be located near the top of the UI window. This is because it pops 
up a user interactive completion list of matching search names, and places the list below the 
text field.

When the user selects the geographic name, the map view is zoomed to that location. The GNIS 
data does not contain view port size information so defaults to a fixed zoom scale. The geocode 
search results from Google usually does contain a view port region. For example, searching for 
"Lake Mead, NV", the Google result should zoom to a view showing the span of the lake, while 
the GNIS only has information of the center coordinate.


The gnis_NAmer.sqlite3 Sqlite3 DB file info:
============================================
The default GNIS DB included in the GIT repository is not optimized or indexed, and is reduced 
of some entries for size. It is included incase a user's environment cannot run a Python 
interpreter with sqlite3.

The GNIS DB is the source project file "gnis_NAmer.sqlite3" and can be regenerated from input 
CSV gzip files 'gnis_US.csv.gz' and 'gnis_CA.csv.gz'.

1) GNIS for Canada and USA, using files 'gnis_US.csv' -> 'NationalFile_20161201.csv' and 
'gnis_CA.csv' -> 'cgn_canada_csv_eng.csv'. The USA GNIS is the version dated Dec 1, 2016 and 
Canada is Jan 12, 2017. The CSV formats differ and the script parses for the specific formats to 
create one sqlite3 DB file "gnis_NAmer.sqlite3".

2) Schema Dump:
sqlite> .schema
CREATE TABLE Tgnis (name TEXT, category TEXT, state TEXT, lat REAL, lon REAL);


Download sources for current GNIS data in CSV format:
=====================================================
https://geonames.usgs.gov/domestic/download_data.htm


World GNIS sources:
===================
http://geonames.nga.mil/namesviewer/
ftp://ftp.nga.mil/pub2/gns_data/


Manual Build SQLite3 DB as file 'gnis_NAmer.sqlite3':
=====================================================
From USA all states "gnis_US.csv" file and from Canada "gnis_CA.csv", run Python script 
"gnis2sqlite.py":

  gzip -d -c gnis_US.csv.gz > gnis_US.csv
  gzip -d -c gnis_CA.csv.gz > gnis_CA.csv
  ./gnis2sqlite.py
  rm gnis_US.csv
  rm gnis_CA.csv

The US GNIS was chunked into 5 parts of 500,000 lines:

bash -c 'LSIZE=500000; for n in {0..4}; do echo $n;k=$(($n + 1)); S=$(($n * $LSIZE + 1)); tail -n +$S gnis_US.csv | head -n $LSIZE | gzip --best > gnis_US.csv.part_${k}of5.gz ;done'


Target "GNIS SQLite3 DB" Automatic Build of SQLite3 DB as file 'gnis_NAmer.sqlite3':
====================================================================================
The Target "GNIS SQL3 DB" is a dependency of the "GNISGeoCoder" project and runs the 
Build Phase/Run script 'RunScript.sh' to generate the project source file "gnis_NAmer.sqlite3" 
from updated 'gnis_US.csv.gz' and 'gnis_CA.csv.gz' files, or if missing or if 'gnis2sqlite.py' 
script was modified.

Note: the gnis2sqlite.py python script may take several minutes to complete.


If no luck generating 'gnis_NAmer.sqlite3' in your environment:
===============================================================
Download 136MB file "gnis_NAmer.sqlite3.zip" from:
   https://delcartes.com/gnis/gnis_NAmer.sqlite3.zip

Unzip and copy into project group "GNIS SQLite3 DB"->"Products"->gnis_NAmer.sqlite3".
File 'gnis_NAmer.sqlite3' should be 290033664 bytes in size.
MD5 (gnis_NAmer.sqlite3) = 2036400853d38a797928cb8d9dc3469b
MD5 (gnis_NAmer.sqlite3.zip) = 24d50bfe6933e87020529665606079f8
