//
//  VKClient.m
//  VKClient
//
//  Created by Kirill Ivonin on 11.07.13.
//  Copyright (c) 2013 BlueBirdTouch, LLC. All rights reserved.
//

#import "VKClient.h"
#import "NSString+URLEncoding.h"

static NSString *const kVKRedirectUrl = @"https://oauth.vk.com/blank.html";

@implementation VKUser

+ (VKUser*)me {
    static VKUser *instance = nil;
    
    @synchronized (self) {
        if (instance == nil) {
            instance = [[self alloc] init];
        }
    }
    
    return instance;
}

- (NSUserDefaults*)standardDefaults {
    return [NSUserDefaults standardUserDefaults];
}

- (NSString*)accessToken {
    return [[self standardDefaults] objectForKey:@"vk_access_token"];
}

- (NSString*)userId {
    return [[self standardDefaults] objectForKey:@"vk_user_id"];
}

- (NSTimeInterval)tokenExpirationTime {
    return [[[self standardDefaults] objectForKey:@"vk_token_exp_time"] doubleValue];
}

- (void)setAccessToken:(NSString *)accessToken {
    [[self standardDefaults] setObject:accessToken forKey:@"vk_access_token"];
    [[self standardDefaults] synchronize];
}

- (void)setTokenExpirationTime:(NSTimeInterval)tokenExpirationTime {
    NSString *intervalString = [NSString stringWithFormat:@"%f", tokenExpirationTime];
    [[self standardDefaults] setObject:intervalString forKey:@"vk_token_exp_time"];
    [[self standardDefaults] synchronize];
}

- (void)setUserId:(NSString *)userId {
    [[self standardDefaults] setObject:userId forKey:@"vk_user_id"];
    [[self standardDefaults] synchronize];
}


@end

@implementation VKClient

#pragma mark Thread-safe instance

+ (VKClient*)client {
    static VKClient *instance = nil;
    
    @synchronized (self) {
        if (instance == nil) {
            instance = [[self alloc] init];
        }
    }
    
    return instance;
}

- (NSUserDefaults*)standardDefaults {
    return [NSUserDefaults standardUserDefaults];
}

- (NSError*)requestError {
    NSError* error = [NSError errorWithDomain:@"VK" code:150 userInfo:[NSDictionary dictionaryWithObject:@"request failed" forKey:@"reason"]];
    return error;
}

#pragma mark Permissions and app ID

- (void)setPermissions:(NSString*)permissions andVKAppID:(NSString*)vkAppID {
    [[self standardDefaults] setObject:permissions forKey:@"vk_permissions"];
    [[self standardDefaults] setObject:vkAppID forKey:@"vk_app_id"];
    [[self standardDefaults] synchronize];
}

- (NSString*)vkPermissions {
    return [[self standardDefaults] objectForKey:@"vk_permissions"];
}

- (NSString*)vkAppID {
    return [[self standardDefaults] objectForKey:@"vk_app_id"];
}

#pragma mark Main post methods

- (void)postStatus:(NSString *)status withImage:(UIImage *)image andCompletionHandler:(void (^)(NSError* error))completionBlock{
    _requestCompletion = completionBlock;
    [self requestAddressForPhotosWallUploadServerWithCompletionHandler:^(NSString *string) {
        if (string) {
            [self uploadPhoto:image toVKServer:[NSURL URLWithString:string] WithCompletionHandler:^(NSString *string) {
                if (string){
                    [self uploadPhotoWithParams:requestParams toVKWallWithCompletionHandler:^(NSString *string) {
                        if (string){
                            [self postToVKWallWithText:status attachID:string withCompletionHandler:^(NSString *string) {
                                if (string){
                                    NSLog(@"%@",string);
                                    _requestCompletion(nil);
                                }else{
                                    _requestCompletion([self requestError]);
                                    return;
                                }
                            }];
                        }else{
                            _requestCompletion([self requestError]);
                            return;
                        }
                    }];
                }else{
                    _requestCompletion([self requestError]);
                    return;
                }
            }];
        }else{
            _requestCompletion([self requestError]);
            return;
        }
    }];
}

