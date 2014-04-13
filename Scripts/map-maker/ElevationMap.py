import math, urllib, zipfile, re, os.path
import HGTFile

class ElevationMap:
    "This class downloads NASA ground elevation data for a given area and then returns data for any given point in the area."
    
    def __init__(self, bounds):
        
        # Expand the boundary rectangle to the closest degree lines
        w,n,e,s = bounds
        w = int(math.floor(w))
        n = int(math.ceil(n))
        e = int(math.ceil(e))
        s = int(math.floor(s))
        self.bounds = (w,n,e,s)
        
        self.tileDirectory = "/tmp/transit_authority_elevations"
        if not os.path.exists(self.tileDirectory): os.makedirs(self.tileDirectory)
      
    # Download all the elevation data for the given boundary rectangle.
    def populate(self):
        
        w,n,e,s = self.bounds
        total = (1+e-w) * (1+n-s)
        print "Downloading %d tiles..." % total
        
        # Download every one degree x one degree tile in the bounds from usgs.gov.
        for lon in range(w,e+1):
            for lat in range(s,n+1):
                # Format the coordinates as a zip filename
                filename = self.filenameAtLocation(lat, lon)
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

    def filenameAtLocation(self, lat, lon):
        lonPrefix = "E" if lon > 0 else "W"
        latPrefix = "N" if lat > 0 else "S"
        return "%s%02d%s%03d.hgt" % (latPrefix, abs(lat), lonPrefix, abs(lon))
        
    def elevationAtLocation(self, lat, lon):
        w,n,e,s = self.bounds
        localpath = self.tileDirectory + "/" + self.filenameAtLocation(lat, lon)
        htg = HGTFile.HGTFile(localpath)
        return htg.get_sample((lon-w)*60, (lat-s)*60)
        
    def scaledElevationAtLocation(self, lat, lon):
        return (self.elevationAtLocation(lat, lon) - self.minElevation) / float(self.maxElevation - self.minElevation)
    
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
