#! /bin/sh

if [ "${ACTION}" = "clean" ]
then
echo "cleaning..."
else

echo "$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH"

echo "bd = ${CONFIGURATION_BUILD_DIR}"
for infile in `ls ./Transit\ Authority/Resources/prototype-sprites/*.png`
do
	echo "file=$infile"
	#filename=$(basename "$infile")
	#extension="${filename##*.}"
	#filename="${filename%.*}"
	#outfile="./Maps/hd/$filename-hd.tmx"

	#./Scripts/WBTMXTool/WBTMXTool -in "$infile" -out $outfile -scale 2.0 -suffixAction add
done

# change filenames
grep -rl matchstring ./Maps/hd/ | xargs sed -i 's/.png/-hd.png/g'

# copy them into the built product
cp -v ./Maps/*.tmx "${CONFIGURATION_BUILD_DIR}/$CONTENTS_FOLDER_PATH/"
cp -v ./Maps/hd/*.tmx "${CONFIGURATION_BUILD_DIR}/$CONTENTS_FOLDER_PATH/"

fi
exit 0