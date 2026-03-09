//
//  UIImageView+WK.m
//  WuKongBase
//
//  Created by tt on 2021/10/14.
//

#import "UIImageView+WK.h"
#import <SDWebImage/SDWebImage.h>
#import <AFNetworking/AFNetworking.h>
@implementation UIImageView (WK)

- (void)lim_setImageWithURL:(NSURL *)url {
    [self sd_setImageWithURL:url placeholderImage:nil options:SDWebImageAllowInvalidSSLCertificates progress:nil completed:nil];
}

- (void)lim_setImageWithURL:(NSURL *)url completed:(SDExternalCompletionBlock)completed{
    [self sd_setImageWithURL:url placeholderImage:nil options:SDWebImageAllowInvalidSSLCertificates progress:nil completed:completed];
}

- (void)lim_setImageWithURL:(NSURL *)url context:(SDWebImageContext*)context completed:(SDExternalCompletionBlock)completed{
    [self sd_setImageWithURL:url placeholderImage:nil options:SDWebImageAllowInvalidSSLCertificates context:context progress:nil completed:completed];
}

- (void)lim_setImageWithURL:(NSURL *)url context:(SDWebImageContext*)context {
    [self sd_setImageWithURL:url placeholderImage:nil options:SDWebImageAllowInvalidSSLCertificates context:context];
}

- (void)lim_setImageWithURL:(NSURL *)url options:( SDWebImageOptions)options context:(SDWebImageContext*)context completed:(SDExternalCompletionBlock)completed {
    [self sd_setImageWithURL:url placeholderImage:nil options:SDWebImageAllowInvalidSSLCertificates | options context:context progress:nil completed:completed];
}


- (void)lim_setImageWithURL:(NSURL *)url placeholderImage:(UIImage*)placeholderImage {
    
    [self sd_setImageWithURL:url placeholderImage:placeholderImage options:SDWebImageAllowInvalidSSLCertificates];
}

- (void)lim_setImageWithURL:(NSURL *)url placeholderImage:(UIImage*)placeholderImage options:(SDWebImageOptions)options context:(SDWebImageContext*)context{
    [self sd_setImageWithURL:url placeholderImage:placeholderImage options:options | SDWebImageAllowInvalidSSLCertificates context:context];
}



@end
