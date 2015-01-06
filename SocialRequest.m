//
//  VKStartScreen.m
//
//  Copyright (c) 2014 VK.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "SocialRequest.h"
#import "MainScene.h"

static NSString *const TOKEN_KEY = @"my_application_access_token";
static NSString *const NEXT_CONTROLLER_SEGUE_ID = @"START_WORK";
static NSArray  * SCOPE = nil;
static BOOL auth = NO;

@implementation SocialRequest

- (void)viewDidLoad {
    
    SCOPE = @[VK_PER_WALL];
	[super viewDidLoad];
    
	[VKSdk initializeWithDelegate:self andAppId:@"4550504"];
    if ([VKSdk wakeUpSession])
    {
        auth = YES;
        NSLog(@"LOGIN");
    }
}

-(void)outAuthorize {
    
    if ([VKSdk vkAppMayExists]) {
        [VKSdk authorize:SCOPE]; // Через Safari
    } else {
        [VKSdk authorize:SCOPE revokeAccess:YES forceOAuth:YES inApp:YES]; // Через WebView
    }
}

-(void)postOnWall:(NSString*)text fromObject:(id)fromObject {
    
    // Проверяем есть ли авторизация
    if(auth == YES) {
        NSLog(@"POST ON WALL: %@", text);
        
        VKRequest * postReq = [[VKApi wall] post:@{VK_API_MESSAGE : text}];
        postReq.attempts = 10;
        postReq.completeBlock = ^(VKResponse *response) {
            // Вызываем скрыть кнопку
            [fromObject wallPostComplete];
        };
        
        VKBatchRequest * batch = [[VKBatchRequest alloc] initWithRequests:postReq, nil];
        
        [batch executeWithResultBlock:^(NSArray *responses) {
            NSLog(@"Responses: %@", responses);
        } errorBlock:^(NSError *error) {
            NSLog(@"Error: %@", error);
        }];

    } else {
        NSLog(@"NEED AUTH");
        [VKSdk authorize:SCOPE revokeAccess:YES];
    }
}

- (void)logout:(id)sender {
    [VKSdk forceLogout];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

-(UIViewController*) getRootViewController {
    return [UIApplication sharedApplication].keyWindow.rootViewController;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void)vkSdkNeedCaptchaEnter:(VKError *)captchaError {
	VKCaptchaViewController *vc = [VKCaptchaViewController captchaControllerWithError:captchaError];
	[vc presentIn:self];
}

- (void)vkSdkTokenHasExpired:(VKAccessToken *)expiredToken {
	[self outAuthorize];
}

- (void)vkSdkReceivedNewToken:(VKAccessToken *)newToken {
    auth = YES;
}

- (void)vkSdkShouldPresentViewController:(UIViewController *)controller {
	[self presentViewController:controller animated:YES completion:nil];
}

- (void)vkSdkAcceptedUserToken:(VKAccessToken *)token {
    auth = YES;
}
- (void)vkSdkUserDeniedAccess:(VKError *)authorizationError {
	[[[UIAlertView alloc] initWithTitle:nil message:@"Access denied" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
}

@end
