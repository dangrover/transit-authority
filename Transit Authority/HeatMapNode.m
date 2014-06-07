//
//  HeatMapNode.m
//  Transit Authority
//
//  Created by Dan Grover on 9/4/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "HeatMapNode.h"
#import "CCTiledMap.h"
#import "CCTMXTiledMap+Extras.h"
#import "Utilities.h"
#import "UIColor+Cocos.h"

@interface HeatMapNode()
@property(strong, readwrite) GameMap *map;
@property(assign, readwrite) CGSize viewportSize; // in tiles
@property(assign, readwrite) CGSize bufferSize; // in tiles
@property(strong) NSMutableSet *_renderBufferPool;
@end


#define BUFFER_FLAG_GOOD 0
#define BUFFER_FLAG_NEEDS_GENERATE 1
#define BUFFER_FLAG_GENERATING 2

@implementation HeatMapNode{
    NSMutableArray *_bufferSprites;
    CGSize _bufferGridSize; // in multiples of bufferSize
    unsigned short *_generatingBufferFlags;
    NSOperationQueue *_opQueue;
    size_t _renderBufferSize;
    unsigned _numberOfSimultaneousRenders;
    CGSize _bufferPaddingInTiles;
    CGFloat _textureScale; // 0.5 to make it half the res it needs to be
    
    BOOL _disableBlur;
}

- (id) initWithMap:(GameMap *)theGameMap viewportSize:(CGSize)theViewportSize bufferSize:(CGSize)theBufferSize{
    if(self = [super init]){
        self.map = theGameMap;
        self.viewportSize = theViewportSize;
        self.bufferSize = theBufferSize;
        
        #if (TARGET_IPHONE_SIMULATOR)
        _textureScale = 1.0f/8.0f;
        #else
        _textureScale = 1.0f/4.0f;
        #endif
        
        
        _numberOfSimultaneousRenders = 4;
        
        _bufferGridSize = CGSizeMake(ceil(self.map.size.width / self.bufferSize.width),
                                     ceil(self.map.size.height / self.bufferSize.height));
        
        _bufferPaddingInTiles = CGSizeMake(4, 4);
        
        _disableBlur = NO;
        
        NSLog(@"Buffer grid size is %@", NSStringFromCGSize(_bufferGridSize));
        NSLog(@"viewport size is %@", NSStringFromCGSize(self.viewportSize));
       
        _opQueue = [[NSOperationQueue alloc] init];
        [_opQueue setMaxConcurrentOperationCount:_numberOfSimultaneousRenders];
        
        unsigned tilePixelDim = self.map.map.tileSize.width*_textureScale;
        
        
        _renderBufferSize = 4 * ((self.bufferSize.width+(_bufferPaddingInTiles.width*2))*tilePixelDim)*((self.bufferSize.height+(_bufferPaddingInTiles.height*2))*tilePixelDim);
        
        NSLog(@"Actual texture size is %@",NSStringFromCGSize(CGSizeMake(tilePixelDim*(self.bufferSize.width+_bufferPaddingInTiles.width*2),
                                                                         tilePixelDim*(self.bufferSize.height+_bufferPaddingInTiles.height*2))));
        
        
        size_t s = sizeof(unsigned short) * (size_t)_bufferGridSize.width * (size_t)_bufferGridSize.height;
        _generatingBufferFlags = malloc(s);
        // NSLog(@"total buffer flags is %d",s);
        memset(_generatingBufferFlags, 0, s);
        
        
        _bufferSprites = [NSMutableArray arrayWithCapacity:_bufferGridSize.width];
        for(unsigned x = 0; x < _bufferGridSize.width; x++){
            NSMutableArray *thisCol = [NSMutableArray arrayWithCapacity:_bufferGridSize.height];
            for(unsigned y = 0; y < _bufferGridSize.height; y++){
                [thisCol addObject:[NSNull null]];
            }
            [_bufferSprites addObject:thisCol];
        }
        
        self._renderBufferPool = [NSMutableSet setWithCapacity:_numberOfSimultaneousRenders*2];
    }
    
    return self;
}

