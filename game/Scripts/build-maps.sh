#! /bin/sh

if [ "${ACTION}" = "clean" ]
then
echo "cleaning..."
else

echo "*** Convert HD TMX files to SD ones..."

for infile in `ls ./Maps/*.tmx`
do
	filename=$(basename "$infile")
	extension="${filename##*.}"
	filename="${filename%.*}"
	outfile="./Maps/hd/$filename-hd.tmx"

	./Scripts/WBTMXTool/WBTMXTool -in "$infile" -out $outfile -scale 2.0 -suffixAction add
done

# create hd directory to avoid errors
mkdir -p ./Maps/hd/

# change filenames
grep -rl matchstring ./Maps/hd/ | xargs sed -i 's/.png/-hd.png/g'

# copy them into the built product
cp -v ./Maps/*.tmx "${CONFIGURATION_BUILD_DIR}/$CONTENTS_FOLDER_PATH/"
cp -v ./Maps/hd/*.tmx "${CONFIGURATION_BUILD_DIR}/$CONTENTS_FOLDER_PATH/"

# copy our json scenario descriptions
cp -v ./Maps/*.json "${CONFIGURATION_BUILD_DIR}/$CONTENTS_FOLDER_PATH/"

#copy background images
cp -v ./Maps/*-bg.jpg "${CONFIGURATION_BUILD_DIR}/$CONTENTS_FOLDER_PATH/"


fi
exit 0