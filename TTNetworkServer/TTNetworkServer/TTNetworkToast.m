//
//  TTNetworkToast.m
//  TTNetworkServer
//
//  Created by TengShuQiang on 2017/3/4.
//  Copyright © 2017年 TTeng. All rights reserved.
//

#import "TTNetworkToast.h"

@implementation TTNetworkToast


+ (void)showLoadingOnView:(UIView *)view {
    
    view = view ? : [UIApplication sharedApplication].keyWindow;
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showHUDAddedTo:view animated:YES];
    });
}

+ (void)showProgress:(float)progress message:(NSString *)msg onView:(UIView *)view {
    
    view = view ? : [UIApplication sharedApplication].keyWindow;
    dispatch_async(dispatch_get_main_queue(), ^{
        MBProgressHUD *hud = [MBProgressHUD HUDForView:view];
        hud.mode = MBProgressHUDModeDeterminate;
        hud.progress = progress;
        hud.label.numberOfLines = 0;
        hud.label.text = msg;
    });
}

+ (void)showCompleteMessage:(NSString *)msg OnView:(UIView *)view{
    
    view = view ? : [UIApplication sharedApplication].keyWindow;
    dispatch_async(dispatch_get_main_queue(), ^{
        MBProgressHUD *hud = [MBProgressHUD HUDForView:view];
        UIImage *image = [[UIImage imageNamed:@"Checkmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        hud.customView = imageView;
        hud.mode = MBProgressHUDModeCustomView;
        hud.label.text = msg;
        hud.label.numberOfLines = 0;
        [hud hideAnimated:YES afterDelay:2.f];
    });
}

+ (void)hideLoadingOnView:(UIView *)view {
    
    view = view ? : [UIApplication sharedApplication].keyWindow;
    [MBProgressHUD hideHUDForView:view animated:YES];
}

@end
