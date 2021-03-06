/*
 * BSD LICENSE
 * Copyright (c) 2016, Mobile Unit of G+J Electronic Media Sales GmbH, Hamburg All rights reserved.
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


#import "GUJInflowAdViewContext.h"

typedef NS_ENUM(NSInteger, GUJInflowAdType) {
    GUJInflowAdTypeNone,
    GUJInflowAdTypeIMA
};

@interface GUJInflowAdViewContext ()

@property (nonatomic) GUJInflowAdType adType;

@end

@implementation GUJInflowAdViewContext {
    id <UIScrollViewDelegate> originalScrollViewDelegate;
    BOOL adViewExpanded, adViewExpanding, adStarted, wasClosedByUser, pausedAtTheEnd;
    IMAAdsLoader *_adsLoader;
    IMAAdsManager *_adsManager;

    AVPlayer *avPlayer;

    UIButton *unmuteButton;

    UIView *coverView;
    UIButton *closeButton;
    UIButton *replayButton;

    NSString *originalAudioSessionCategory;
    
    BOOL isAdLoaded;
}


- (instancetype)     initWithScrollView:(UIScrollView *)scrollView
                inFlowAdPlaceholderView:(UIView *)inFlowAdPlaceholderView
inFlowAdPlaceholderViewHeightConstraint:(NSLayoutConstraint *)inFlowAdPlaceholderViewHeightConstraint
                            dfpAdunitId:(NSString *)dfpAdunitId {
    
    return [self initWithScrollView:scrollView inFlowAdPlaceholderView:inFlowAdPlaceholderView inFlowAdPlaceholderViewHeightConstraint:inFlowAdPlaceholderViewHeightConstraint dfpAdunitId:dfpAdunitId smartClipUrl:nil];
}

- (instancetype)     initWithScrollView:(UIScrollView *)scrollView
                inFlowAdPlaceholderView:(UIView *)inFlowAdPlaceholderView
inFlowAdPlaceholderViewHeightConstraint:(NSLayoutConstraint *)inFlowAdPlaceholderViewHeightConstraint
                            dfpAdunitId:(NSString *)dfpAdunitId
                           smartClipUrl:(NSString *)smartClipUrl {
    self = [super init];
    if (self) {
        self.scrollView = scrollView;
        
        
        
        self.inFlowAdPlaceholderView = inFlowAdPlaceholderView;
        self.inFlowAdPlaceholderViewHeightConstraint = inFlowAdPlaceholderViewHeightConstraint;
        
        self.inFlowAdPlaceholderView.clipsToBounds = YES;
        
        self.dfpAdunitId = dfpAdunitId;
        
        _adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
        _adsLoader.delegate = self;
        
        [self requestAds];
        
        originalAudioSessionCategory = [AVAudioSession sharedInstance].category;
        [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryAmbient error:nil];
    }
    
    return self;
}


- (void) dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[AVAudioSession sharedInstance]setCategory:originalAudioSessionCategory error:nil];
}


- (void)containerViewDidAppear {

    originalScrollViewDelegate = self.scrollView.delegate;
    self.scrollView.delegate = self;

    if (adStarted && !pausedAtTheEnd) {
        [self playAd];
    }
}


- (void)containerViewWillDisappear {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    self.scrollView.delegate = originalScrollViewDelegate;

    if (adStarted) {
        [self pauseAd];
    }
}


- (BOOL)disableLocationService {
    return [super disableLocationService];
}


- (void)checkIfScrolledIntoView {

    CGRect adViewRect = self.inFlowAdPlaceholderView.frame;
    CGRect scrollViewRect = CGRectMake(
            self.scrollView.contentOffset.x,
            self.scrollView.contentOffset.y,
            self.scrollView.frame.size.width,
            self.scrollView.frame.size.height);

    if (isAdLoaded && !adViewExpanded && !wasClosedByUser && CGRectIntersectsRect(adViewRect, scrollViewRect)) {
        //[self expandAdView:YES];
    }

    if (adViewExpanded && adStarted && !pausedAtTheEnd) {
        if (CGRectIntersectsRect(adViewRect, scrollViewRect)) {
            [self playAd];
        } else {
            [self pauseAd];
        }
    }
}


- (void)expandAdView:(BOOL)expand {

    if (expand != adViewExpanded && !adViewExpanding) {
        adViewExpanding = YES;
        
        CGFloat expectedHeight = self.inFlowAdPlaceholderView.frame.size.width / 4 * 3;
        
        self.inFlowAdPlaceholderViewHeightConstraint.constant = expand ? expectedHeight : 0;
        
    
        [UIView animateWithDuration:0.7f delay:0.2f options:UIViewAnimationOptionAllowUserInteraction animations:^{
            [self.inFlowAdPlaceholderView.superview layoutIfNeeded];
        }                completion:^(BOOL finished) {
            if (self->isAdLoaded) {
                [self playAd];
                self->adStarted = YES;
            }
            self->adViewExpanding = NO;
            self->adViewExpanded = expand;
        }];
    }
}


-(void) playAd {
    if (self.adType == GUJInflowAdTypeIMA) {
        [_adsManager resume];
    }
}

-(void) pauseAd {
    if (self.adType == GUJInflowAdTypeIMA) {
        [_adsManager pause];
    }
}


#pragma mark SDK Setup

- (void)requestAds {
    // Create an ad display container for ad rendering.
    IMAAdDisplayContainer *adDisplayContainer =
            [[IMAAdDisplayContainer alloc] initWithAdContainer:self.inFlowAdPlaceholderView companionSlots:nil];

    [self updateLocationDataInCustomTargetingDictAndOptionallySetLocationDataOnDfpRequest:nil];

    NSString *keyValueParameters = @"";
    for (NSString *key in self.customTargetingDict) {

        NSString *escapedKey = [GUJAdUtils urlencode:key];
        NSString *escapedValue = [GUJAdUtils urlencode:self.customTargetingDict[key]];

        keyValueParameters = [keyValueParameters stringByAppendingString:
                [NSString stringWithFormat:@"%@=%@&", escapedKey, escapedValue]];
    }

    keyValueParameters = [GUJAdUtils urlencode:keyValueParameters];

    NSString *adTagUrl =
            [NSString stringWithFormat:@"https://pubads.g.doubleclick.net/gampad/ads?sz=400x300&iu=%@&gdfp_req=1&env=vp&t=%@",
                                       self.dfpAdunitId,
                                       keyValueParameters
            ];
    NSLog(@"Requesting ad from URL: %@", adTagUrl);

    IMAAdsRequest *request = [[IMAAdsRequest alloc] initWithAdTagUrl:adTagUrl
                                                  adDisplayContainer:adDisplayContainer
                                                     contentPlayhead:nil
                                                         userContext:nil];
    [_adsLoader requestAdsWithRequest:request];
}


- (AVPlayer *)discoverAVPlayer {
    if (self.inFlowAdPlaceholderView.subviews.count > 0) {
        UIView /*IMAAdView */ *adView = self.inFlowAdPlaceholderView.subviews[0];
        if (adView.subviews.count > 0) {
            UIView /*IMAAdPlayerView*/ *adPlayerView = adView.subviews[0];
            if ([adPlayerView respondsToSelector:@selector(delegate)]) {
                id /*IMAAVPlayerVideoDisplay */ avPlayerVideoDisplay = [adPlayerView performSelector:@selector(delegate)];
                if ([avPlayerVideoDisplay respondsToSelector:@selector(player)]) {
                    return [avPlayerVideoDisplay performSelector:@selector(player)];
                }
            }
        }
    }
    NSLog(@"AVPlayer not found!");
    return nil;
}


