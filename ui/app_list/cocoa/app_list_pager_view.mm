// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ui/app_list/cocoa/app_list_pager_view.h"

#include "base/mac/mac_util.h"
#include "skia/ext/skia_utils_mac.h"
#include "ui/app_list/app_list_constants.h"
#include "ui/gfx/scoped_ns_graphics_context_save_gstate_mac.h"

namespace {

const CGFloat kButtonHeight = 6;
const CGFloat kButtonCornerRadius = 2;
const CGFloat kButtonStripPadding = 20;

}  // namespace

@interface AppListPagerView ()

@property(assign, nonatomic) NSInteger hoveredSegment;

- (NSInteger)segmentUnderEvent:(NSEvent*)theEvent;

@end

@interface AppListPagerCell : NSSegmentedCell;
@end

@implementation AppListPagerView

@synthesize hoveredSegment = hoveredSegment_;

+ (Class)cellClass {
  return [AppListPagerCell class];
}

- (id)init {
  if ((self = [super initWithFrame:NSZeroRect])) {
    trackingArea_.reset(
        [[CrTrackingArea alloc] initWithRect:NSZeroRect
                                     options:NSTrackingInVisibleRect |
                                             NSTrackingMouseEnteredAndExited |
                                             NSTrackingMouseMoved |
                                             NSTrackingActiveInKeyWindow
                                       owner:self
                                    userInfo:nil]);
    [self addTrackingArea:trackingArea_.get()];
    hoveredSegment_ = -1;
  }
  return self;
}

- (void)setHoveredSegment:(NSInteger)segment {
  if (segment == hoveredSegment_)
    return;

  hoveredSegment_ = segment;
  [self setNeedsDisplay:YES];
  return;
}

- (NSInteger)segmentUnderEvent:(NSEvent*)theEvent {
  if ([self segmentCount] == 0)
    return -1;

  NSPoint pointInView = [self convertPoint:[theEvent locationInWindow]
                                  fromView:nil];
  if (![self mouse:pointInView inRect:[self bounds]])
    return -1;

  CGFloat segmentWidth = [self bounds].size.width / [self segmentCount];
  return pointInView.x / segmentWidth;
}

- (BOOL)isHoveredForSegment:(NSInteger)segment {
  return segment == hoveredSegment_;
}

- (void)mouseExited:(NSEvent*)theEvent {
  [self setHoveredSegment:-1];
}

- (void)mouseMoved:(NSEvent*)theEvent {
  [self setHoveredSegment:[self segmentUnderEvent:theEvent]];
}

- (void)mouseDown:(NSEvent*)theEvent {
  // Temporarily clear the highlight to give feedback.
  [self setHoveredSegment:-1];
}

// The stock NSSegmentedControl ignores any clicks outside the non-default
// control height, so process all clicks here.
- (void)mouseUp:(NSEvent*)theEvent {
  [self setHoveredSegment:[self segmentUnderEvent:theEvent]];
  if (hoveredSegment_ < 0)
    return;

  [self setSelectedSegment:hoveredSegment_];
  [[self target] performSelector:[self action]
                      withObject:self];
}

@end

@implementation AppListPagerCell

- (void)drawWithFrame:(NSRect)cellFrame
               inView:(NSView*)controlView {
  // Draw nothing if there are less than two segments.
  if ([self segmentCount] < 2)
    return;

  cellFrame.size.width /= [self segmentCount];
  for (NSInteger i = 0; i < [self segmentCount]; ++i) {
    [self drawSegment:i
              inFrame:cellFrame
             withView:controlView];
    cellFrame.origin.x += cellFrame.size.width;
  }
}

- (void)drawSegment:(NSInteger)segment
            inFrame:(NSRect)frame
           withView:(NSView*)controlView {
  gfx::ScopedNSGraphicsContextSaveGState context;
  NSRect clipRect = NSMakeRect(
      frame.origin.x + kButtonStripPadding / 2,
      frame.origin.y + (frame.size.height - kButtonHeight) / 2,
      frame.size.width - kButtonStripPadding,
      kButtonHeight);
  [[NSBezierPath bezierPathWithRoundedRect:clipRect
                                   xRadius:kButtonCornerRadius
                                   yRadius:kButtonCornerRadius] addClip];

  AppListPagerView* pagerControl =
      base::mac::ObjCCastStrict<AppListPagerView>(controlView);
  SkColor backgroundColor = [pagerControl hoveredSegment] == segment ?
      app_list::kPagerHoverColor :
      app_list::kPagerNormalColor;

  [gfx::SkColorToCalibratedNSColor(backgroundColor) set];
  NSRectFill(frame);

  if (![[self target] conformsToProtocol:@protocol(AppListPagerDelegate)])
    return;

  CGFloat selectedRatio = [[self target] visiblePortionOfPage:segment];
  if (selectedRatio == 0.0)
    return;

  [gfx::SkColorToCalibratedNSColor(app_list::kPagerSelectedColor) set];
  if (selectedRatio < 0)
    frame.origin.x += frame.size.width + frame.size.width * selectedRatio;
  frame.size.width *= fabs(selectedRatio);
  NSRectFill(frame);
}

@end
