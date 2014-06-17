//
//  FinanceRowCell.m
//  Transit Authority
//
//  Created by Dan Grover on 7/17/13.
//
//

#import "FinanceRowCell.h"

@implementation FinanceRowCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void) layoutSubviews{
    [super layoutSubviews];
    [self.contentView addSubview:self.col1Label];
    [self.contentView addSubview:self.col2Label];
    [self.contentView addSubview:self.col3Label];
    
    if(self.narrow){
        self.col1Label.frame = CGRectMake(20, 0, 65, 20);
        self.col2Label.frame = CGRectMake(self.col1Label.frame.origin.x + self.col1Label.frame.size.width + 3, self.col1Label.frame.origin.y, self.col1Label.frame.size.width, self.col1Label.frame.size.height);
        self.col3Label.frame = CGRectMake(self.col2Label.frame.origin.x + self.col2Label.frame.size.width +  6, self.col1Label.frame.origin.y, self.col1Label.frame.size.width, self.col1Label.frame.size.height);
    }
}



@end
