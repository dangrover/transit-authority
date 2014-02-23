//
//  FinanceRowCell.h
//  Transit Authority
//
//  Created by Dan Grover on 7/17/13.
//
//

#import <UIKit/UIKit.h>

@interface FinanceRowCell : UITableViewCell

@property(assign) IBOutlet UILabel *col1Label;
@property(assign) IBOutlet UILabel *col2Label;
@property(assign) IBOutlet UILabel *col3Label;
@property(assign) BOOL narrow;

@end
