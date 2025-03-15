//
//  ViewController.m
//  trader
//
//  Created by Chieh on 2025/3/15.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>

@interface ViewController () <WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) NSMutableArray *vixData;
@property (nonatomic, strong) NSMutableArray *nvdaData;
@property (nonatomic, strong) NSMutableArray *dates;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"帅哥来了3");
    self.view.backgroundColor = UIColor.systemPinkColor;
    
    self.title = @"VIX与NVDA涨跌幅对比";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 初始化数据数组
    self.vixData = [NSMutableArray array];
    self.nvdaData = [NSMutableArray array];
    self.dates = [NSMutableArray array];
    
    // 设置加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.center = self.view.center;
    [self.view addSubview:self.loadingIndicator];
    
    // 设置WebView用于显示图表
    [self setupChartView];
    
    // 获取真实数据
    [self fetchRealStockData];
}

- (void)setupChartView {
    // 创建WebView来显示图表
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    self.webView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.webView];
    
    // 设置WebView约束
    [NSLayoutConstraint activateConstraints:@[
        [self.webView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)fetchRealStockData {
    [self.loadingIndicator startAnimating];
    
    // 创建一个调度组来同步两个请求
    dispatch_group_t group = dispatch_group_create();
    
    // 获取VIX数据
    dispatch_group_enter(group);
    [self fetchHistoricalDataForSymbol:@"^VIX" completion:^(NSArray *dates, NSArray *percentChanges) {
        if (dates && percentChanges) {
            [self.dates addObjectsFromArray:dates];
            [self.vixData addObjectsFromArray:percentChanges];
        }
        dispatch_group_leave(group);
    }];
    
    // 获取NVDA数据
    dispatch_group_enter(group);
    [self fetchHistoricalDataForSymbol:@"NVDA" completion:^(NSArray *dates, NSArray *percentChanges) {
        if (dates && percentChanges) {
            // 如果已经有日期数据，我们只需要百分比变化数据
            if (self.dates.count > 0) {
                [self.nvdaData addObjectsFromArray:percentChanges];
            } else {
                [self.dates addObjectsFromArray:dates];
                [self.nvdaData addObjectsFromArray:percentChanges];
            }
        }
        dispatch_group_leave(group);
    }];
    
    // 当两个请求都完成时生成图表
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self.loadingIndicator stopAnimating];
        [self generateChartWithData];
    });
}

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol completion:(void(^)(NSArray *dates, NSArray *percentChanges))completion {
    // 获取当前日期
    NSDate *endDate = [NSDate date];
    
    // 获取一年前的日期
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    [dateComponents setMonth:-2]; // 12个月前
    NSDate *startDate = [calendar dateByAddingComponents:dateComponents toDate:endDate options:0];
    
    // 格式化日期为Unix时间戳
    NSTimeInterval startInterval = [startDate timeIntervalSince1970];
    NSTimeInterval endInterval = [endDate timeIntervalSince1970];
    
    // 构建Yahoo Finance API URL
    NSString *urlString = [NSString stringWithFormat:@"https://query1.finance.yahoo.com/v7/finance/chart/%@?period1=%.0f&period2=%.0f&interval=1d&events=history",
                          symbol, startInterval, endInterval];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error fetching data for %@: %@", symbol, error);
            completion(nil, nil);
            return;
        }
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            NSLog(@"Error parsing JSON for %@: %@", symbol, jsonError);
            completion(nil, nil);
            return;
        }
        
        // 解析Yahoo Finance API响应
        NSMutableArray *dates = [NSMutableArray array];
        NSMutableArray *percentChanges = [NSMutableArray array];
        
        NSDictionary *result = json[@"chart"][@"result"][0];
        NSArray *timestamps = result[@"timestamp"];
        NSDictionary *indicators = result[@"indicators"];
        NSDictionary *quotes = indicators[@"quote"][0];
        NSArray *closePrices = quotes[@"close"];
        
        if (timestamps && closePrices && timestamps.count == closePrices.count) {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd"];
            
            for (int i = 1; i < timestamps.count; i++) {
                // 计算每日涨跌幅
                NSNumber *previousClose = closePrices[i-1];
                NSNumber *currentClose = closePrices[i];
                
                if (![previousClose isKindOfClass:[NSNull class]] && ![currentClose isKindOfClass:[NSNull class]]) {
                    double previousValue = [previousClose doubleValue];
                    double currentValue = [currentClose doubleValue];
                    
                    if (previousValue > 0) {
                        double percentChange = ((currentValue - previousValue) / previousValue) * 100.0;
                        [percentChanges addObject:@(percentChange)];
                        
                        // 格式化日期
                        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[timestamps[i] doubleValue]];
                        [dates addObject:[dateFormatter stringFromDate:date]];
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(dates, percentChanges);
        });
    }];
    
    [task resume];
}