- (void)toggleAudioMuting {
    if (avPlayer.muted) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    } else {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
    }
    avPlayer.muted = !avPlayer.muted;

    unmuteButton.selected = !avPlayer.muted;
}


- (void)close {
    [self expandAdView:NO];
    wasClosedByUser = YES;
}


- (void)replay {
    [coverView removeFromSuperview];
    [replayButton removeFromSuperview];
    [closeButton removeFromSuperview];
    [avPlayer seekToTime:kCMTimeZero];
    [avPlayer play];
    [self addUnmuteButton];
    pausedAtTheEnd = NO;
}


- (UIViewController *)findInFlowAdPlaceholderViewsViewController {
    UIResponder *responder = self.inFlowAdPlaceholderView;
    while (![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
        if (nil == responder) {
            break;
        }
    }
    return (UIViewController *) responder;
}


- (void)addUnmuteButton {
    [unmuteButton removeFromSuperview];
    unmuteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [unmuteButton setImage:[UIImage imageNamed:@"gujemsiossdk.bundle/sound_off_white.png"] forState:UIControlStateNormal];
    [unmuteButton setImage:[UIImage imageNamed:@"gujemsiossdk.bundle/sound_on_white.png"] forState:UIControlStateSelected];
    [unmuteButton addTarget:self
                     action:@selector(toggleAudioMuting)
           forControlEvents:UIControlEventTouchUpInside];
    unmuteButton.frame = CGRectMake((CGFloat) (self.inFlowAdPlaceholderView.frame.size.width - 30.0), (CGFloat) (self.inFlowAdPlaceholderView.frame.size.height - 30.0), 20.0, 20.0);
    [self.inFlowAdPlaceholderView addSubview:unmuteButton];
}


- (void)addCoverView {
    coverView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.inFlowAdPlaceholderView.frame.size.width, self.inFlowAdPlaceholderView.frame.size.height)];
    coverView.contentMode = UIViewContentModeScaleAspectFit;
    coverView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.2];
    coverView.userInteractionEnabled = NO;
    [self.inFlowAdPlaceholderView addSubview:coverView];
}


