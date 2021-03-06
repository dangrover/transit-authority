/*
 * HKTMXTiledMap
 *
 * cocos2d-extensions
 * https://github.com/cocos2d/cocos2d-iphone-extensions
 * 
 * HKASoftware
 * http://hkasoftware.com
 *
 * Copyright (c) 2011 HKASoftware
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * TMX Tiled Map support:
 * http://www.mapeditor.org
 *
 */

#import "HKTMXTiledMap.h"
#import "CCTMXXMLParser.h"
#import "CCTiledMapObjectGroup.h"
#import "CCSprite.h"
#import "CCTextureCache.h"
#import "CGPointExtension.h"
#import "ccMacros.h"
#import "CCTiledMap.h"
#import "CCTiledMapLayer.h"

#pragma mark -
#pragma mark CCTMXTiledMap

@interface HKTMXTiledMap (Private)
-(id) parseLayer:(CCTiledMapLayerInfo *)layer map:(CCTiledMapInfo *)mapInfo;
-(CCTiledMapTilesetInfo *) tilesetForLayer:(CCTiledMapLayerInfo*)layerInfo map:(CCTiledMapInfo*)mapInfo;
@end

@implementation HKTMXTiledMap
@synthesize mapSize=mapSize_;
@synthesize tileSize=tileSize_;
@synthesize mapOrientation=mapOrientation_;
@synthesize objectGroups=objectGroups_;
@synthesize properties=properties_;

+(id) tiledMapWithTMXFile:(NSString*)tmxFile
{
	return [[[self alloc] initWithFile:tmxFile] autorelease];
}

-(id) initWithTMXFile:(NSString*)tmxFile
{
	NSAssert(tmxFile != nil, @"TMXTiledMap: tmx file should not bi nil");

	if ((self=[super init])) {
		
		[self setContentSize:CGSizeZero];

		CCTiledMapInfo *mapInfo = [CCTiledMapInfo formatWithTMXFile:tmxFile];
		
		NSAssert( [mapInfo.tilesets count] != 0, @"TMXTiledMap: Map not found. Please check the filename.");
		
		mapSize_ = mapInfo.mapSize;
		tileSize_ = mapInfo.tileSize;
		mapOrientation_ = mapInfo.orientation;
		objectGroups_ = [mapInfo.objectGroups retain];
		properties_ = [mapInfo.properties retain];
		tileProperties_ = [mapInfo.tileProperties retain];
				
		int idx=0;

		for( CCTiledMapLayerInfo *layerInfo in mapInfo.layers ) {
            
			if( layerInfo.visible ) {
				id child = [self parseLayer:layerInfo map:mapInfo];
                [self addChild:child z:idx name:[NSString stringWithFormat:@"%d", idx]];
				
				// update content size with the max size
                CGSize childSize = [child contentSizeInPoints];
                
				CGSize currentSize = [self contentSizeInPoints];
				currentSize.width = MAX( currentSize.width, childSize.width );
				currentSize.height = MAX( currentSize.height, childSize.height );
				[self setContentSize:currentSize];
                
				idx++;
			}			
		}		
	}

	return self;
}

-(void) dealloc
{
	[objectGroups_ release];
	[properties_ release];
	[tileProperties_ release];
	[super dealloc];
}

// private
-(id) parseLayer:(CCTiledMapLayerInfo *)layerInfo map:(CCTiledMapInfo *)mapInfo
{
	CCTiledMapTilesetInfo *tileset = [self tilesetForLayer:layerInfo map:mapInfo];
	HKTMXLayer *layer = [HKTMXLayer layerWithTilesetInfo:tileset layerInfo:layerInfo mapInfo:mapInfo];

	// tell the layerinfo to release the ownership of the tiles map.
	layerInfo.ownTiles = NO;

	[layer setupTiles];
	
	return layer;
}

-(CCTiledMapTilesetInfo *) tilesetForLayer:(CCTiledMapLayerInfo *)layerInfo map:(CCTiledMapInfo *)mapInfo
{
	CCTiledMapTilesetInfo *tileset = nil;
	CFByteOrder o = CFByteOrderGetCurrent();
	
	CGSize size = layerInfo.layerSize;

	id iter = [mapInfo.tilesets reverseObjectEnumerator];
	for( CCTiledMapTilesetInfo* tileset in iter) {
		for( unsigned int y=0; y < size.height; y++ ) {
			for( unsigned int x=0; x < size.width; x++ ) {
				
				unsigned int pos = x + size.width * y;
				unsigned int gid = layerInfo.tiles[ pos ];
				
				// gid are stored in little endian.
				// if host is big endian, then swap
				if( o == CFByteOrderBigEndian )
					gid = CFSwapInt32( gid );
				
				// XXX: gid == 0 --> empty tile
				if( gid != 0 ) {
                    
                    // JEB - Mask out flip bits to allow individual layers to have 
                    // different tileset.
                    gid &= kFlippedMask;
					
					// Optimization: quick return
					// if the layer is invalid (more than 1 tileset per layer) an assert will be thrown later
					  if( (gid & kFlippedMask) >= tileset.firstGid )
						return tileset;
				}
			}
		}		
	}
	
	// If all the tiles are 0, return empty tileset
	CCLOG(@"cocos2d: Warning: TMX Layer '%@' has no tiles", layerInfo.name);
	return tileset;
}


// public

-(HKTMXLayer*) layerNamed:(NSString *)layerName 
{
	for( HKTMXLayer *layer in _children ) {
		if([layer isKindOfClass:[HKTMXLayer class]]){
			if( [layer.layerName isEqual:layerName] )
				return layer;
		}
	}
	
	// layer not found
	return nil;
}

-(CCTiledMapObjectGroup*) objectGroupNamed:(NSString *)groupName
{
	for( CCTiledMapObjectGroup *objectGroup in objectGroups_ ) {
		if( [objectGroup.groupName isEqual:groupName] )
			return objectGroup;
		}
	
	// objectGroup not found
	return nil;
}

// XXX deprecated
-(CCTiledMapObjectGroup *) groupNamed:(NSString *)groupName
{
	return [self objectGroupNamed:groupName];
}

-(id) propertyNamed:(NSString *)propertyName 
{
	return [properties_ valueForKey:propertyName];
}
-(NSDictionary*)propertiesForGID:(unsigned int)GID{
	return [tileProperties_ objectForKey:[NSNumber numberWithInt:GID]];
}
@end