- (void)postStatus:(NSString *)status withDoc:(NSData *)data andCompletionHandler:(void (^)(NSError* error))completionBlock {
    _requestCompletion = completionBlock;
    [self requestAddressForDocsWallUploadServerWithCompletionHandler:^(NSString *string) {
        if (string) {
            [self uploadDocument:data toVKServer:[NSURL URLWithString:string] WithCompletionHandler:^(NSString *string) {
                if (string){
                    [self uploadDocWithParams:requestParams toVKWallWithCompletionHandler:^(NSString *string) {
                        if (string){
                            [self postToVKWallWithText:status attachID:string withCompletionHandler:^(NSString *string) {
                                if (string){
                                    NSLog(@"%@",string);
                                    _requestCompletion(nil);
                                }else{
                                    _requestCompletion([self requestError]);
                                    return;
                                }
                            }];
                        }else{
                            _requestCompletion([self requestError]);
                            return;
                        }
                    }];
                }else{
                    _requestCompletion([self requestError]);
                    return;
                }
            }];
        }else{
            _requestCompletion([self requestError]);
            return;
        }
    }];
}

#pragma mark Login

- (void)loginWithCompletionHandler:(void (^)(NSError* error))completionBlock {
    _loginCompletion = completionBlock;
    
    if ([[UIApplication sharedApplication] isIgnoringInteractionEvents]){
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    }
    
    VKUser *me = [VKUser me];
    
    if ([me accessToken] && ([me tokenExpirationTime] > [[NSDate date] timeIntervalSince1970])){
        _loginCompletion(nil);
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            
            modalWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
            modalWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            modalWindow.opaque = NO;
            
            modalViewController = [[UIViewController alloc] init];
            modalWindow.rootViewController = modalViewController;
            
            if (nil == modalWebView) {
                CGRect frame = [[UIScreen mainScreen] bounds];
                modalWebView = [[UIWebView alloc] initWithFrame:frame];
                [modalWebView setDelegate:self];
                
                CGPoint centerPoint = [modalWebView center];
                CGRect activityIndicatorFrame = CGRectMake(centerPoint.x - 15, centerPoint.y - 15, 30, 30);
                
                if (nil == modalActivity) {
                    modalActivity = [[UIActivityIndicatorView alloc]
                                          initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
                    [modalActivity setColor:[UIColor darkGrayColor]];
                    [modalActivity setFrame:activityIndicatorFrame];
                    [modalActivity setHidesWhenStopped:YES];
                    [modalActivity startAnimating];
                }
            }
            
            NSDictionary *params = @{@"client_id"     : self.vkAppID,
                                     @"redirect_uri"  : kVKRedirectUrl,
                                     @"scope"         : self.vkPermissions,
                                     @"response_type" : @"token",
                                     @"display"       : @"touch"};
            
            NSMutableString *urlAsString = [[NSMutableString alloc] init];
            NSMutableArray *urlParams = [[NSMutableArray alloc] init];
            
            [urlAsString appendString:@"https://oauth.vk.com/authorize?"];
            [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)
             {
                 [urlParams addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
             }];
            [urlAsString appendString:[urlParams componentsJoinedByString:@"&"]];
            
            NSURL *url = [NSURL URLWithString:urlAsString];
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            
            [modalWebView loadRequest:request];
            modalViewController.view = modalWebView;
            
        });
    }
    
}

- (void)hideModalView {
    [modalWebView removeFromSuperview];
    [[[[UIApplication sharedApplication] delegate] window] makeKeyWindow];
    [modalWindow removeFromSuperview];
    modalViewController = nil;
    modalWindow = nil;
    modalActivity = nil;
}

#pragma mark - WebView delegate methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString *url = [[request URL] absoluteString];
    
    if ([url hasPrefix:kVKRedirectUrl]) {
        NSString *queryString = [url componentsSeparatedByString:@"#"][1];
        
        if ([queryString hasPrefix:@"access_token"]) {
            NSArray *parts = [queryString componentsSeparatedByString:@"&"];
            
            NSString *accessToken = [parts[0] componentsSeparatedByString:@"="][1];
            NSTimeInterval expirationTime = [[parts[1] componentsSeparatedByString:@"="][1] doubleValue] + [[NSDate date] timeIntervalSince1970];
            NSString* userID = [parts[2] componentsSeparatedByString:@"="][1];
            
            VKUser *me = [VKUser me];
            
            [me setAccessToken:accessToken];
            [me setUserId:userID];
            [me setTokenExpirationTime:expirationTime];
            
            _loginCompletion(nil);
            [self hideModalView];
        } else {
            _loginCompletion([self requestError]);
            [self hideModalView];
            [self logout];
        }
    }else{
        [modalWindow makeKeyAndVisible];
        [modalWindow setHidden:NO];
    }
    
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [modalActivity stopAnimating];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [modalActivity startAnimating];
}

