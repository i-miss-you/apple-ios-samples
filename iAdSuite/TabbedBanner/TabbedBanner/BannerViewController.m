/*
    File: BannerViewController.m
Abstract: A container view controller that manages an ADBannerView and a content view controller
 Version: 2.2

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2013 Apple Inc. All Rights Reserved.

*/

#import "BannerViewController.h"

NSString * const BannerViewActionWillBegin = @"BannerViewActionWillBegin";
NSString * const BannerViewActionDidFinish = @"BannerViewActionDidFinish";

@interface BannerViewController ()

// This method is used by BannerViewSingletonController to inform instances of BannerViewController that the banner has loaded/unloaded.
- (void)updateLayout;

@end

@interface BannerViewManager : NSObject <ADBannerViewDelegate>

@property (nonatomic, readonly) ADBannerView *bannerView;

+ (BannerViewManager *)sharedInstance;

- (void)addBannerViewController:(BannerViewController *)controller;
- (void)removeBannerViewController:(BannerViewController *)controller;

@end

@implementation BannerViewController {
    UIViewController *_contentController;
}

- (instancetype)initWithContentViewController:(UIViewController *)contentController
{
    // If contentController is nil, -loadView is going to throw an exception when it attempts to setup
    // containment of a nil view controller.  Instead, throw the exception here and make it obvious
    // what is wrong.
    NSAssert(contentController != nil, @"Attempting to initialize a BannerViewController with a nil contentController.");
    
    self = [super init];
    if (self != nil) {
        _contentController = contentController;
        [[BannerViewManager sharedInstance] addBannerViewController:self];
    }
    return self;
}

- (void)dealloc
{
    [[BannerViewManager sharedInstance] removeBannerViewController:self];
}

- (void)loadView
{
    UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Setup containment of the _contentController.
    [self addChildViewController:_contentController];
    [contentView addSubview:_contentController.view];
    [_contentController didMoveToParentViewController:self];
    
    self.view = contentView;
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [_contentController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}
#endif

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return [_contentController preferredInterfaceOrientationForPresentation];
}

- (NSUInteger)supportedInterfaceOrientations
{
    return [_contentController supportedInterfaceOrientations];
}

- (void)viewDidLayoutSubviews
{
    CGRect contentFrame = self.view.bounds, bannerFrame = CGRectZero;
    ADBannerView *bannerView = [BannerViewManager sharedInstance].bannerView;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0
    NSString *contentSizeIdentifier;
    // If configured to support iOS <6.0, then we need to set the currentContentSizeIdentifier in order to resize the banner properly.
    // This continues to work on iOS 6.0, so we won't need to do anything further to resize the banner.
    if (contentFrame.size.width < contentFrame.size.height) {
        contentSizeIdentifier = ADBannerContentSizeIdentifierPortrait;
    } else {
        contentSizeIdentifier = ADBannerContentSizeIdentifierLandscape;
    }
    bannerFrame.size = [ADBannerView sizeFromBannerContentSizeIdentifier:contentSizeIdentifier];
#else
    // If configured to support iOS >= 6.0 only, then we want to avoid currentContentSizeIdentifier as it is deprecated.
    // Fortunately all we need to do is ask the banner for a size that fits into the layout area we are using.
    // At this point in this method contentFrame=self.view.bounds, so we'll use that size for the layout.
    bannerFrame.size = [_bannerView sizeThatFits:contentFrame.size];
#endif
    
    if (bannerView.bannerLoaded) {
        contentFrame.size.height -= bannerFrame.size.height;
        bannerFrame.origin.y = contentFrame.size.height;
    } else {
        bannerFrame.origin.y = contentFrame.size.height;
    }
    _contentController.view.frame = contentFrame;
    // We only want to modify the banner view itself if this view controller is actually visible to the user.
    // This prevents us from modifying it while it is being displayed elsewhere.
    if (self.isViewLoaded && (self.view.window != nil)) {
        [self.view addSubview:bannerView];
        bannerView.frame = bannerFrame;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0
        bannerView.currentContentSizeIdentifier = contentSizeIdentifier;
#endif
    }
}

- (void)updateLayout
{
    [UIView animateWithDuration:0.25 animations:^{
        // -viewDidLayoutSubviews will handle positioning the banner such that it is either visible
        // or hidden depending upon whether its bannerLoaded property is YES or NO.  We just need our view
        // to (re)lay itself out so -viewDidLayoutSubviews will be called.
        // You must not call [self.view layoutSubviews] directly.  However, you can flag the view
        // as requiring layout...
        [self.view setNeedsLayout];
        // ...then ask it to lay itself out immediately if it is flagged as requiring layout...
        [self.view layoutIfNeeded];
        // ...which has the same effect.
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.view addSubview:[BannerViewManager sharedInstance].bannerView];
}

- (NSString *)title
{
    return _contentController.title;
}

@end

@implementation BannerViewManager {
    ADBannerView *_bannerView;
    NSMutableSet *_bannerViewControllers;
}

+ (BannerViewManager *)sharedInstance
{
    static BannerViewManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[BannerViewManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        // On iOS 6 ADBannerView introduces a new initializer, use it when available.
        if ([ADBannerView instancesRespondToSelector:@selector(initWithAdType:)]) {
            _bannerView = [[ADBannerView alloc] initWithAdType:ADAdTypeBanner];
        } else {
            _bannerView = [[ADBannerView alloc] init];
        }
        _bannerView.delegate = self;
        _bannerViewControllers = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)addBannerViewController:(BannerViewController *)controller
{
    [_bannerViewControllers addObject:controller];
}

- (void)removeBannerViewController:(BannerViewController *)controller
{
    [_bannerViewControllers removeObject:controller];
}

- (void)bannerViewDidLoadAd:(ADBannerView *)banner
{
    for (BannerViewController *bvc in _bannerViewControllers) {
        [bvc updateLayout];
    }
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
    for (BannerViewController *bvc in _bannerViewControllers) {
        [bvc updateLayout];
    }
}

- (BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave
{
    [[NSNotificationCenter defaultCenter] postNotificationName:BannerViewActionWillBegin object:self];
    return YES;
}

- (void)bannerViewActionDidFinish:(ADBannerView *)banner
{
    [[NSNotificationCenter defaultCenter] postNotificationName:BannerViewActionDidFinish object:self];
}


@end
