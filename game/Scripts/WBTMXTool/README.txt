=================
WBTMXTool 1.0-RC3
=================

For more details, you may refer to the development notes at http://wasabibit.org/WasabiBit/Dev_Notes.html


There are two ways to run the tool:

----------------------------------------------------------------
1) Running WBTMXTool from command line:

From SD to HD:
./WBTMXTool -in sample.tmx -out sample-hd.tmx -scale 2.0 -suffixForHD -hd -suffixAction add

FRom HD to SD:
./WBTMXTool -in sample-hd.tmx -out sample.tmx -scale 0.5 -suffixForHD -hd -suffixAction remove

----------------------------------------------------------------
2) Running WBTMXTool as a preprocess before your main project:

Here in this example, this is the way I am currently using WBTMXTool for me to convert all HD files in a specified directory to SD files in a different directory. (If you want, you can do in the reverse way - from SD to HD.)

1) Place the executable in ${SRCROOT}/../WBTMXTool directory.
WBTMXTool executable is within WBTMXTool directory.

2) Create staging directories:
${SRCROOT}/../StageTMXs/eachOne-hd  <- For HD TMX files (I create HD TMX files only and put all of them here.)
${SRCROOT}/../StageTMXs/eachOne     <- For SD TMX files (Empty directory initially)
3) Place all your HD TMX files in ${SRCROOT}/../StageTMXs/eachOne-hd

4) Don't forget to make your game project dependent on automate_stuff.sh in Xcode.
Please note that the source TMX files in this example start with TileMap and TexturePacker is used for scaling the tile images themselves separately.

It's possible that this script may not work in your project most likely due to the directory structures. If this happened, please check if each of the directories used here is correctly found and reached in the script and adjust the script accordingly.

---
Here is a small script called automate_stuff.sh which is placed at 1 level higher than my main project file.
Part of my automate_stuff.sh integrated with my Xcode:

#! /bin/sh
WBTMXTool=${SRCROOT}/../WBTMXTool/WBTMXTool

if [ "${ACTION}" = "clean" ]
then
	echo "cleaning..."
else

	echo "*** Convert HD TMX files to SD ones..."

	newfile=""
    
    // Please note that all my source HD TMX files start with TileMap...-hd.tmx
	for file in 'ls ../StageTMXs/eachOne-hd/TileMap*-hd.tmx'
	do
		#echo "input HD TMX File: $file"
        temp0='echo $file|cut -d'/' -f2'
        temp1='echo $file|cut -d'/' -f3|cut -d'-' -f1'
		temp2='echo $file|cut -d'/' -f4'
        prefix='echo $temp2|cut -d'.' -f1'
        prefixNoHD='echo $prefix|cut -d'-' -f1'
        ext='echo $temp2|cut -d'.' -f2'
        infile="$file"
        outfile="../$temp0/$temp1/$prefixNoHD.$ext"
        echo "Input HD TMX File: $infile"
        echo "Output SD TMX File: $outfile"
		${WBTMXTool} -in $infile -out $outfile -scale 0.5 -suffixAction remove -suffixForHD -hd -outCondensed no
	done
	cp ${SRCROOT}/../StageTMXs/eachOne-hd/TileMap*-hd.tmx ${SRCROOT}/Resources
	cp ${SRCROOT}/../StageTMXs/eachOne/TileMap*.tmx ${SRCROOT}/Resources
fi
exit 0


----------------------------------------------------------------

Syntax: $WBTMXTool -in <input_file_with_or_w/o_path> -out <output_file_with_or_w/o_path> [-scale <0.5|2.0|any_number>] [-suffixForHD <-hd|any> -suffixAction <none|add|remove>] [ -xmlVersion <1.0|any> -xmlEncoding <UTF-8|any>] [-outCondensed <yes|no>]

The scale option ‘-scale’ applies to the following tag:attribute pairs. 
object:x
object:y
object:width
object:height
map:tilewidth
map:tileheight
map:spacing
map:margin
tileset:tilewidth
tileset:tileheight
tileset:spacing
tileset:margin
(Added two more below on 9/28/2011. Thanks to rgbedin for finding the issue!)
image:width
image:height
(Added the following on 1/8/2013 to uptake new tags in Tiled)
tileoffset:x
tileoffset:y
polyline:points
polygon:points

The suffix option ‘-suffixAction’ applies to the following tag:attribute pairs. 
image:source