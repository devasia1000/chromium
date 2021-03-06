// Copyright (c) 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "chrome/browser/ui/cocoa/autofill/autofill_main_container.h"

#include "base/memory/scoped_nsobject.h"
#include "chrome/browser/ui/autofill/mock_autofill_dialog_controller.h"
#import "chrome/browser/ui/cocoa/autofill/autofill_account_chooser.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/platform_test.h"
#import "ui/base/test/ui_cocoa_test_helper.h"

namespace {

class AutofillMainContainerTest : public ui::CocoaTest {
 public:
  virtual void SetUp() {
    CocoaTest::SetUp();
    container_.reset([[AutofillMainContainer alloc] initWithController:
                         &controller_]);
    [[test_window() contentView] addSubview:[container_ view]];
  }

 protected:
  scoped_nsobject<AutofillMainContainer> container_;
  testing::NiceMock<autofill::MockAutofillDialogController> controller_;
};

}  // namespace

TEST_VIEW(AutofillMainContainerTest, [container_ view])

TEST_F(AutofillMainContainerTest, SubViews) {
  bool hasAccountChooser = false;
  bool hasButtons = false;

  // Should have account chooser, button strip, and details section.
  EXPECT_EQ(3U, [[[container_ view] subviews] count]);
  for (NSView* view in [[container_ view] subviews]) {
    if ([view isKindOfClass:[AutofillAccountChooser class]]) {
      hasAccountChooser = true;
    } else {
      NSArray* subviews = [view subviews];
      if ([subviews count] == 2) {
        EXPECT_TRUE(
            [[subviews objectAtIndex:0] isKindOfClass:[NSButton class]]);
        EXPECT_TRUE(
            [[subviews objectAtIndex:1] isKindOfClass:[NSButton class]]);
        hasButtons = true;
      }
    }
  }

  EXPECT_TRUE(hasAccountChooser && hasButtons);
}