//
// Copyright 2016 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "Additions/UIScrollView+GREYAdditions.h"

#import <objc/message.h>
#import <objc/runtime.h>

#import "Common/GREYExposed.h"
#import "Common/GREYSwizzler.h"
#import "Synchronization/GREYAppStateTracker.h"

static void const *const kStateTrackerElementIDKey = &kStateTrackerElementIDKey;

@implementation UIScrollView (GREYAdditions)

+ (void)load {
  @autoreleasepool {
    GREYSwizzler *swizzler = [[GREYSwizzler alloc] init];

    SEL originalSel = @selector(_scrollViewWillBeginDragging);
    SEL swizzledSel = @selector(greyswizzled_scrollViewWillBeginDragging);
    BOOL swizzled = [swizzler swizzleClass:[UIScrollView class]
                     replaceInstanceMethod:originalSel
                                withMethod:swizzledSel];
    NSAssert(swizzled, @"Cannot swizzle [UIScrollView _scrollViewWillBeginDragging]");

    originalSel = @selector(_scrollViewDidEndDraggingWithDeceleration:);
    swizzledSel = @selector(greyswizzled_scrollViewDidEndDraggingWithDeceleration:);
    swizzled = [swizzler swizzleClass:[UIScrollView class]
                replaceInstanceMethod:originalSel
                           withMethod:swizzledSel];
    NSAssert(swizzled, @"Cannot swizzle [UIScrollView _scrollViewDidEndDraggingWithDeceleration:]");

    originalSel = @selector(_stopScrollDecelerationNotify:);
    swizzledSel = @selector(greyswizzled_stopScrollDecelerationNotify:);
    swizzled = [swizzler swizzleClass:[UIScrollView class]
                replaceInstanceMethod:originalSel
                           withMethod:swizzledSel];
    NSAssert(swizzled, @"Cannot swizzle [UIScrollView _stopScrollDecelerationNotify:]");
  }
}

- (BOOL)grey_hasScrollResistance {
  if (self.bounces) {
    return ((BOOL (*)(id, SEL))objc_msgSend)(self, NSSelectorFromString(@"_isBouncing"));
  } else {
    // NOTE that these values are not reliable as scroll views without bounce have non-zero
    // velocities even when they are at the edge of the content and cannot be scrolled.
    double horizontalVelocity =
    ((double (*)(id, SEL))objc_msgSend)(self, NSSelectorFromString(@"_horizontalVelocity"));
    double verticalVelocity =
    ((double (*)(id, SEL))objc_msgSend)(self, NSSelectorFromString(@"_verticalVelocity"));
    return horizontalVelocity == 0 && verticalVelocity == 0;
  }
}

#pragma mark - Swizzled Implementation

- (void)greyswizzled_scrollViewWillBeginDragging {
  NSString *elementID = TRACK_STATE_FOR_ELEMENT(kGREYPendingUIScrollViewScrolling, self);
  objc_setAssociatedObject(self,
                           kStateTrackerElementIDKey,
                           elementID,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  INVOKE_ORIGINAL_IMP(void, @selector(greyswizzled_scrollViewWillBeginDragging));
}

- (void)greyswizzled_scrollViewDidEndDraggingWithDeceleration:(BOOL)deceleration {
  if (!deceleration) {
    NSString *elementID = objc_getAssociatedObject(self, kStateTrackerElementIDKey);
    UNTRACK_STATE_FOR_ELEMENT_WITH_ID(kGREYPendingUIScrollViewScrolling, elementID);
  }
  INVOKE_ORIGINAL_IMP1(void,
                       @selector(greyswizzled_scrollViewDidEndDraggingWithDeceleration:),
                       deceleration);
}

- (void)greyswizzled_stopScrollDecelerationNotify:(BOOL)notify {
  NSString *elementID = objc_getAssociatedObject(self, kStateTrackerElementIDKey);
  UNTRACK_STATE_FOR_ELEMENT_WITH_ID(kGREYPendingUIScrollViewScrolling, elementID);
  INVOKE_ORIGINAL_IMP1(void, @selector(greyswizzled_stopScrollDecelerationNotify:), notify);
}

@end