- (void) dealloc{
    free(_generatingBufferFlags);
}

- (float) _opacityForDensity:(int)density{
    float densityProportion = (float)density/(float)GAMEMAP_MAX_DENSITY;
   // NSLog(@"Density %d -> %f opacity/%f", density, densityProportion, pow(densityProportion, 2));
   // return pow(densityProportion,2);
    return densityProportion;
}

- (void) refresh{
   //NSLog(@"refreshing heat map. pos=%@, view size=%@",NSStringFromCGPoint(self.currentPosition), NSStringFromCGSize(self.viewportSize));
    
    CGPoint topLeftBuffer = [self _bufferForTileCoord:CGPointMake(self.currentPosition.x - ceil(self.viewportSize.width/2),
                                                                  self.currentPosition.y - ceil(self.viewportSize.height/2))];
    
    CGPoint topRightBuffer = [self _bufferForTileCoord:CGPointMake(self.currentPosition.x + ceil(self.viewportSize.width/2),
                                                                   self.currentPosition.y - (self.viewportSize.height/2))];
    
    CGPoint bottomLeftBuffer = [self _bufferForTileCoord:CGPointMake(self.currentPosition.x - ceil(self.viewportSize.width/2),
                                                                     self.currentPosition.y + ceil(self.viewportSize.height/2))];
    
    
    CGRect buffersWeNeed = CGRectMake(topLeftBuffer.x,
                                      topLeftBuffer.y,
                                      topRightBuffer.x - topLeftBuffer.x,
                                      bottomLeftBuffer.y - topLeftBuffer.y);
    
    //NSLog(@"We need the buffers %@",NSStringFromCGRect(buffersWeNeed));
    
    
    for( unsigned xBufferCoord = 0; xBufferCoord < _bufferGridSize.width; xBufferCoord++){
        for( unsigned yBufferCoord = 0; yBufferCoord < _bufferGridSize.height; yBufferCoord++){
            // CGPoint bufferCoord = CGPointMake(xBufferCoord, yBufferCoord);
            if(   (xBufferCoord >= CGRectGetMinX(buffersWeNeed))
               && (xBufferCoord <= CGRectGetMaxX(buffersWeNeed))
               && (yBufferCoord >= CGRectGetMinY(buffersWeNeed))
               && (yBufferCoord <= CGRectGetMaxY(buffersWeNeed))){
                //   NSLog(@"Checking on buffer for %@ -> %d", NSStringFromCGPoint(bufferCoord), (xBufferCoord*(int)_bufferGridSize.height) + yBufferCoord);
                //  NSLog(@"buffer sprites = %@",_bufferSprites);
                
                CCSprite *thisBuffer = _bufferSprites[xBufferCoord][yBufferCoord];
                if(![thisBuffer isEqual:[NSNull null]]){
                    // we already have a buffer here. Good!
                }else{ // We do not have one. Generate it
                    unsigned short flag = _generatingBufferFlags[xBufferCoord*(unsigned)_bufferGridSize.height + yBufferCoord];
                    
                    if(flag == BUFFER_FLAG_GOOD){
                        CGRect bufferTileRect = CGRectMake(self.bufferSize.width * xBufferCoord,
                                                           self.bufferSize.height * yBufferCoord,
                                                           self.bufferSize.width,
                                                           self.bufferSize.height);
                        
                        _generatingBufferFlags[xBufferCoord*(unsigned)_bufferGridSize.height + yBufferCoord] = BUFFER_FLAG_GENERATING;
                        
                        [_opQueue addOperationWithBlock:^{
                            EAGLContext *auxGLContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:((CCGLView *)[CCDirector sharedDirector].view).context.sharegroup];
                            
                            [EAGLContext setCurrentContext:auxGLContext];
                        
                            
                            CCSprite *heatSprite = [[CCSprite alloc] initWithTexture:[self _heatMapWithBoundingBox:bufferTileRect]];
                            
                            
                            CGPoint normalBufferPos = CGPointMake(self.bufferSize.width * xBufferCoord,
                                                                  self.bufferSize.height * yBufferCoord);
                            
                            heatSprite.position = [self.map.landLayer positionAt:CGPointMake(normalBufferPos.x - _bufferPaddingInTiles.width,normalBufferPos.y - _bufferPaddingInTiles.height)];
                            
                            heatSprite.blendFunc = (ccBlendFunc){GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA};
                            heatSprite.anchorPoint = CGPointMake(0,1);
                            heatSprite.scale = 1.0f/_textureScale;
                            [self addChild:heatSprite];
                            /*    CCLabelTTF *label = [[CCLabelTTF alloc] initWithString:[NSString stringWithFormat:@"%d,%d",xBufferCoord,yBufferCoord] fontName:@"Helvetica" fontSize:90];
                             [label setFontFillColor:ccBLACK updateImage:YES];
                             [heatSprite addChild:label];*/
                            
                            [EAGLContext setCurrentContext:nil];
                            
                            _bufferSprites[xBufferCoord][yBufferCoord] = heatSprite;
                            _generatingBufferFlags[xBufferCoord*(unsigned)_bufferGridSize.height + yBufferCoord] = BUFFER_FLAG_GOOD;
                        }];
                    }
                }
            }else{
                // We don't need this buffer anymore! Kill it
                
                CCSprite *s = _bufferSprites[xBufferCoord][yBufferCoord];
                //NSLog(@"Removing tile at %d,%d = %@", xBufferCoord, yBufferCoord, s);
                if(s && ![s isEqual:[NSNull null]]){
                    [self removeChild:s];
                }
                _bufferSprites[xBufferCoord][yBufferCoord] = [NSNull null];
            }
        }
    }
    
    return;

    
}

