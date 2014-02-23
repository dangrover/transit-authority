//
//  UIImage+Blur.m
//  Transit Authority
//
//  Created by Dan Grover on 9/4/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "UIImage+Blur.h"

@implementation UIImage (Blur)

- (UIImage *) blurredImageWithRadius:(CGFloat)radius{
    
    CIImage *ci = [CIImage imageWithCGImage:[self CGImage]];
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
     
     [filter setValue:@(radius) forKey:@"inputRadius"];
     [filter setValue:ci forKey:@"inputImage"];
     
     CIImage *result = [filter valueForKey:kCIOutputImageKey];
     return [UIImage imageWithCGImage:[context createCGImage:result fromRect:[result extent]]];
}

@end