- (void)addReplayButton {
    replayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [replayButton setImage:[UIImage imageNamed:@"gujemsiossdk.bundle/replay_white.png"] forState:UIControlStateNormal];
    [replayButton addTarget:self
                     action:@selector(replay)
           forControlEvents:UIControlEventTouchUpInside];
    replayButton.frame = CGRectMake((CGFloat) (self.inFlowAdPlaceholderView.frame.size.width / 2 - 30.0), (CGFloat) (self.inFlowAdPlaceholderView.frame.size.height / 2 - 30.0), 60.0, 60.0);
    [self.inFlowAdPlaceholderView addSubview:replayButton];
}


- (void)addCloseButton {
    closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeButton setImage:[UIImage imageNamed:@"gujemsiossdk.bundle/close_white.png"] forState:UIControlStateNormal];
    [closeButton addTarget:self
                    action:@selector(close)
          forControlEvents:UIControlEventTouchUpInside];
    closeButton.frame = CGRectMake((CGFloat) (self.inFlowAdPlaceholderView.frame.size.width - 30.0), (CGFloat) (self.inFlowAdPlaceholderView.frame.size.height - 30.0), 20.0, 20.0);
    [self.inFlowAdPlaceholderView addSubview:closeButton];
}

#pragma mark AdsLoader Delegates

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {

    NSLog(@"adsLoadedWithData");

    _adsManager = adsLoadedData.adsManager;
    _adsManager.delegate = self;

    [_adsManager initializeWithAdsRenderingSettings:nil];

    avPlayer = [self discoverAVPlayer];
    avPlayer.muted = YES;
}


- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
    // Something went wrong loading ads. May be no fill.
    NSLog(@"failedWithErrorData: %@", adErrorData.adError.message);
}


#pragma mark AdsManager Delegate

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdEvent:(IMAAdEvent *)event {
    
    if (event.type == kIMAAdEvent_LOADED) {
        
        self.adType = GUJInflowAdTypeIMA;
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self];  // cancel fallbackRequestAfter2SecondTimeout
        
        isAdLoaded = YES;
        if (adViewExpanded) {
            adStarted = YES;
        } else {
            [self expandAdView:YES];
        }
    }

    if (event.type == kIMAAdEvent_STARTED) {
        if (!adViewExpanded) {
            [self pauseAd];  // pause until view is expanded
        }
        [self addUnmuteButton];
    }

    if (event.type == kIMAAdEvent_RESUME) {
        [self addUnmuteButton];
    }
}

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdError:(IMAAdError *)error {
    // Something went wrong with the ads manager after ads were loaded. Log the error.
    NSLog(@"didReceiveAdError: %@", error.message);
}


- (void)adsManagerDidRequestContentPause:(IMAAdsManager *)adsManager {
    // ignored because we don't have an underlying video
}


- (void)adsManagerDidRequestContentResume:(IMAAdsManager *)adsManager {
    // ignored because we don't have an underlying video
}


- (void) adsManager:(IMAAdsManager *)adsManager
adDidProgressToTime:(NSTimeInterval)mediaTime
          totalTime:(NSTimeInterval)totalTime {
    // called every 200ms

    if (!pausedAtTheEnd && totalTime - mediaTime <= .200) {
        [avPlayer pause];
        pausedAtTheEnd = YES;

        [unmuteButton removeFromSuperview];

        [self addCoverView];
        [self addCloseButton];
        [self addReplayButton];
    }

}


# pragma mark - UIScrollViewDelegate

// we are only interested in the scrollViewDidScroll: event,
// original delegate methods shall always be called!

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self checkIfScrolledIntoView];
    [originalScrollViewDelegate scrollViewDidScroll:scrollView];
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewDidZoom:scrollView];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewWillBeginDragging:scrollView];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    [originalScrollViewDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [originalScrollViewDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewWillBeginDecelerating:scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewDidEndDecelerating:scrollView];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewDidEndScrollingAnimation:scrollView];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return [originalScrollViewDelegate viewForZoomingInScrollView:scrollView];;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    [originalScrollViewDelegate scrollViewWillBeginZooming:scrollView withView:view];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    [originalScrollViewDelegate scrollViewDidEndZooming:scrollView withView:view atScale:scale];
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    return [originalScrollViewDelegate scrollViewShouldScrollToTop:scrollView];;
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewDidScrollToTop:scrollView];
}

@end