- (void)generateChartWithData {
    // 确保我们有数据
    if (self.vixData.count == 0 || self.nvdaData.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"数据错误"
                                                                       message:@"无法获取股票数据，请稍后再试。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // 使用HTML和JavaScript (Chart.js) 创建图表
    NSString *htmlTemplate = @"<!DOCTYPE html>\
    <html>\
    <head>\
        <meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'>\
        <script src='https://cdn.jsdelivr.net/npm/chart.js'></script>\
        <style>\
            body { margin: 0; padding: 20px; font-family: -apple-system, sans-serif; }\
            .chart-container { position: relative; height: 80vh; width: 100%; }\
        </style>\
    </head>\
    <body>\
        <div class='chart-container'>\
            <canvas id='stockChart'></canvas>\
        </div>\
        <script>\
            const ctx = document.getElementById('stockChart').getContext('2d');\
            const dates = %@;\
            const vixData = %@;\
            const nvdaData = %@;\
            \
            const chart = new Chart(ctx, {\
                type: 'line',\
                data: {\
                    labels: dates,\
                    datasets: [{\
                        label: 'VIX涨跌幅(%)',\
                        data: vixData,\
                        borderColor: 'red',\
                        backgroundColor: 'rgba(255, 0, 0, 0.1)',\
                        borderWidth: 2,\
                        pointRadius: 3,\
                        tension: 0.1\
                    }, {\
                        label: 'NVDA涨跌幅(%)',\
                        data: nvdaData,\
                        borderColor: 'green',\
                        backgroundColor: 'rgba(0, 255, 0, 0.1)',\
                        borderWidth: 2,\
                        pointRadius: 3,\
                        tension: 0.1\
                    }]\
                },\
                options: {\
                    responsive: true,\
                    maintainAspectRatio: false,\
                    plugins: {\
                        title: {\
                            display: true,\
                            text: '2025年VIX与NVDA每日涨跌幅对比',\
                            font: { size: 18 }\
                        },\
                        legend: {\
                            position: 'bottom'\
                        }\
                    },\
                    scales: {\
                        x: {\
                            ticks: { maxRotation: 45, minRotation: 45 }\
                        },\
                        y: {\
                            title: {\
                                display: true,\
                                text: '涨跌幅(%)'\
                            }\
                        }\
                    }\
                }\
            });\
        </script>\
    </body>\
    </html>";
    
    // 将数据转换为JSON字符串
    NSError *error;
    NSData *datesData = [NSJSONSerialization dataWithJSONObject:self.dates options:0 error:&error];
    NSData *vixData = [NSJSONSerialization dataWithJSONObject:self.vixData options:0 error:&error];
    NSData *nvdaData = [NSJSONSerialization dataWithJSONObject:self.nvdaData options:0 error:&error];
    
    NSString *datesString = [[NSString alloc] initWithData:datesData encoding:NSUTF8StringEncoding];
    NSString *vixString = [[NSString alloc] initWithData:vixData encoding:NSUTF8StringEncoding];
    NSString *nvdaString = [[NSString alloc] initWithData:nvdaData encoding:NSUTF8StringEncoding];
    
    // 填充HTML模板
    NSString *html = [NSString stringWithFormat:htmlTemplate, datesString, vixString, nvdaString];
    
    // 加载HTML到WebView
    [self.webView loadHTMLString:html baseURL:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"图表加载完成");
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"图表加载失败: %@", error);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"图表加载失败"
                                                                   message:[error localizedDescription]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
