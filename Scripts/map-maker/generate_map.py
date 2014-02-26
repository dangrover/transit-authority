#!/usr/bin/env python
import sys, os, shutil, datetime
import mapnik
import tmxlib
import wand
from PIL import Image
from util import *


######################
# Constants

TILE_SIZE = 16 #tile size in non-retina pixels

# Tile IDs for different things in the tile set
LAND_GID=9 
WATER_GID=29
PARK_GID=30
AIRPORT_GID=74

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
    output_dir = os.path.join(output_base_dir, city_name)
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    shutil.copytree(template_dir, output_dir)


    land_image_output_uri = os.path.join(output_dir,"landform.png")
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
    
    # Render the landform map
    print "RENDERING LANDFORM MAP"
    # render the map to an image
    land_map_image = mapnik.Image(img_width,img_height)
    mapnik.render(land_map, land_map_image)
    land_map_image.save(land_image_output_uri,'png')

    #Render the refernce map (with streets and junk)
    print "RENDERING REFERENCE MAP"
    regular_map = mapnik.Map(img_width,img_height)
    mapnik.load_map(regular_map, os.path.join(base_path, "stylesheet/osm.xml"))
    regular_map.srs = merc.params() # ensure the target map projection is mercator
    regular_map.zoom_to_box(merc_bbox) # fix aspect ratio
    reference_map_path = os.path.join(output_dir, "reference.png")
    mapnik.render_to_file(regular_map, reference_map_path)

    # Do any rotating we need with imagemagick
    if city.get('rotate'):
        print "PEFORMING ROTATION"
        # convert reference.png -alpha set \( +clone -background none -rotate 30 \) -gravity center  -compose Src -composite  reference-rotated.png
        ref_rotated_path = os.path.join(output_dir, "reference-rotated.png")
        land_rotated_path = os.path.join(output_dir, "landform-rotated.png")
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
    
    neighborhoods_layer = tmx_map.add_layer(name="Neighborhoods", layer_class=tmxlib.ObjectLayer)
    streets_layer = tmx_map.add_layer(name="Streets", layer_class=tmxlib.ObjectLayer)

    # Populate the layers based on the output
    land_image = Image.open(land_image_output_uri)
    for x in range(0,tiles_width):
        for y in range(0,tiles_height):
            x_pixel = (TILE_SIZE/2) + (TILE_SIZE * x)
            y_pixel = (TILE_SIZE/2) + (TILE_SIZE * y)

            r,g,b,a = land_image.getpixel((x_pixel, y_pixel))

            #print "looking at pixel %f,%f,%f" % (r,g,b)
            if a == 0: # if no alpha, skip the pixel
                continue

            land_gid, res_gid, com_gid = None, None, None
            if r==0 and g==0 and b==0:
                land_gid = AIRPORT_GID
            elif r==242: # land is almost white
                land_gid = LAND_GID
                res_gid = 1
                com_gid = 1
            elif g > r and g > b:
                land_gid = PARK_GID
            else:
                land_gid = WATER_GID

            land_layer[x,y] = land_tileset[land_gid]

            if com_gid:
                com_layer[x,y] = com_tileset[com_gid]

            if res_gid:
                res_layer[x,y] = res_tileset[res_gid]

    land_layer[0, 0] = land_tileset[0]
    tmx_map.save(map_output_uri)

    print "DONE!"

if __name__ == "__main__":
    main()