/*
 * BSD LICENSE
 * Copyright (c) 2015, Mobile Unit of G+J Electronic Media Sales GmbH, Hamburg All rights reserved.
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer .
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import <GoogleMobileAds/GoogleMobileAds.h>
#import "GUJBaseAdViewContext.h"
#import "GUJAdViewContext.h"
#import "GUJAdSpaceIdToAdUnitIdMapper.h"
#import "GUJAdViewContextDelegate.h"


static NSString *const CUSTOM_TARGETING_KEY_POSITION = @"pos";
static NSString *const CUSTOM_TARGETING_KEY_INDEX = @"ind";

@implementation GUJAdView {
    GUJAdViewContext *context;
}


- (void)show {
    super.hidden = NO;
}


- (id)initWithContext:(GUJAdViewContext *)context1 {
    self = [super init];
    context = context1;
    return self;
}


- (void)showInterstitialView {
    [context showInterstitial];
}


- (void)hide {
    super.hidden = YES;
}


- (NSString *)adSpaceId {
    return [[GUJAdSpaceIdToAdUnitIdMapper instance] getAdSpaceIdForAdUnitId:context.adUnitId position:context.position index:context.isIndex];
}

@end


@interface GUJAdViewContext () <GADNativeContentAdLoaderDelegate, GADBannerViewDelegate, GADInterstitialDelegate, GADAppEventDelegate>

@end

@implementation GUJAdViewContext {
    GADAdLoader *adLoader;
    NSString* _contentURL;
    NSString* _publisherProvidedID;

    BOOL allowSmartBannersOnly;
    BOOL mediumRectanglesDisabled;
    BOOL twoToOneAdsDisabled;
    BOOL billboardAdsDisabled;
    BOOL desktopBillboardAdsDisabled;
    BOOL leaderboardAdsDisabled;
    BOOL autoShowInterstitialView;

    adViewCompletion adViewCompletionHandler;
    interstitialAdViewCompletion interstitialAdViewCompletionHandler;

}


+ (GUJAdViewContext *)instanceForAdspaceId:(NSString *)adSpaceId {
    GUJAdViewContext *adViewContext = [[self alloc] init];
    adViewContext.adUnitId = [[GUJAdSpaceIdToAdUnitIdMapper instance] getAdUnitIdForAdSpaceId:adSpaceId];
    adViewContext.position = [[GUJAdSpaceIdToAdUnitIdMapper instance] getPositionForAdSpaceId:adSpaceId];
    NSNumber *isIndex =[[GUJAdSpaceIdToAdUnitIdMapper instance] getIsIndexForAdSpaceId:adSpaceId];
    if (isIndex != nil) {
        adViewContext.isIndex = [isIndex boolValue];
    }
    return adViewContext;
}


+ (GUJAdViewContext *)instanceForAdspaceId:(NSString *)adSpaceId delegate:(id <GUJAdViewContextDelegate>)delegate {
    GUJAdViewContext *adViewContext = [self instanceForAdspaceId:adSpaceId];
    adViewContext.delegate = delegate;
    return adViewContext;
}


+ (GUJAdViewContext *)instanceForAdspaceId:(NSString *)adSpaceId adUnit:(NSString *)adUnitId {
    // ignore adUnitId ... was ad exchange id of format "ca-app-pub-xxxxxxxxxxxxxxxx/nnnnnnnnnn"

    GUJAdViewContext *adViewContext = [self instanceForAdspaceId:adSpaceId];
    return adViewContext;
}


+ (GUJAdViewContext *)instanceForAdspaceId:(NSString *)adSpaceId adUnit:(NSString *)adUnitId delegate:(id <GUJAdViewContextDelegate>)delegate {
    // ignore adUnitId ... was ad exchange id of format "ca-app-pub-xxxxxxxxxxxxxxxx/nnnnnnnnnn" in v2.1.1

    GUJAdViewContext *adViewContext = [self instanceForAdspaceId:adSpaceId delegate:delegate];
    return adViewContext;
}


+ (GUJAdViewContext *)instanceForAdUnitId:(NSString *)adUnitId position:(NSInteger)position rootViewController:(UIViewController *)rootViewController {
    GUJAdViewContext *adViewContext = [[self alloc] init];

    adUnitId = [GUJAdUtils normalizeAdUnitId:adUnitId];
    adViewContext.adUnitId = adUnitId;
    adViewContext.position = position;
    adViewContext.rootViewController = rootViewController;
    return adViewContext;
}


+ (GUJAdViewContext *)instanceForAdUnitId:(NSString *)adUnitId position:(NSInteger)position rootViewController:(UIViewController *)rootViewController delegate:(id <GUJAdViewContextDelegate>)delegate {
    GUJAdViewContext *adViewContext = [self instanceForAdUnitId:adUnitId position:position rootViewController:rootViewController];
    adViewContext.delegate = delegate;
    return adViewContext;
}


+ (GUJAdViewContext *)instanceForAdUnitId:(NSString *)adUnitId rootViewController:(UIViewController *)rootViewController {
    return [self instanceForAdUnitId:adUnitId position:GUJ_AD_VIEW_POSITION_UNDEFINED rootViewController:rootViewController];
}


+ (GUJAdViewContext *)instanceForAdUnitId:(NSString *)adUnitId rootViewController:(UIViewController *)rootViewController delegate:(id <GUJAdViewContextDelegate>)delegate {
    return [self instanceForAdUnitId:adUnitId position:GUJ_AD_VIEW_POSITION_UNDEFINED rootViewController:rootViewController delegate:delegate];
}


- (void)setPosition:(NSInteger)position {
    _position = position;
    if (position != 0) {
        self.customTargetingDict[CUSTOM_TARGETING_KEY_POSITION] = @(position);
    } else {
        [self.customTargetingDict removeObjectForKey:CUSTOM_TARGETING_KEY_POSITION];
    }
}


- (void)setIsIndex:(BOOL)isIndex {
    _isIndex = isIndex;
    if (isIndex) {
        self.customTargetingDict[CUSTOM_TARGETING_KEY_INDEX] = @"YES";
    } else {
        self.customTargetingDict[CUSTOM_TARGETING_KEY_INDEX] = @"NO";
    }
}


-(void)setContentURL:(NSString*) contentURL {
    _contentURL = contentURL;
}


-(void)setPublisherProvidedID:(NSString*) publisherProvidedID {
    _publisherProvidedID = publisherProvidedID;
}


- (BOOL)disableLocationService {
    return [super disableLocationService];
}


- (void)allowSmartBannersOnly {
    allowSmartBannersOnly = YES;
}


- (void)disableMediumRectangleAds {
    mediumRectanglesDisabled = YES;
}


- (void)disableTwoToOneAds {
    twoToOneAdsDisabled = YES;
}


- (void)disableBillboardAds {
    billboardAdsDisabled = YES;
}


- (void)disableDesktopBillboardAds {
    desktopBillboardAdsDisabled = YES;
}


- (void)disableLeaderboardAds {
    leaderboardAdsDisabled = YES;
}


- (void)shouldAutoShowIntestitialView:(BOOL)show {
    [self shouldAutoShowInterstitialView:show];
}


- (void)shouldAutoShowInterstitialView:(BOOL)show {
    autoShowInterstitialView = show;
}


- (DFPRequest *)createRequest {
    DFPRequest *request = [DFPRequest request];
    
    BOOL npaStatus = [GUJAdUtils getNonPersonalizedAds];
    BOOL isChild = [GUJAdUtils getIsChild];
    
    GADExtras *extras = [[GADExtras alloc] init];
    if (isChild) {
        extras.additionalParameters = @{@"tag_for_under_age_of_consent": @YES};
    } else if (npaStatus) {
        extras.additionalParameters = @{@"npa": @"1"};
    }
    
    if (npaStatus || isChild) {
        [request registerAdNetworkExtras:extras];
    }
    
    if (_contentURL != nil) {
        request.contentURL = _contentURL;
    }
    
    if (_publisherProvidedID != nil) {
        request.publisherProvidedID = _publisherProvidedID;
    }
    
    [self updateLocationDataInCustomTargetingDictAndOptionallySetLocationDataOnDfpRequest:request];
    
    request.customTargeting = self.customTargetingDict;
    return request;
}


- (DFPBannerView *)adView {
    return [self adViewWithOrigin:CGPointZero];
}


- (void)adView:(adViewCompletion)completion {
    adViewCompletionHandler = completion;
    [self adView];
}


- (DFPBannerView *)adViewWithOrigin:(CGPoint)origin {

    BOOL isLandscape = UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation);
    self.bannerView = [[DFPBannerView alloc] initWithAdSize:isLandscape ? kGADAdSizeSmartBannerLandscape : kGADAdSizeSmartBannerPortrait origin:origin];

    if (!allowSmartBannersOnly) {

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {  // iPad

            NSMutableArray *validAdSizes = [NSMutableArray new];
            [validAdSizes addObjectsFromArray:@[
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(1, 1))),
                    NSValueFromGADAdSize(kGADAdSizeBanner),  // Typically 320x50.
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(300, 50))),
                    NSValueFromGADAdSize(kGADAdSizeLargeBanner),  // Typically 320x100.
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(300, 100))),
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 75))),
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(300, 75))),
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(180, 150))),
                    NSValueFromGADAdSize(isLandscape ? kGADAdSizeSmartBannerLandscape : kGADAdSizeSmartBannerPortrait),

                    // iq media
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 53))),
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 80))),
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 106)))
            ]];

            if (!mediumRectanglesDisabled) {
                [validAdSizes addObject:NSValueFromGADAdSize(kGADAdSizeMediumRectangle)];  // Typically 300x250.
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 250)))];

                // iq media
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 320)))];
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 416)))];
            }

            if (!twoToOneAdsDisabled) {
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(300, 150)))];
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 150)))];

                // iq media
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 160)))];
            }

            if (!billboardAdsDisabled) {
                [validAdSizes addObject:NSValueFromGADAdSize(isLandscape ? GADAdSizeFromCGSize(CGSizeMake(1024, 220)) : GADAdSizeFromCGSize(CGSizeMake(768, 300)))];
            }

            if (isLandscape && !desktopBillboardAdsDisabled) {
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(800, 250)))];
            }

            if (!leaderboardAdsDisabled) {
                [validAdSizes addObject:NSValueFromGADAdSize(kGADAdSizeLeaderboard)];  // Typically 728x90.
            }

            self.bannerView.validAdSizes = validAdSizes;

        } else {  //iPhone, iPod

            NSMutableArray *validAdSizes = [NSMutableArray new];

            [validAdSizes addObjectsFromArray:@[
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(1, 1))),
                    NSValueFromGADAdSize(kGADAdSizeBanner), // Typically 320x50.
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(300, 50))),
                    NSValueFromGADAdSize(kGADAdSizeLargeBanner), // Typically 320x100.
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(300, 100))),
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(300, 75))),
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 75))),
                    NSValueFromGADAdSize(isLandscape ? kGADAdSizeSmartBannerLandscape : kGADAdSizeSmartBannerPortrait),

                    // iq media
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 53))),
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 80))),
                    NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 106)))
            ]];

            if (!mediumRectanglesDisabled) {
                [validAdSizes addObject:NSValueFromGADAdSize(kGADAdSizeMediumRectangle)];  // Typically 300x250.
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 250)))];

                // iq media
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 320)))];
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 416)))];
            }

            if (!twoToOneAdsDisabled) {
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(300, 150)))];
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 150)))];

                // iq media
                [validAdSizes addObject:NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSizeMake(320, 160)))];
            }

            self.bannerView.validAdSizes = validAdSizes;
        }
    }

    self.bannerView.adUnitID = self.adUnitId;
    self.bannerView.rootViewController = self.rootViewController;
    self.bannerView.delegate = self;
    self.bannerView.appEventDelegate = self;
    
    DFPRequest *request = [self createRequest];

    if ([self.delegate respondsToSelector:@selector(bannerViewInitialized:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate bannerViewInitialized:(id) self.bannerView];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(bannerViewInitializedForContext:)]) {
        [self.delegate bannerViewInitializedForContext:self];
    }

    if ([self.delegate respondsToSelector:@selector(bannerViewWillLoadAdData:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate bannerViewWillLoadAdData:(id) self.bannerView];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(bannerViewWillLoadAdDataForContext:)]) {
        [self.delegate bannerViewWillLoadAdDataForContext:self];
    }
    [self.bannerView loadRequest:request];
    
    return self.bannerView;
}

- (void)adViewWithOrigin:(CGPoint)origin completion:(adViewCompletion)completion {
    adViewCompletionHandler = completion;
    [self adViewWithOrigin:origin];
}


- (DFPBannerView *)adViewForKeywords:(NSArray *)keywords {
    self.customTargetingDict[KEYWORDS_DICT_KEY] = keywords;
    return [self adView];
}


- (void)adViewForKeywords:(NSArray *)keywords completion:(adViewCompletion)completion {
    adViewCompletionHandler = completion;
    [self adViewForKeywords:keywords];
}


- (DFPBannerView *)adViewForKeywords:(NSArray *)keywords origin:(CGPoint)origin {
    self.customTargetingDict[KEYWORDS_DICT_KEY] = keywords;
    return [self adViewWithOrigin:origin];
}


- (void)adViewForKeywords:(NSArray *)keywords origin:(CGPoint)origin completion:(adViewCompletion)completion {
    adViewCompletionHandler = completion;
    [self adViewForKeywords:keywords origin:origin];
}


- (DFPInterstitial *)interstitialAdView {
    self.interstitial = [[DFPInterstitial alloc] initWithAdUnitID:self.adUnitId];
    self.interstitial.delegate = self;
    DFPRequest *request = [self createRequest];

    if ([self.delegate respondsToSelector:@selector(interstitialViewInitialized:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate interstitialViewInitialized:[[GUJAdView alloc] initWithContext:self]];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(interstitialViewInitializedForContext:)]) {
        [self.delegate interstitialViewInitializedForContext:self];
    }

    if ([self.delegate respondsToSelector:@selector(interstitialViewWillLoadAdData:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate interstitialViewWillLoadAdData:[[GUJAdView alloc] initWithContext:self]];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(interstitialViewWillLoadAdDataForContext:)]) {
        [self.delegate interstitialViewWillLoadAdDataForContext:self];
    }

    [self.interstitial loadRequest:request];

    return self.interstitial;
}


- (void)interstitialAdViewWithCompletionHandler:(interstitialAdViewCompletion)completion {
    interstitialAdViewCompletionHandler = completion;
    [self interstitialAdView];
}


- (DFPInterstitial *)interstitialAdViewForKeywords:(NSArray *)keywords {
    self.customTargetingDict[KEYWORDS_DICT_KEY] = keywords;
    return [self interstitialAdView];
}


- (void)interstitialAdViewForKeywords:(NSArray *)keywords completion:(interstitialAdViewCompletion)completion {
    self.customTargetingDict[KEYWORDS_DICT_KEY] = keywords;
    [self interstitialAdViewWithCompletionHandler:interstitialAdViewCompletionHandler];
}


- (void)showInterstitial {
    if (self.interstitial.isReady) {
        [self.interstitial presentFromRootViewController:self.rootViewController];
        if ([self.delegate respondsToSelector:@selector(interstitialViewDidAppear)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [self.delegate interstitialViewDidAppear];
#pragma clang diagnostic pop
        }
        if ([self.delegate respondsToSelector:@selector(interstitialViewDidAppearForContext:)]) {
            [self.delegate interstitialViewDidAppearForContext:self];
        }
    }
}


- (void)addCustomTargetingKeyword:(NSString *)keyword {
    [super addCustomTargetingKeyword:keyword];
}


- (void)addCustomTargetingKey:(NSString *)key Value:(NSString *)value {
    NSAssert(![key isEqualToString:CUSTOM_TARGETING_KEY_POSITION], @"Set the position (pos) via position property.");
    NSAssert(![key isEqualToString:CUSTOM_TARGETING_KEY_INDEX], @"Set the isIndex (ind) via isIndex property.");
    [super addCustomTargetingKey:key Value:value];
}


- (void)freeInstance {
    self.bannerView.delegate = nil;
    self.interstitial.delegate = nil;
    adLoader.delegate = nil;
}


- (void)loadNativeContentAd {
    adLoader = [[GADAdLoader alloc]
            initWithAdUnitID:self.adUnitId
          rootViewController:self.rootViewController
                     adTypes:@[kGADAdLoaderAdTypeNativeContent]
                     options:@[]];
    adLoader.delegate = self;

    DFPRequest *request = [self createRequest];
    [adLoader loadRequest:request];

}


- (void)loadNativeContentAdForKeywords:(NSArray *)keywords {
    self.customTargetingDict[KEYWORDS_DICT_KEY] = keywords;
    [self loadNativeContentAd];
}


# pragma mark - GADAdLoaderDelegate

- (void)adLoader:(GADAdLoader *)adLoader1 didFailToReceiveAdWithError:(GADRequestError *)error {
    if ([self.delegate respondsToSelector:@selector(nativeContentAdLoaderDidFailLoadingAdWithError:ForContext:)]) {
        [self.delegate nativeContentAdLoaderDidFailLoadingAdWithError:error ForContext:self];
    }
}


#pragma mark - GADNativeContentAdLoaderDelegate

- (void)adLoader:(GADAdLoader *)adLoader1 didReceiveNativeContentAd:(GADNativeContentAd *)nativeContentAd {
    self.nativeContentAd = nativeContentAd;
    if ([self.delegate respondsToSelector:@selector(nativeContentAdLoaderDidLoadDataForContext:)]) {
        [self.delegate nativeContentAdLoaderDidLoadDataForContext:self];
    }
}


#pragma mark - GADBannerViewDelegate

- (void)adViewDidReceiveAd:(GADBannerView *)bannerView {
    BOOL completionHandlerAllowsToShowBanner = YES;
    if (adViewCompletionHandler != nil) {
        completionHandlerAllowsToShowBanner = adViewCompletionHandler((DFPBannerView *) bannerView, nil);
    }

    bannerView.hidden = !completionHandlerAllowsToShowBanner;

    if ([self.delegate respondsToSelector:@selector(bannerViewDidLoadAdData:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate bannerViewDidLoadAdData:(GUJAdView *) bannerView];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(bannerViewDidLoadAdDataForContext:)]) {
        [self.delegate bannerViewDidLoadAdDataForContext:self];
    }
}


- (void)adView:(GADBannerView *)bannerView didFailToReceiveAdWithError:(GADRequestError *)error {
    BOOL completionHandlerAllowsToShowBanner = YES;
    if (adViewCompletionHandler != nil) {
        completionHandlerAllowsToShowBanner = adViewCompletionHandler((DFPBannerView *) bannerView, error);
    }

    bannerView.hidden = !completionHandlerAllowsToShowBanner;

    if ([self.delegate respondsToSelector:@selector(bannerView:didFailLoadingAdWithError:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate bannerView:(GUJAdView *) bannerView didFailLoadingAdWithError:error];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(bannerViewDidFailLoadingAdWithError:ForContext:)]) {
        [self.delegate bannerViewDidFailLoadingAdWithError:error ForContext:self];
    }
}


- (void)adViewWillPresentScreen:(GADBannerView *)bannerView {
    if ([self.delegate respondsToSelector:@selector(bannerViewWillPresentScreenForContext:)]) {
        [self.delegate bannerViewWillPresentScreenForContext:self];
    }
}


- (void)adViewWillDismissScreen:(GADBannerView *)bannerView {
    if ([self.delegate respondsToSelector:@selector(bannerViewWillDismissScreenForContext:)]) {
        [self.delegate bannerViewWillDismissScreenForContext:self];
    }
}


- (void)adViewDidDismissScreen:(GADBannerView *)bannerView {
    if ([self.delegate respondsToSelector:@selector(bannerViewDidDismissScreenForContext:)]) {
        [self.delegate bannerViewDidDismissScreenForContext:self];
    }
}


- (void)adViewWillLeaveApplication:(GADBannerView *)bannerView {
    if ([self.delegate respondsToSelector:@selector(bannerViewWillLeaveApplicationForContext:)]) {
        [self.delegate bannerViewWillLeaveApplicationForContext:self];
    }
}

- (void)adView:(GADBannerView *)banner didReceiveAppEvent:(NSString *)name
      withInfo:(NSString *GAD_NULLABLE_TYPE)info {
    if ([self.delegate respondsToSelector:@selector(bannerViewDidRecieveEventForContext:eventName:withInfo:)]) {
        [self.delegate bannerViewDidRecieveEventForContext:self eventName:name withInfo:info];
    }
}


#pragma mark - GADInterstitialDelegate

- (void)interstitialDidReceiveAd:(GADInterstitial *)ad {
    BOOL completionHandlerAllowsToShowInterstitial = NO;
    if (interstitialAdViewCompletionHandler != nil) {
        completionHandlerAllowsToShowInterstitial = interstitialAdViewCompletionHandler(ad, nil);
    }

    if (autoShowInterstitialView || completionHandlerAllowsToShowInterstitial) {
        [self showInterstitial];
    }

    if ([self.delegate respondsToSelector:@selector(interstitialViewDidLoadAdData:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate interstitialViewDidLoadAdData:[[GUJAdView alloc] initWithContext:self]];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(interstitialViewDidLoadAdDataForContext:)]) {
        [self.delegate interstitialViewDidLoadAdDataForContext:self];
    }
}


- (void)interstitial:(GADInterstitial *)ad didFailToReceiveAdWithError:(GADRequestError *)error {
    if (interstitialAdViewCompletionHandler != nil) {
        interstitialAdViewCompletionHandler(ad, error);
    }
    if ([self.delegate respondsToSelector:@selector(interstitialView:didFailLoadingAdWithError:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate interstitialView:[[GUJAdView alloc] initWithContext:self] didFailLoadingAdWithError:error];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(interstitialViewDidFailLoadingAdWithError:ForContext:)]) {
        [self.delegate interstitialViewDidFailLoadingAdWithError:error ForContext:self];
    }
}


- (void)interstitialWillPresentScreen:(GADInterstitial *)ad {
    if ([self.delegate respondsToSelector:@selector(interstitialViewWillAppear)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate interstitialViewWillAppear];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(interstitialViewWillAppearForContext:)]) {
        [self.delegate interstitialViewWillAppearForContext:self];
    }
}


- (void)interstitialWillDismissScreen:(GADInterstitial *)ad {
    if ([self.delegate respondsToSelector:@selector(interstitialViewWillDisappear)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate interstitialViewWillDisappear];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(interstitialViewWillDisappearForContext:)]) {
        [self.delegate interstitialViewWillDisappearForContext:self];
    }
}


- (void)interstitialDidDismissScreen:(GADInterstitial *)ad {
    if ([self.delegate respondsToSelector:@selector(interstitialViewDidDisappear)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate interstitialViewDidDisappear];
#pragma clang diagnostic pop
    }
    if ([self.delegate respondsToSelector:@selector(interstitialViewDidDisappearForContext:)]) {
        [self.delegate interstitialViewDidDisappearForContext:self];
    }
}

@end
