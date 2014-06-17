import struct

class HGTFile:
    "This class parses a Shuttle Radar Topography Mission Data (.hgt) file"
    
    def __init__(self, filename):
        self.filename = filename
    
    def get_sample(self, n, e):
        i = 1201 - int(round(n / 3, 0))
        j = int(round(e / 3, 0))
        with open(self.filename, "rb") as f:
            f.seek(((i - 1) * 1201 + (j - 1)) * 2)  # go to the right spot,
            buf = f.read(2)  # read two bytes and convert them:
            val = struct.unpack('>h', buf)[0]  # ">h" is a signed two byte integer
            if not val == -32768:  # the not-a-valid-sample value
                return val
            else:
                return None