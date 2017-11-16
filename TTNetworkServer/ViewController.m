//
//  ViewController.m
//  TTNetworkServer
//
//  Created by TengShuQiang on 2017/3/4.
//  Copyright © 2017年 TTeng. All rights reserved.
//

#import "ViewController.h"
#import "TTNetworkServer.h"
#import "AFNetworking.h"

static NSString *const ConvertJSONFail = @"http://liveapi.rr-b.cn/api/course/learn";
static NSString *const JSON = @"https://alpha-api.app.net/stream/0/posts/stream/global";
static NSString *const JointURL = @"car";//@"car/brand/query";
static NSString *const XML = @"http://ws.webxml.com.cn/WebServices/WeatherWS.asmx/getRegionDataset";

@interface ViewController ()

@property (nonatomic, strong) NSURLSessionTask *task;

@end

@implementation ViewController

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (AFHTTPSessionManager *)manager {
    static AFHTTPSessionManager *_manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [AFHTTPSessionManager manager];
    });
    return _manager;
}

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
    /*
    [TTNetworkServer GET:JointURL parameters:@{@"key":@"112fcd924b710"} cacheResponse:nil succeess:^(NSURLSessionDataTask *task, NSDictionary *responseObject) {
        NSLog(@"网络获取的数据 %@",responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        
    }];
     */
    for (int i = 0; i < 5; i++) {
        if (_task) {
            [_task cancel];
        }
        _task = [[self manager] GET:ConvertJSONFail parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            
        }];
        /*
        _task = [TTNetworkServer GET:ConvertJSONFail parameters:nil succeess:^(NSURLSessionDataTask *task, NSDictionary *responseObject) {
            
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            
        }];
         */
    }
}

- (IBAction)batchRequest:(UIButton *)sender {
    TTNetworkServer *server1 = [TTNetworkServer addPOST:ConvertJSONFail parameters:nil cacheResponse:nil];
    TTNetworkServer *server2 = [TTNetworkServer addGET:JSON parameters:nil cacheResponse:nil];
    TTNetworkServer *server3 = [TTNetworkServer addGET:JointURL parameters:@{@"key":@"112fcd924b710"} cacheResponse:nil];
    TTNetworkServer *server4 = [TTNetworkServer addGET:XML parameters:nil cacheResponse:nil];
    [TTNetworkServer startBatchRequest:@[server1,server2,server3,server4] success:^(NSArray<id> *responses) {
        id res0 = responses[0];
        id res1 = responses[1];
        id res2 = responses[2];
        id res3 = responses[3];
        //NSLog(@"%@%@%@%@",res0,res1,res2,res3);
    } failure:^(NSArray<id> *errors) {
        NSLog(@"\n---%@\n---%@\n---%@\n---%@",errors[0],errors[1],errors[2],errors[3]);
    } task:^(NSArray<NSURLSessionDataTask *> *tasks) {
         NSLog(@"\n---%@\n---%@\n---%@\n---%@",tasks[0].currentRequest.URL,tasks[1].currentRequest.URL,tasks[2].currentRequest.URL,tasks[3].currentRequest.URL);
    }];
}

@end