- (void)logout
{
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    
    for (NSHTTPCookie *cookie in cookies) {
        if (NSNotFound != [cookie.domain rangeOfString:@"vk.com"].location) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage]
             deleteCookie:cookie];
        }
    }
    
    VKUser *me = [VKUser me];
    
    [me setAccessToken:nil];
    [me setUserId:nil];
    [me setTokenExpirationTime:0];
}

#pragma mark Upload data to specified server

- (void)uploadPhoto:(UIImage*)photo toVKServer:(NSURL*)serverUrl WithCompletionHandler:(void (^)(NSString* string))completionBlock {
    _uploadCompletion = completionBlock;
    
    AFHTTPClient *httpClient = [[AFHTTPClient alloc] initWithBaseURL:serverUrl];
    [httpClient setDefaultHeader:@"'Accept'" value:@"application/json"];
    [httpClient registerHTTPOperationClass:[AFJSONRequestOperation class]];
    [httpClient setParameterEncoding:AFJSONParameterEncoding];
    [AFJSONRequestOperation addAcceptableContentTypes:[NSSet setWithObjects:@"text/html",@"text/plain",nil]];
    
    NSData *imageData = UIImageJPEGRepresentation(photo, 0.5);
        
    NSMutableURLRequest *request = [httpClient multipartFormRequestWithMethod:@"POST" path:@"" parameters:nil constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
        [formData appendPartWithFileData:imageData name:@"photo" fileName:@"photo.jpg" mimeType:@"image/jpeg"];
    }];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSLog(@"photo %@", [JSON valueForKeyPath:@"photo"]);
        requestParams = [NSDictionary dictionaryWithDictionary:JSON];
        _uploadCompletion(@"success");
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON ){
        _uploadCompletion(nil);
    }];
    
    [operation start];
}

- (void)uploadDocument:(NSData*)doc toVKServer:(NSURL*)serverUrl WithCompletionHandler:(void (^)(NSString* string))completionBlock {
    _uploadCompletion = completionBlock;
    
    AFHTTPClient *httpClient = [[AFHTTPClient alloc] initWithBaseURL:serverUrl];
    [httpClient setDefaultHeader:@"'Accept'" value:@"application/json"];
    [httpClient registerHTTPOperationClass:[AFJSONRequestOperation class]];
    [httpClient setParameterEncoding:AFJSONParameterEncoding];
    [AFJSONRequestOperation addAcceptableContentTypes:[NSSet setWithObjects:@"text/html",@"text/plain",nil]];
    
    NSMutableURLRequest *request = [httpClient multipartFormRequestWithMethod:@"POST" path:@"" parameters:nil constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
        [formData appendPartWithFileData:doc name:@"file" fileName:@"animation.gif" mimeType:@"image/gif"];
    }];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSLog(@"GIF %@", [JSON valueForKeyPath:@"file"]);
        requestParams = [NSDictionary dictionaryWithDictionary:JSON];
        _uploadCompletion(@"success");
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON ){
        _uploadCompletion(nil);
    }];
    
    [operation start];
}

#pragma mark Upload data to VK wall

- (void)uploadPhotoWithParams:(NSDictionary*)params toVKWallWithCompletionHandler:(void (^)(NSString* string))completionBlock {
    _uploadCompletion = completionBlock;

    NSString* urlPrefix = @"https://api.vk.com/method/";
    NSMutableString *fullURL = [NSMutableString string];
    [fullURL appendFormat:@"%@photos.saveWallPhoto",urlPrefix];
    
    if (0 != [params count])
        [fullURL appendString:@"?"];
    
    NSMutableArray *paramsArray = [NSMutableArray array];
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)
     {
         NSString *param = [NSString stringWithFormat:@"%@=%@",
                            [[key description]
                             lowercaseString],
                            [[obj description]
                             encodedURLParameterString]];
         
         [paramsArray addObject:param];
     }];
    
    [paramsArray sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    [fullURL appendString:[paramsArray componentsJoinedByString:@"&"]];
    [fullURL appendString:[NSString stringWithFormat:@"&access_token=%@",[VKUser me].accessToken]];
    
    NSURL *url = [NSURL URLWithString:fullURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSLog(@"PHOTO %@",JSON);
        _uploadCompletion([[[JSON objectForKey:@"response"] objectAtIndex:0] objectForKey:@"id"]);
        requestParams = [NSDictionary dictionaryWithDictionary:JSON];
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON ){
        _uploadCompletion(nil);
    }];
    
    [operation start];
}

