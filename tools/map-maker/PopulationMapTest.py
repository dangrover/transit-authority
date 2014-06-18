import PopulationMap

map = PopulationMap.PopulationMap([-71.1372, 42.3063,-71.006, 42.3816])
map.populate()
print map.populationDensityAtLocation(42.35, -71.13)
