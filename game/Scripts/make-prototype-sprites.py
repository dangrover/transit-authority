import subprocess, os, shutil

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))+"/../"
SPRITES_DIR = os.path.abspath(SCRIPT_DIR+"/prototype-sprites")
DEST_DIR = os.path.join(os.environ['CONFIGURATION_BUILD_DIR'],os.environ['CONTENTS_FOLDER_PATH'])

for l in os.listdir(SPRITES_DIR):
	if l.endswith(".png") and not l.endswith("-hd.png"):
		input_file = os.path.join(SPRITES_DIR, l)
		output_file = os.path.join(DEST_DIR,l.replace(".png","-hd.png"))

		subprocess.check_call(['/usr/local/bin/convert', input_file, '-scale', '200%', output_file])
		shutil.copyfile(input_file, os.path.join(DEST_DIR,l))