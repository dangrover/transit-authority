#!/usr/bin/env python
import sys, os, shutil, datetime, math
import mapnik
import tmxlib
import wand
from PIL import Image
from util import *
from PopulationMap import PopulationMap
from ElevationMap import ElevationMap

######################
# Constants

TILE_SIZE = 16 #tile size in non-retina pixels

# Tile IDs for different things in the tile set
LAND_GID=0 
WATER_GID=1
PARK_GID=2
AIRPORT_GID=3

# Some pre-determined geographical bounds for generating levels
# Format: w, n, e, s
CITIES = {
    "boston":{
        "bounds":[-71.1372, 42.3063,-71.006, 42.3816]
    },
    "sf":{
        "bounds":[-122.5237,37.6539,-122.2614,37.8152],
        "rotate":-6
    },
    "la":{
        "bounds":[-118.5864,33.7038,-118.0199,34.1027]
    },
    "san-diego":{
        "bounds":[-117.2607,32.6615,-117.1191,32.7626],
    },
    "nyc":{
        "bounds":[-74.0743,40.5884,-73.7873,40.8097],
        "rotate": 28.911 # use manhattan north
    }
}

# The geographical scale used. 
SCALE_TILES_PER_MILE = 25

######################

# Set up projections
# spherical mercator (most common target map projection of osm data imported with osm2pgsql)
merc = mapnik.Projection('+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs +over')
longlat = mapnik.Projection('+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')


def get_tileset(name, path):
    pil_image = Image.open(path)
    return tmxlib.ImageTileset(name=name, 
                               tile_size=(TILE_SIZE,TILE_SIZE),
                               image=tmxlib.Image(size=pil_image.size,source=os.path.basename(path)))
                               
def rotate2d(degrees,point,origin):
    """
    A rotation function that rotates a point around a point
    to rotate around the origin use [0,0]
    """
    x = point[0] - origin[0]
    yorz = point[1] - origin[1]
    newx = (x*math.cos(math.radians(degrees))) - (yorz*math.sin(math.radians(degrees)))
    newyorz = (x*math.sin(math.radians(degrees))) + (yorz*math.cos(math.radians(degrees)))
    newx += origin[0]
    newyorz += origin[1]
    
    return newx,newyorz


