//
//  NSCoding-Macros.h
//  Transit Authority
//
//  Created by James Murdza on 4/13/14.
//  Copyright (c) 2014 Brown Bag Software LLC. All rights reserved.
//

// Speed up NSCoding with Macros: http://stablekernel.com/blog/speeding-up-nscoding-with-macros/

#define OBJC_STRINGIFY(x) @#x
#define encodeObject(x) [encoder encodeObject:x forKey:OBJC_STRINGIFY(x)]
#define decodeObject(x) x = [decoder decodeObjectForKey:OBJC_STRINGIFY(x)]
#define encodeFloat(x) [encoder encodeFloat:x forKey:OBJC_STRINGIFY(x)]
#define decodeFloat(x) x = [decoder decodeFloatForKey:OBJC_STRINGIFY(x)]
#define encodeDouble(x) [encoder encodeDouble:x forKey:OBJC_STRINGIFY(x)]
#define decodeDouble(x) x = [decoder decodeDoubleForKey:OBJC_STRINGIFY(x)]
#define encodeInt(x) [encoder encodeInt:x forKey:OBJC_STRINGIFY(x)]
#define decodeInt(x) x = [decoder decodeIntForKey:OBJC_STRINGIFY(x)]
