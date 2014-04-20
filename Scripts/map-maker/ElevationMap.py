import math, urllib, zipfile, re, os.path
import HGTFile

class ElevationMap:
    "This class downloads NASA ground elevation data for a given area and then returns data for any given point in the area."
    
    def __init__(self, bounds):
        
        # The exact requested bounds of the map
        # We use these for statistics like average, min and max height
        self.bounds = bounds
        
        # Expand the boundary rectangle to the closest degree lines by finding the corner tile locations
        w,n,e,s = bounds
        tileS, tileW = self.tileContainingLocation(s,w)
        tileN, tileE = self.tileContainingLocation(n,e)
        self.tileBounds = (tileW,tileN+1,tileE+1,tileS)
        
        self.tileDirectory = "/tmp/transit_authority_elevations"
        if not os.path.exists(self.tileDirectory): os.makedirs(self.tileDirectory)
      
    # Download all the elevation data for the given boundary rectangle.
    def populate(self):

        w,n,e,s = self.tileBounds
        total = (e-w) * (n-s)
        print "Downloading %d tiles..." % total
        
        # Download every one degree x one degree tile in the bounds from usgs.gov.
        for lon in range(w,e):
            for lat in range(s,n):
                # Format the coordinates as a zip filename
                filename = self.filenameForTile(lat, lon)
                zipfilename = filename + ".zip"
                remotepath = "http://dds.cr.usgs.gov/srtm/version2_1/SRTM3/North_America/" + zipfilename
                localpath = self.tileDirectory + "/" + zipfilename
                unzipped = self.tileDirectory + "/" + filename
                
                if (os.path.isfile(unzipped)):
                    result = "(Cached) " + unzipped
                else:
                    # Download
                    fn, h = urllib.urlretrieve(remotepath, localpath)
                    # Unzip the file
                    if (h["content-type"] == "application/zip"):
                        try:
                            success = zipfile.ZipFile(localpath).extractall(self.tileDirectory)
                            result = unzipped
                        except RuntimeError:
                            result = "UNZIP FAILED!"
                    else:
                        result = "NOT FOUND!"
                    
                print "Downloaded %s -> %s" % (remotepath, result)
            
        self.minElevation, self.maxElevation = self.minMaxElevation()
        print "Elevation range: %f-%f" % (self.minElevation, self.maxElevation)

    def tileContainingLocation(self, lat, lon):
        # The SRTM tiles from NASA are 1 degree by 1 degree
        # Return the southwest corner of the 1 degree square containing the given point
        lat = int(math.floor(lat))
        lon = int(math.floor(lon))
        return (lat, lon)

    def filenameForTile(self, lat, lon):
        # Return the SRTM filename used by NASA for the tile at this location
        lonPrefix = "E" if lon > 0 else "W"
        latPrefix = "N" if lat > 0 else "S"
        if lat < 0: lat = abs(lat)
        if lon < 0: lon = abs(lon)
        return "%s%02d%s%03d.hgt" % (latPrefix, abs(lat), lonPrefix, abs(lon))
    
    # Using the elevation files downloaded in .populate(), read the elevation of a specific point.
    def elevationAtLocation(self, lat, lon):
        w,n,e,s = self.bounds
        
        # Find the SRTM tile which contains the point we need
        tileLat, tileLon = self.tileContainingLocation(lat, lon)
        localpath = self.tileDirectory + "/" + self.filenameForTile(tileLat, tileLon)
        htg = HGTFile.HGTFile(localpath)
        
        # Calculate the coordinates of the point in arc seconds relative to the southwest corner of the tile
        innerLat = lat - tileLat
        innerLon = lon - tileLon

        # Read the elevation from file and return
        sample = htg.get_sample(innerLat*3600, innerLon*3600)
        if sample == None or sample < 0: # We'll assume negative heights are ocean and irrelevant
            return 0
        else:
            return sample
     
    # Return the elevation on a scale of 0 (loweset) to 1 (highest elevation on map).
    def scaledElevationAtLocation(self, lat, lon):
        return (self.elevationAtLocation(lat, lon) - self.minElevation) / float(self.maxElevation - self.minElevation)
    
    # Calculate the lowest and highest elevations on the map
    def minMaxElevation(self):
        w,n,e,s = self.bounds
        min = None
        max = None
        for x in range(0,100):
            for y in range(0,100):
                lat = s + (n-s) * y / float(100)
                lon = w + (e-w) * x / float(100)
                val = self.elevationAtLocation(lat, lon)
                if min is None or val < min: min = val
                if max is None or val > max: max = val
        return (min, max)