def main():
    base_path = os.path.dirname(sys.argv[0])
    output_base_dir = os.path.join(base_path, "output")
    template_dir = os.path.join(base_path, "template")

    if len(sys.argv) > 1:
        city_name = sys.argv[1]
    else:
        print "City choices are: %s" % ", ".join(CITIES.iterkeys())
        city_name = raw_input("Which city? ")

    if not CITIES.get(city_name):
        print "Invalid city"
        return

    print "\n\nRendering %s" % city_name
    city = CITIES[city_name]

    # Make the file structure. Copy from /template
    # Skip this step if the -tmx option is specified to only generate tmx.
    tmxOnly = "-tmx" in sys.argv
    output_dir = os.path.join(output_base_dir, city_name)
    if not tmxOnly:
        if os.path.exists(output_dir):
            shutil.rmtree(output_dir)
        shutil.copytree(template_dir, output_dir)


    land_image_output_uri = os.path.join(output_dir,"landform.png")
    land_rotated_path = os.path.join(output_dir, "landform-rotated.png")
    map_output_uri = os.path.join(output_dir,city_name+".tmx")

    # Figure out the map scale
    bounds = city['bounds']
    w,n,e,s = bounds

    radian_width = distance_on_unit_sphere(n, e, n, w)
    radian_height = distance_on_unit_sphere(n, e, s, e)
    miles_height, miles_width = (radian_height * EARTH_RADIUS), (radian_width * EARTH_RADIUS)
    tiles_height, tiles_width = int(math.floor(miles_height*SCALE_TILES_PER_MILE)), int(math.floor(miles_width*SCALE_TILES_PER_MILE))

    print "Real dimensions: %0.2fmi x %0.2fmi" % (miles_width, miles_height)
    print "Tile dimensions: %d x %d" % (tiles_width, tiles_height)

    img_width = tiles_width*TILE_SIZE
    img_height = tiles_height*TILE_SIZE

    bbox = mapnik.Box2d(*bounds)

    transform = mapnik.ProjTransform(longlat,merc)
    merc_bbox = transform.forward(bbox) # Transform bounds from long/lat to spherical mercator

    land_map = mapnik.Map(img_width,img_height)
    mapnik.load_map(land_map,os.path.join(base_path, "stylesheet/osm-cleaner.xml"))
    land_map.srs = merc.params() # ensure the target map projection is mercator
    land_map.zoom_to_box(merc_bbox) # fix aspect ratio
    
    # If -tmx option specified attempt to read image file rather than regenerate
    # This allows us to generate only the TMX file
    land_map_image = None
    if (tmxOnly):
        if os.path.exists(land_rotated_path):
            land_image_output_uri = land_rotated_path
        if os.path.exists(land_image_output_uri):
            land_map_image = Image.open(land_image_output_uri)
            print "Loading landform from " + land_image_output_uri
        else:
            print "No landform png found."

    # Render the landform map
    # render the map to an image
    if (land_map_image is None):
        print "RENDERING LANDFORM MAP"
        land_map_image = mapnik.Image(img_width,img_height)
        mapnik.render(land_map, land_map_image)
        land_map_image.save(land_image_output_uri,'png')

    if not tmxOnly:
        #Render the refernce map (with streets and junk)
        print "RENDERING REFERENCE MAP"
        regular_map = mapnik.Map(img_width,img_height)
        mapnik.load_map(regular_map, os.path.join(base_path, "stylesheet/osm.xml"))
        regular_map.srs = merc.params() # ensure the target map projection is mercator
        regular_map.zoom_to_box(merc_bbox) # fix aspect ratio
        reference_map_path = os.path.join(output_dir, "reference.png")
        mapnik.render_to_file(regular_map, reference_map_path)

    # Do any rotating we need with imagemagick
    if city.get('rotate') and land_image_output_uri != land_rotated_path:
        print "PEFORMING ROTATION"
        
        if not tmxOnly:
            # convert reference.png -alpha set \( +clone -background none -rotate 30 \) -gravity center  -compose Src -composite  reference-rotated.png
            ref_rotated_path = os.path.join(output_dir, "reference-rotated.png")
            reference_rot = Image.open(reference_map_path).rotate(city['rotate'],expand=0)
            reference_rot.save(ref_rotated_path)
    
        land_rot = Image.open(land_image_output_uri).rotate(city['rotate'],expand=0)
        land_rot.save(land_rotated_path)
        land_image_output_uri = land_rotated_path


    # Now let's generate the TMX file from the landform output
    print "Generating TMX file"

    # Set up all the layers
    tmx_map = tmxlib.Map(size=(tiles_width, tiles_height), 
                         tile_size=(TILE_SIZE, TILE_SIZE), 
                         orientation='orthogonal')


    tmx_map.properties = {
        "start": "%d, %d" % (tiles_width/2, tiles_height/2),
        "generator-scale": str(SCALE_TILES_PER_MILE),
        "generator-geo-bounds": str(bounds),
        "generator-date": str(datetime.datetime.now())
    }

    if(city.get("rotate")):
        tmx_map.properties["generator-rotation"] = str(city["rotate"])

    
    land_layer = tmx_map.add_layer('Land')
    land_tileset = get_tileset(name="Landform",
                               path=os.path.join(output_dir, "tileset-land.png"))

    com_layer = tmx_map.add_layer('Commercial')
    com_tileset = get_tileset(name="Commercial Density", path=os.path.join(output_dir, "tileset-com-density.png"))

    res_layer = tmx_map.add_layer('Residential')
    res_tileset = get_tileset(name="Residential Density", path=os.path.join(output_dir, "tileset-res-density.png"))

    elevation_layer = tmx_map.add_layer('Elevation')
    elevation_tileset = get_tileset(name="Elevation", path=os.path.join(output_dir, "tileset-elevation.png"))
    
    neighborhoods_layer = tmx_map.add_layer(name="Neighborhoods", layer_class=tmxlib.ObjectLayer)
    streets_layer = tmx_map.add_layer(name="Streets", layer_class=tmxlib.ObjectLayer)
    
    # Populate the layers based on the output
    land_image = Image.open(land_image_output_uri)
    population = PopulationMap(bounds)
    population.populate()
    elevation = ElevationMap(bounds)
    elevation.populate()
    
    print "Writing TMX layers..."
    
    previewXScale = round(tiles_height/40)
    previewYScale = round(tiles_height/20)
    
    for y in range(0,tiles_height):
    
        for x in range(0,tiles_width):
            
            printPreviewTile = "-v" in sys.argv and y%previewYScale == 0 and x%previewXScale == 0
            
            x_pixel = (TILE_SIZE/2) + (TILE_SIZE * x)
            y_pixel = (TILE_SIZE/2) + (TILE_SIZE * y)
            
            # Calculate the latitude and longitude for the tile so we can lookup population and elevation.
            # First, adjust for any rotation of the image
            if city.get('rotate'):
                rotatedX, rotatedY = rotate2d(city.get('rotate'), (x,y), (tiles_width/2,tiles_height/2))
            else:
                rotatedX, rotatedY = x, y
            # Then fit x and y into the bounds of the map
            lat = s + (n-s) * rotatedY / float(tiles_height)
            lon = w + (e-w) * rotatedX / float(tiles_width)

            # Find the elvation at this point
            tileElevation = elevation.scaledElevationAtLocation(lat, lon)
            # If -v option, print an elevation grid to the command line
            if printPreviewTile:
                sys.stdout.write("%d" % min(round(tileElevation*10),9))
                sys.stdout.flush()
                
            r,g,b,a = land_image.getpixel((x_pixel, y_pixel))

            #print "looking at pixel %f,%f,%f" % (r,g,b)
            if a == 0: # if no alpha, skip the pixel
                continue

            land_gid, res_gid, com_gid, el_gid = None, None, None, None
            if r==0 and g==0 and b==0:
                land_gid = AIRPORT_GID
            elif r==242: # land is almost white
                land_gid = LAND_GID

                # This function takes the number of deviations (sigma) from the center of a normal distribution graph
                # It returns which third of the distribution area the value is in
                # a.k.a., about 33% of all values lie within .4 std deviations of center
                def deviationsToThirds(deviations):
                    if (deviations <= -.4):
                        return 0
                    elif (deviations < .4):
                        return 1
                    else:
                        return 2
                
                (tilePopulation, tileWorkers) = population.populationDensityAtLocation(lat, lon)
                # Turn standard deviations into tile 0, 1 or 2
                # About one third of each tile should be represented on the graph
                res_gid = deviationsToThirds(tilePopulation)
                com_gid = deviationsToThirds(tileWorkers)
                
                # To choose which elevation tile to use, we define some threshold heights relative to the highest and lowest point on the map
                if (tileElevation > .6):
                    el_gid = 2
                elif (tileElevation > .4):
                    el_gid = 1
                elif (tileElevation > .2):
                    el_gid = 0
                
            elif g > r and g > b:
                land_gid = PARK_GID
            else:
                land_gid = WATER_GID

            # Draw the tile for this square that will appear in the game.
            land_layer[x,y] = land_tileset[land_gid]

            # Maybe add population tiles in the two population layers
            if com_gid >= 0:
                com_layer[x,y] = com_tileset[com_gid]
            if res_gid >= 0:
                res_layer[x,y] = res_tileset[res_gid]
            
            # Maybe add a tile in the elevation layer
            if not el_gid is None:
                elevation_layer[x,y] = elevation_tileset[el_gid]

        # If -v option, print an elevation grid
        if "-v" in sys.argv and y%previewYScale == 0: print ""

    land_layer[0, 0] = land_tileset[0]
    tmx_map.save(map_output_uri)

    print "DONE!"

if __name__ == "__main__":
    main()