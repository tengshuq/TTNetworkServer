//
//  SecondViewController.m
//  TTNetworkServer
//
//  Created by TengShuQiang on 2017/3/4.
//  Copyright © 2017年 TTeng. All rights reserved.
//

#import "SecondViewController.h"
#import "TTNetworkServer.h"

static NSString *google = @"https://developer.apple.com/download";
static NSString *const baidu = @"https://www.baidu.com";

@interface SecondViewController ()

@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self cancelAllTasksWhileViewDidDisappear:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSLog(@"当前网络状态：%ld",[TTNetworkServer networkStatusType]);
}


- (IBAction)loadRequest:(id)sender {
    for (int i = 0; i < 5; i++) {
        [TTNetworkServer GET:google parameters:nil succeess:^(NSURLSessionDataTask *task, NSDictionary *responseObject) {
            
            NSLog(@"翻墙送温暖");
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSLog(@"再也不敢了");
        }];
        [TTNetworkServer GET:baidu parameters:nil succeess:^(NSURLSessionDataTask *task, NSDictionary *responseObject) {
            NSLog(@"翻墙送温暖");
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSLog(@"呵呵呵呵");
        }];
    }
    [TTNetworkServer cancelTaskWithURL:google];
}

- (IBAction)cancelRequest:(id)sender {
    [TTNetworkServer cancelTaskWithURL:google];
}

- (IBAction)cacheData:(id)sender {
    [TTNetworkServer GET:google parameters:nil cacheResponse:^(NSDictionary *responseCache) {
        NSLog(@"\n这是缓存的数据啊:\n %@",responseCache);
    } succeess:^(NSURLSessionDataTask *task, NSDictionary *responseObject) {
        NSLog(@"\n这是新获取的数据啊：\n %@",responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"\n这是没有数据啊：\n %@",error);
    }];
}

@end
