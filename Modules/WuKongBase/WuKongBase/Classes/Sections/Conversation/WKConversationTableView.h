//
//  WKConversationTableView.h
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol WKConversationTableViewDelegate <NSObject>

@optional

- (void)tableView:(UITableView *)tableView touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)tableView:(UITableView *)tableView touchesEnd:(NSSet *)touches withEvent:(UIEvent *)event;

- (void)tableView:(UITableView *)tableView touchesTime:(NSTimeInterval)timestamp;
@end

@interface WKConversationTableView : UITableView

@property (nonatomic,weak) id<WKConversationTableViewDelegate> conversationTableDelegate;
@end

NS_ASSUME_NONNULL_END
