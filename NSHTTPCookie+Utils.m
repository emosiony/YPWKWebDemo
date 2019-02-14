//
//  NSHTTPCookie+Utils.m
//  OpenGLDemo01
//
//  Created by Jtg_yao on 2019/2/14.
//  Copyright © 2019年 rocHome. All rights reserved.
//

#import "NSHTTPCookie+Utils.h"

@implementation NSHTTPCookie (Utils)

- (NSString *)da_javascriptString
{
    NSString *string = [NSString stringWithFormat:@"%@=%@;domain=%@;path=%@",
                        self.name,
                        self.value,
                        self.domain,
                        self.path ?: @"/"];
    if (self.secure) {
        string = [string stringByAppendingString:@";secure=true"];
    }
    return string;
}

@end