- (CGPoint) _bufferForTileCoord:(CGPoint)tileCoord{
    // Get the coordinate in the buffer grid that would render this tile coord.
    // Clamp it to the bounds so we don't go off-grid.
    return CGPointMake(MAX(0, MIN(_bufferGridSize.width - 1,
                                  floor(tileCoord.x / self.bufferSize.width))),
                       MAX(0, MIN(_bufferGridSize.height - 1,
                                  floor(tileCoord.y / self.bufferSize.height))));
}

- (NSMutableData *) _getNewRenderBuffer{
    @synchronized(self){
        
        if([self._renderBufferPool count]){
            NSMutableData *recycled = [self._renderBufferPool anyObject];
            [self._renderBufferPool removeObject:recycled];
            [recycled resetBytesInRange:NSMakeRange(0, _renderBufferSize)];
            return recycled;
        }else{
            NSMutableData *b = [[NSMutableData alloc] initWithLength:_renderBufferSize];
            return b;
        }
        
    }
}

- (void) _recycleRenderBuffer:(NSMutableData *)d{
    @synchronized(self){
        [self._renderBufferPool addObject:d];
    }
}

- (CCTexture *) _heatMapWithBoundingBox:(CGRect)boundingBoxInTiles{
  
    //NSLog(@"Started a render");
    float tileSize = self.map.map.tileSize.width * _textureScale;
    CGSize imgSize = CGSizeMake((boundingBoxInTiles.size.width + (_bufferPaddingInTiles.width * 2)) * tileSize,
                                (boundingBoxInTiles.size.height + (_bufferPaddingInTiles.height * 2)) * tileSize);
    
    
    NSMutableData *mainRenderSpace = [self _getNewRenderBuffer];
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate((void *)[mainRenderSpace bytes],
                                             imgSize.width,
                                             imgSize.height,
                                             8,
                                             imgSize.width * 4,
                                             rgbColorSpace,
                                             kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    
    for(unsigned xTile = boundingBoxInTiles.origin.x; xTile < CGRectGetMaxX(boundingBoxInTiles); xTile++){
        for(unsigned yTile = boundingBoxInTiles.origin.y; yTile < CGRectGetMaxY(boundingBoxInTiles); yTile++){
            CGPoint tileCoord = CGPointMake(xTile, yTile);
            
            CGPoint imgCoord = CGPointMake((_bufferPaddingInTiles.width + (xTile - boundingBoxInTiles.origin.x)) * tileSize,
                                           (_bufferPaddingInTiles.height + ((CGRectGetMaxY(boundingBoxInTiles) - yTile))) * tileSize);
            
            CGRect tileRect = CGRectMake(imgCoord.x, imgCoord.y, tileSize, tileSize);
            
            unsigned resD = [self.map residentialDensityAt:tileCoord];
            unsigned comD = [self.map commercialDensityAt:tileCoord];
            if(resD){
                CGContextSetRGBFillColor(ctx, 1, 0, 0, [self _opacityForDensity:resD]);
                //    CGContextFillRect(ctx, tileRect);
                unsigned insetAmount = (GAMEMAP_MAX_DENSITY - resD) * tileSize*0.1;
                CGContextFillEllipseInRect(ctx, CGRectInset(tileRect, insetAmount, insetAmount));
            }
            
            if(comD){
                CGContextSetRGBFillColor(ctx, 0, 0, 1, [self _opacityForDensity:comD]);
                //      CGContextFillRect(ctx, tileRect);
                unsigned insetAmount = (GAMEMAP_MAX_DENSITY - comD) * tileSize*0.1;
                CGContextFillEllipseInRect(ctx, CGRectInset(tileRect, insetAmount, insetAmount));
            }
        }
    }
    

    NSMutableData *blurRenderSpace  = nil;
    // Now blur what we drew in a separate buffer.
    if(!_disableBlur){
        CIImage *ci = [CIImage imageWithBitmapData:mainRenderSpace
                                       bytesPerRow:CGBitmapContextGetBytesPerRow(ctx)
                                              size:imgSize
                                            format:kCIFormatRGBA8
                                        colorSpace:rgbColorSpace];
        
        CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @(NO)}];
        
        CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
        [filter setValue:@(tileSize*0.5) forKey:@"inputRadius"];
        [filter setValue:ci forKey:@"inputImage"];
        
        blurRenderSpace = [self _getNewRenderBuffer];
        
        [context render:filter.outputImage
               toBitmap:(void *)[blurRenderSpace bytes]
               rowBytes:CGBitmapContextGetBytesPerRow(ctx)
                 bounds:CGRectMake(0, 0, imgSize.width, imgSize.height)
                 format:kCIFormatRGBA8
             colorSpace:rgbColorSpace];
    }
    
    // Now generate a texture from the buffer
    
    // border for debugging
        CGContextSetLineWidth(ctx, 10);
        CGContextSetStrokeColorWithColor(ctx, [[UIColor blackColor] CGColor]);
        CGContextStrokeRect(ctx, CGRectMake(1, 1, imgSize.width - 2, imgSize.height - 2));
    
    
    
    CCTexture *tex = [[CCTexture alloc] initWithData:_disableBlur ? [mainRenderSpace bytes] : [blurRenderSpace bytes]
                        pixelFormat:CCTexturePixelFormat_RGBA8888
                         pixelsWide:imgSize.width
                         pixelsHigh:imgSize.height
                contentSizeInPixels:imgSize
                       contentScale:1];
    
    //NSLog(@"Finished a render");
    [tex setAntialiased:NO];
    
    CGContextRelease(ctx);
    CGColorSpaceRelease(rgbColorSpace);
    
    if(!_disableBlur) [self _recycleRenderBuffer:blurRenderSpace];
    [self _recycleRenderBuffer:mainRenderSpace];
    
    return tex;
    
}

@end
