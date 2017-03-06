//
//  TTNetworkToast.h
//  TTNetworkServer
//
//  Created by TengShuQiang on 2017/3/4.
//  Copyright © 2017年 TTeng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MBProgressHUD.h"

@interface TTNetworkToast : NSObject

+ (void)showLoadingOnView:(UIView *)view;
+ (void)hideLoadingOnView:(UIView *)view;
+ (void)showProgress:(float)progress message:(NSString *)msg onView:(UIView *)view;
+ (void)showCompleteMessage:(NSString *)msg OnView:(UIView *)view;

@end
