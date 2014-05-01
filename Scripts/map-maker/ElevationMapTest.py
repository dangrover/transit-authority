import ElevationMap

map = ElevationMap.ElevationMap([-108,37,-107,36])
map.populate()
print map.elevationAtLocation(37,-108)