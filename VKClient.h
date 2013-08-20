//
//  VKClient.h
//  VKClient
//
//  Created by Kirill Ivonin on 11.07.13.
//  Copyright (c) 2013 BlueBirdTouch, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"

@interface VKUser : NSObject

@property (nonatomic, retain) NSString* accessToken;
@property (nonatomic, retain) NSString* userId;
@property (nonatomic, assign) NSTimeInterval tokenExpirationTime;

+ (VKUser*)me;

@end

typedef void (^CompletionBlock)(NSError*);
typedef void (^CompletionStringBlock)(NSString*);

@interface VKClient : NSObject <UIWebViewDelegate> {
    CompletionBlock _requestCompletion;
    CompletionBlock _loginCompletion;
    CompletionStringBlock _uploadCompletion;
    CompletionBlock _finalCompletion;
    
    NSDictionary* requestParams;
    
    UIWindow* modalWindow;
    UIWebView* modalWebView;
    UIViewController* modalViewController;
    UIActivityIndicatorView* modalActivity;
}

+ (VKClient*)client;
- (void)setPermissions:(NSString*)permissions andVKAppID:(NSString*)vkAppID;
- (void)postStatus:(NSString*)status withImage:(UIImage*)image andCompletionHandler:(void (^)(NSError* error))completionBlock;
- (void)postStatus:(NSString*)status withDoc:(NSData*)data andCompletionHandler:(void (^)(NSError* error))completionBlock;
- (void)loginWithCompletionHandler:(void (^)(NSError* error))completionBlock;

@end
