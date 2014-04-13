import ElevationMap

map = ElevationMap.ElevationMap([-71.1372, 42.3063,-71.006, 42.3816])
map.populate()
print map.elevationAtLocation(42.35, -71.13)