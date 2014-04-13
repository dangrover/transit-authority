from census import Census
import time, math

class PopulationMap:
    "This class downloads census population data for a given area and then returns data for any given point in the area."
    
    def __init__(self, bounds):
        self.bounds = bounds
        
    def populate(self):
        w,n,e,s = self.bounds
        
        print "Reading tab delimited tract file..."
        
        # Populate the database line by line.
        self.tracts = {}
        counties = []
        tractfile = open("Gaz_tracts_national.txt", "r")
        columns = tractfile.readline().strip().split("\t");
        for line in tractfile:
            row = line.strip().split("\t")
            geoid = row[1]
            landArea = float(row[4])
            lat, lon = float(row[8]), float(row[9])
            if lat > n and lat < s and lon > w and lon < e:
                state, county, tract = geoid[:2], geoid[2:5], geoid[5:]
                self.tracts[state + county + tract] = (lat, lon, landArea)
                if (state, county) not in counties:
                    counties.append((state, county))
        tractfile.close()
        
        assert len(self.tracts.values()) > 0, "No tracts found in city bounds"
        print "Using %d tracts found in %d counties within city bounds..." % (len(self.tracts.values()), len(counties))
        
        # Query the Census API to get stats on each county, by tract.
        # It seems as though there is a maximum of one county per query.
        print "Querying census.gov..."
        c = Census("243ef0b1be61224c39bb87b5b3d7c59aa5818fe5")
        self.tractPopulations = {}
        self.tractWorkers = {}
        for county in counties:
            result = c.acs.get((
            'NAME',
            'B01001_001E', # Total population
            'B08009_001E' # Workers (includes those who work near home)
            ), {'for': 'tract:*', 'in': 'state:%s county:%s' % (county[0], county[1])})
            for tract in result:
                
                # Since the census returns all tracts in the county, trim down to only the ones in bounds
                key = tract['state'] + tract['county'] + tract['tract']
                if key in self.tracts.keys():
                    # Population densities are calculated by people / land area of tract
                    # and put into arrays to perform stats on
                    tractArea = self.tracts[key][2] / 1000.0 # Land area of the tract in square kilometers
                    self.tractPopulations[key] = float(tract['B01001_001E']) / tractArea
                    self.tractWorkers[key] = float(tract['B08009_001E']) / tractArea
                    
        # This should be the same as the previously printed tract count
        # If it's different, our tract file is probably out of date
        print "Acquired population stats for %d tracts" % len(self.tractPopulations)
        
        self.averagePopulation = self.calculateAverage(self.tractPopulations.values())
        self.populationStd = self.calculateStd(self.tractPopulations.values(), self.averagePopulation)

        self.averageWorkers = self.calculateAverage(self.tractWorkers.values())
        self.workersStd = self.calculateStd(self.tractWorkers.values(), self.averageWorkers)

        print "Average population per tract: %.2f people/sqkm, Standard dev: %.2f people/sqkm" % (self.averagePopulation, self.populationStd)
        print "Average workers per tract: %.2f people/sqkm, Standard dev: %.2f people/sqkm" % (self.averageWorkers, self.workersStd)
    
    # One more efficient way of doing this would possibly be to generate
    # an equally spaced dotmap with a high enough resolution.
    def geoidAtLocation(self, x, y):
        w,n,e,s = self.bounds
        tic = time.clock()
        tileLat = s + (n-s) * y
        tileLon = w + (e-w) * x
        def distanceToCurrentTile(geoid):
            lat, lon, area = self.tracts[geoid]
            return (lat-tileLat)**2 + (lon-tileLon)**2
        geoid = min(self.tracts, key=distanceToCurrentTile)
        toc = time.clock()
        #print "Geo lookup took %f seconds" % (toc - tic)
        return geoid
        
    def calculateAverage(self, values):
        return sum(values) / float(len(values))
        
    def calculateStd(self, values, average):
        squareDiffs = 0
        for pop in values:
            squareDiffs += (pop-average)**2
        return math.sqrt(squareDiffs / float(len(values)))
           
    # Return the standard deviation of the located tract's population density from the larger area
    def populationDensityAtLocation(self, x, y):
        geoid = self.geoidAtLocation(x, y)
        populationDeviation = (self.tractPopulations[geoid] - self.averagePopulation) / self.populationStd
        workersDeviation = (self.tractWorkers[geoid] - self.averageWorkers) / self.workersStd
        return (populationDeviation, workersDeviation)