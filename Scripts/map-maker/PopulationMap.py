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
        self.tracts = []
        counties = []
        tractfile = open("Gaz_tracts_national.txt", "r")
        columns = tractfile.readline().strip().split("\t");
        for line in tractfile:
            row = line.strip().split("\t")
            geoid = row[1]
            lat, lon = float(row[8]), float(row[9])
            if lat > n and lat < s and lon > w and lon < e:
                state, county, tract = geoid[:2], geoid[2:5], geoid[5:]
                self.tracts.append((lat, lon, state, county, tract))
                if (state, county) not in counties:
                    counties.append((state, county))
        tractfile.close()
        
        assert len(self.tracts) > 0, "No tracts found in city bounds"
        print "Using %d tracts found in %d counties within city bounds..." % (len(self.tracts), len(counties))
        
        # Query the Census API to get stats on each county, by tract.
        # It seems as though there is a maximum of one county per query.
        print "Querying census.gov..."
        c = Census("243ef0b1be61224c39bb87b5b3d7c59aa5818fe5")
        self.tractPopulations = {}
        for county in counties:
            result = c.acs.get((
            'NAME',
            'B01001_001E', # Total population
            'B08604_001E' # This should be something like workers in area
            ), {'for': 'tract:*', 'in': 'state:%s county:%s' % (county[0], county[1])})
            for tract in result:
                key = tract['state'] + tract['county'] + tract['tract']
                self.tractPopulations[key] = int(tract['B01001_001E'])
        print "Acquired population stats for %d tracts" % len(self.tractPopulations)
        # These should probably be trimmed down to only the tracts we wanted, not all the tracts in the counties we wanted.
        # This would make our statistics more accurate, and probably make the program faster.

        
        self.averagePopulation = self.calculateAveragePopulation()
        self.populationStd = self.calculatePopulationStd()
        print "Average population per tract: %.2f, Standard dev: %.2f" % (self.averagePopulation, self.populationStd)
    
    # One more efficient way of doing this would possibly be to generate
    # an equally spaced dotmap with a high enough resolution.
    def geoidAtLocation(self, x, y):
        w,n,e,s = self.bounds
        tic = time.clock()
        tileLat = s + (n-s) * x
        tileLon = w + (e-w) * y
        def distanceToCurrentTile((lat, lon, state, county, tract)):
            return (lat-tileLat)**2 + (lon-tileLon)**2
        closestTract = min(self.tracts, key=distanceToCurrentTile)
        lat, lon, state, county, tract = closestTract
        geoid = state + county + tract
        toc = time.clock()
        #print "Geo lookup took %f seconds" % (toc - tic)
        return geoid
        
    def calculateAveragePopulation(self):
        return sum(self.tractPopulations.values()) / float(len(self.tractPopulations))
        
    def calculatePopulationStd(self):
        squareDiffs = 0
        average = self.averagePopulation
        for pop in self.tractPopulations.values():
            squareDiffs += (pop-self.averagePopulation)**2
        return math.sqrt(squareDiffs / float(len(self.tractPopulations)))

    def calculateMaxPopulation(self):
        return max(self.tractPopulations.values())
        
    # Return the standard deviation of the located tract's population density from the larger area
    # This is actually population, not population density.
    # We can factor in tract size later, but fortunately tracts are roughly the same size
    def populationDensityAtLocation(self, x, y):
        geoid = self.geoidAtLocation(x, y)
        tilePopulation = self.tractPopulations[geoid]
        return (tilePopulation - self.averagePopulation) / self.populationStd