GNIS and Google Forward Geocode for iOS _GNISGeoCoder_ is a project app example which performs forward geocoder searches into an embedded GNIS SQLite3 database and to Google's online geocoder search engine. The GNIS database is compiled from the U.S. Geological Survey and Natural Resources Canada, Geographical Names Information Systems.

When run on an iOS device type into the text field any name of a geographical feature. Tap the name and the map view will zoom to coordinate location of the feature.

## Features

- **_GeoCoderTextField_** Objective-C UITextField subclass that performs the forward geocoder searches. When searching it drops down a table of matching names sorted by distance. Upon selection, it zooms the delegate map view to geographic feature's coordinates.

- **_MapDistanceKeyView_** Objective-C UIView that actively draws the MKMapView distance key to scale in miles, feet, meters, or nautical miles.

- **SQLite3** C source code (3.17.0 13-Feb-2017) slightly modified for an almost warning free compile by _clang_.

- **Python** script to parse the GNIS CSV files and outputs a SQLite3 database file.

- **RESTful JSON API to the Google geocoder service** (A Google API key may be required).

- **Complete iOS App** example. Runs on an iOS device or iOS simulator.

## Building _GNISGeoCoder_

- Required Xcode 8 to build. Targets iOS 8.0 and later.

- Download the project and open in XCode the file GNISGeoCoder/GNISGeoCoder.xcodeproj

- Set the provisioning profile signing for your team. 

Initial build in Xcode may take several minutes to first parse and build the SQLite DB project file _gnis_NAmer.sqlite3_.

### If no luck generating 'gnis_NAmer.sqlite3' in your environment:

Download 136MB file "gnis_NAmer.sqlite3.zip" from:
https://delcartes.com/gnis/gnis_NAmer.sqlite3.zip

Unzip and copy into project group "GNIS SQLite3 DB "-> 
"Products"->gnis_NAmer.sqlite3".

File 'gnis_NAmer.sqlite3' should be 290033664 bytes in size.

MD5 (gnis_NAmer.sqlite3) = 2036400853d38a797928cb8d9dc3469b

MD5 (gnis_NAmer.sqlite3.zip) = 24d50bfe6933e87020529665606079f8

## License

The software is license free.

## Credits

GNISGeoCoder was created by Dennis E. Lindsey, February 2017.

United State Board on Geological Names https://geonames.usgs.gov

Natural Resources Canada http://www.nrcan.gc.ca

