//
//  MoreTool.m
//  Transit Authority
//
//  Created by Dan Grover on 7/8/13.
//
//

#import "MoreTool.h"
#import "Utilities.h"
#import "MainGameScene.h"
#import "AppDelegate.h"

@implementation MoreTool

- (id) init{
    if (self = [super init]){
        [[UINib nibWithNibName:@"MoreToolUI" bundle:nil] instantiateWithOwner:self options:nil];
    }
    return self;
}


- (BOOL) showsHelpText{
    return NO;
}

- (BOOL) allowsPanning{
    return YES;
}

- (void) _notImp{
    QuickAlert(@"Not implemented yet", @"");
}

- (IBAction)save:(id)sender{
    [self _notImp];
}

- (IBAction)exit:(id)sender{
    [((AppController *)[UIApplication sharedApplication].delegate) exitToMainMenu];
}

- (IBAction)settings:(id)sender{
    [self _notImp];
}

- (IBAction)help{
    [self _notImp];
}

@end
