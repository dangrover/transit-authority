//
//  TAModal.h
//  Transit Authority
//
//  Created by Dan Grover on 9/13/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TATitlebar : UIView
@end

@interface TAModal : UIViewController
@property(strong) IBOutlet UIButton *backButton;
@property(strong) IBOutlet TATitlebar *titleBar;
@property(strong) UIButton *closeButton;

@end

