//
//  main.m
//  trader
//
//  Created by Chieh on 2025/3/15.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
        NSLog(@"帅哥来了1");
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
