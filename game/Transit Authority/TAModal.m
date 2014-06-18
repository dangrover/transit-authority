#import "TAModal.h"

@interface TATitlebar()
@property(assign) TAModal *parent;
@end

@interface TAModal()<UINavigationControllerDelegate>

@end

@implementation TAModal

- (void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad){
        [self.backButton removeFromSuperview];
        
        self.view.layer.cornerRadius = 10;
        self.view.layer.borderColor = [[UIColor grayColor] CGColor];
        self.view.layer.borderWidth = 0.5;
        self.view.backgroundColor = [UIColor colorWithWhite:1 alpha:1];
        self.view.layer.shadowColor = [[UIColor blackColor] CGColor];
        self.view.layer.shadowOffset = CGSizeMake(0, 1);
        self.view.layer.shadowOpacity = 0.25;
        self.view.layer.shadowRadius = 1;
        
    }
    
    if(!self.navigationController.delegate) [self.navigationController setDelegate:self];
    
    self.titleBar.parent = self;
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated{
    if([viewController isKindOfClass:[TAModal class]]){
        TAModal *newOne = (TAModal *)viewController;
        newOne.closeButton = self.closeButton;
    }
}
- (void) _titleBarDragged:(UIButton *)theTitlebar{
    NSLog(@"titlebar dragged %@",theTitlebar);
    
}
@end

@implementation TATitlebar

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    if([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad) return;
    
    UITouch *ourTouch = [touches anyObject];
    
    CGPoint loc = [ourTouch locationInView:self];
    CGPoint locPrev = [ourTouch previousLocationInView:self];
    
    UIView *mainViewToMove = self.parent.navigationController.view;
    CGPoint delta = CGPointMake(loc.x - locPrev.x, loc.y - locPrev.y);
    
    mainViewToMove.frame = CGRectMake(mainViewToMove.frame.origin.x + delta.x,
                                      mainViewToMove.frame.origin.y + delta.y,
                                      mainViewToMove.frame.size.width,
                                      mainViewToMove.frame.size.height);
    
    UIButton *close = self.parent.closeButton;
    self.parent.closeButton.frame = CGRectMake(close.frame.origin.x + delta.x,
                                               close.frame.origin.y + delta.y,
                                               close.frame.size.width,
                                               close.frame.size.height);
    
    
    
}

@end