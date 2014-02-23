//
//  InstructionsViewController.m
//  Transit Authority
//
//  Created by Dan Grover on 7/16/13.
//
//

#import "InstructionsViewController.h"
#import "AppDelegate.h"

@interface InstructionsViewController ()

@end

@implementation InstructionsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [webView loadRequest:[NSURLRequest requestWithURL:[[NSBundle mainBundle] URLForResource:@"instructions" withExtension:@"html"]]];
    
}


- (IBAction)back:(id)sender{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{}];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
