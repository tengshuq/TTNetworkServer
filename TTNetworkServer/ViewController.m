//
//  ViewController.m
//  TTNetworkServer
//
//  Created by TengShuQiang on 2017/3/4.
//  Copyright © 2017年 TTeng. All rights reserved.
//

#import "ViewController.h"
#import "TTNetworkServer.h"

static NSString *const ConvertJSONFail = @"https://www.baidu.com";
static NSString *const JSON = @"https://alpha-api.app.net/stream/0/posts/stream/global";
static NSString *const JointURL = @"car/brand/query";
static NSString *const XML = @"http://ws.webxml.com.cn/WebServices/WeatherWS.asmx/getRegionDataset";

@interface ViewController ()

@property (nonatomic, strong) NSURLSessionTask *task;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    TTNetworkConfig *config = [TTNetworkConfig standardConfig];
    config.debugLogEnabled = YES;
    //config.commonParameters = @{@"key1":@"value1"};
    config.cookieEnabled = YES;
    config.baseURL = @"http://apicloud.mob.com";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStatusChange) name:TTNetworkStatusDidChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (void)networkStatusChange {
    NSLog(@"当前网络状态：%ld",(long)[TTNetworkServer networkStatusType]);
}

//请求带缓存
- (IBAction)baseRequest:(UIButton *)sender {
    [TTNetworkServer GET:JointURL parameters:@{@"key":@"112fcd924b710"} cacheResponse:^(NSDictionary *responseCache) {
        NSLog(@"缓存的数据%@",responseCache);
    } succeess:^(NSURLSessionDataTask *task, NSDictionary *responseObject) {
        NSLog(@"网络获取的数据 %@",responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        
    }];
}

//请求不带缓存
- (IBAction)loadData:(UIButton *)sender {
    [TTNetworkServer GET:JointURL parameters:@{@"key":@"112fcd924b710"} cacheResponse:nil succeess:^(NSURLSessionDataTask *task, NSDictionary *responseObject) {
        NSLog(@"网络获取的数据 %@",responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        
    }];
}

- (IBAction)batchRequest:(UIButton *)sender {
    TTNetworkServer *server1 = [TTNetworkServer addGET:ConvertJSONFail parameters:nil cacheResponse:nil];
    TTNetworkServer *server2 = [TTNetworkServer addGET:JSON parameters:nil cacheResponse:nil];
    TTNetworkServer *server3 = [TTNetworkServer addGET:JointURL parameters:@{@"key":@"112fcd924b710"} cacheResponse:nil];
    TTNetworkServer *server4 = [TTNetworkServer addGET:XML parameters:nil cacheResponse:nil];
    [TTNetworkServer startBatchRequest:@[server1,server2,server3,server4] cacheResponse:nil success:^(NSArray<id> *res) {
        id res0 = res[0];
        id res1 = res[1];
        id res2 = res[2];
        id res3 = res[3];
        NSLog(@"%@%@%@%@",res0,res1,res2,res3);
    } failure:^(NSArray<NSError *> *err) {
        NSLog(@"%@\n%@\n%@\n%@",err[0].localizedDescription,err[1].localizedDescription,err[2].localizedDescription,err[3].localizedDescription);
    } task:^(NSArray<NSURLSessionDataTask *> *task) {
        NSLog(@"%@\n%@\n%@\n%@",task[0].currentRequest.URL,task[1].currentRequest.URL,task[2].currentRequest.URL,task[3].currentRequest.URL);
    }];
}

@end