- (void)uploadDocWithParams:(NSDictionary*)params toVKWallWithCompletionHandler:(void (^)(NSString* string))completionBlock {
    _uploadCompletion = completionBlock;
    
    NSString* urlPrefix = @"https://api.vk.com/method/";
    NSMutableString *fullURL = [NSMutableString string];
    [fullURL appendFormat:@"%@docs.save",urlPrefix];
    
    if (0 != [params count])
        [fullURL appendString:@"?"];
    
    NSMutableArray *paramsArray = [NSMutableArray array];
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)
     {
         NSString *param = [NSString stringWithFormat:@"%@=%@",
                            [[key description]
                             lowercaseString],
                            [[obj description]
                             encodedURLParameterString]];
         
         [paramsArray addObject:param];
     }];
    
    [paramsArray sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    [fullURL appendString:[paramsArray componentsJoinedByString:@"&"]];
    [fullURL appendString:[NSString stringWithFormat:@"&access_token=%@",[VKUser me].accessToken]];
    
    NSURL *url = [NSURL URLWithString:fullURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSLog(@"FILE %@",JSON);
        NSString* ownerId = [[[JSON objectForKey:@"response"] objectAtIndex:0] objectForKey:@"owner_id"];
        NSString* docId = [[[JSON objectForKey:@"response"] objectAtIndex:0] objectForKey:@"did"];
        NSString* completeId = [NSString stringWithFormat:@"doc%@_%@",ownerId,docId];
        _uploadCompletion(completeId);
        requestParams = [NSDictionary dictionaryWithDictionary:JSON];
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON ){
        _uploadCompletion(nil);
    }];
    
    [operation start];
}

#pragma mark Post to VK wall

- (void)postToVKWallWithText:(NSString*)text attachID:(NSString*)attachID withCompletionHandler:(void (^)(NSString* string))completionBlock {
    _uploadCompletion = completionBlock;
    
    NSString* urlPrefix = @"https://api.vk.com/method/";
    NSMutableString *fullURL = [NSMutableString string];
    [fullURL appendFormat:@"%@wall.post",urlPrefix];
    
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:text, @"message", attachID, @"attachments", nil];
    if (0 != [params count])
        [fullURL appendString:@"?"];
    
    NSMutableArray *paramsArray = [NSMutableArray array];
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)
     {
         NSString *param = [NSString stringWithFormat:@"%@=%@",
                            [[key description]
                             lowercaseString],
                            [[obj description]
                             encodedURLParameterString]];
         
         [paramsArray addObject:param];
     }];
    
    [fullURL appendString:[paramsArray componentsJoinedByString:@"&"]];
    [fullURL appendString:[NSString stringWithFormat:@"&access_token=%@",[VKUser me].accessToken]];
    
    NSLog(@"URL %@",fullURL);
    
    NSURL *url = [NSURL URLWithString:fullURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSLog(@"%@",JSON);
        _uploadCompletion(@"success");
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON ){
        _uploadCompletion(nil);
    }];
    
    [operation start];

}

#pragma mark Get adresses of upload servers

- (void)requestAddressForPhotosWallUploadServerWithCompletionHandler:(void (^)(NSString* string))completionBlock {
    _uploadCompletion = completionBlock;
    
    NSString* urlPrefix = @"https://api.vk.com/method/";
    NSMutableString *fullURL = [NSMutableString string];
    [fullURL appendFormat:@"%@photos.getWallUploadServer",urlPrefix];
    
    [fullURL appendString:[NSString stringWithFormat:@"?&access_token=%@",[VKUser me].accessToken]];
    
    NSLog(@"URL %@",fullURL);
    
    NSURL *url = [NSURL URLWithString:fullURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSLog(@"%@",JSON);
        _uploadCompletion(JSON[@"response"][@"upload_url"]);
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON ){
        NSLog(@"%@ %i",JSON, response.statusCode);
        _uploadCompletion(nil);
    }];
    
    [operation start];    
}

- (void)requestAddressForDocsWallUploadServerWithCompletionHandler:(void (^)(NSString* string))completionBlock {
    _uploadCompletion = completionBlock;
    
    NSString* urlPrefix = @"https://api.vk.com/method/";
    NSMutableString *fullURL = [NSMutableString string];
    [fullURL appendFormat:@"%@docs.getWallUploadServer",urlPrefix];
    
    [fullURL appendString:[NSString stringWithFormat:@"?&access_token=%@",[VKUser me].accessToken]];
    
    NSLog(@"URL %@",fullURL);
    
    NSURL *url = [NSURL URLWithString:fullURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSLog(@"%@",JSON);
        _uploadCompletion(JSON[@"response"][@"upload_url"]);
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON ){
        NSLog(@"%@ %i",JSON, response.statusCode);
        _uploadCompletion(nil);
    }];
    
    [operation start];
}

@end
