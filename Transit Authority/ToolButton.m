//
//  ToolButton.m
//  Transit Authority
//
//  Created by Dan Grover on 6/18/13.
//
//

#import "ToolButton.h"

@implementation ToolButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect frame = self.imageView.frame;
    frame = CGRectMake(truncf((self.bounds.size.width - frame.size.width) / 2), 20, frame.size.width, frame.size.height);
    self.imageView.frame = frame;
    
    frame = self.titleLabel.frame;
    frame = CGRectMake(truncf((self.bounds.size.width - frame.size.width) / 2), self.bounds.size.height - 10 - frame.size.height, frame.size.width, frame.size.height);
    self.titleLabel.frame = frame;
}

@end
