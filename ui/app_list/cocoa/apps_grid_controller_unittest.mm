// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/memory/scoped_nsobject.h"
#import "testing/gtest_mac.h"
#include "ui/app_list/app_list_item_model.h"
#import "ui/app_list/cocoa/apps_collection_view_drag_manager.h"
#import "ui/app_list/cocoa/apps_grid_controller.h"
#import "ui/app_list/cocoa/apps_grid_view_item.h"
#import "ui/app_list/cocoa/apps_pagination_model_observer.h"
#import "ui/app_list/cocoa/test/apps_grid_controller_test_helper.h"
#include "ui/app_list/test/app_list_test_model.h"
#include "ui/app_list/test/app_list_test_view_delegate.h"
#import "ui/base/test/cocoa_test_event_utils.h"

@interface TestPaginationObserver : NSObject<AppsPaginationModelObserver> {
 @private
  int totalPagesChangedCount_;
  int selectedPageChangedCount_;
  int lastNewSelectedPage_;
  bool visibilityDidChange_;
}

@property(assign, nonatomic) int totalPagesChangedCount;
@property(assign, nonatomic) int selectedPageChangedCount;
@property(assign, nonatomic) int lastNewSelectedPage;

- (bool)readVisibilityDidChange;

@end

@implementation TestPaginationObserver

@synthesize totalPagesChangedCount = totalPagesChangedCount_;
@synthesize selectedPageChangedCount = selectedPageChangedCount_;
@synthesize lastNewSelectedPage = lastNewSelectedPage_;

- (bool)readVisibilityDidChange {
  bool truth = visibilityDidChange_;
  visibilityDidChange_ = false;
  return truth;
}

- (void)totalPagesChanged {
  ++totalPagesChangedCount_;
}

- (void)selectedPageChanged:(int)newSelected {
  ++selectedPageChangedCount_;
  lastNewSelectedPage_ = newSelected;
}

- (void)pageVisibilityChanged {
  visibilityDidChange_ = true;
}

@end

namespace app_list {
namespace test {

namespace {

class AppsGridControllerTest : public AppsGridControllerTestHelper {
 public:
  AppsGridControllerTest() {}

  virtual void SetUp() OVERRIDE {
    owned_apps_grid_controller_.reset([[AppsGridController alloc] init]);
    [owned_apps_grid_controller_ setDelegate:delegate_.get()];
    AppsGridControllerTestHelper::SetUpWithGridController(
        owned_apps_grid_controller_.get());

    [[test_window() contentView] addSubview:[apps_grid_controller_ view]];
    [test_window() makePretendKeyWindowAndSetFirstResponder:
        [apps_grid_controller_ collectionViewAtPageIndex:0]];
  }

  virtual void TearDown() OVERRIDE {
    owned_apps_grid_controller_.reset();
    AppsGridControllerTestHelper::TearDown();
  }

 private:
  scoped_nsobject<AppsGridController> owned_apps_grid_controller_;

  DISALLOW_COPY_AND_ASSIGN(AppsGridControllerTest);
};

}  // namespace

TEST_VIEW(AppsGridControllerTest, [apps_grid_controller_ view]);

// Test showing with an empty model.
TEST_F(AppsGridControllerTest, EmptyModelAndShow) {
  EXPECT_TRUE([[apps_grid_controller_ view] superview]);

  // First page should always exist, even if empty.
  EXPECT_EQ(1u, [apps_grid_controller_ pageCount]);
  EXPECT_EQ(0u, [[GetPageAt(0) content] count]);
  EXPECT_TRUE([GetPageAt(0) superview]);  // The pages container.
  EXPECT_TRUE([[GetPageAt(0) superview] superview]);
}

// Test with a single item.
// This test is disabled in builders until the delay to wait for the collection
// view to load subviews can be removed, or some other solution is found.
TEST_F(AppsGridControllerTest, DISABLED_SingleEntryModel) {
  // We need to "wake up" the NSCollectionView, otherwise it does not
  // immediately update its subviews later in this function.
  // When this test is run by itself, it's enough just to send a keypress (and
  // this delay is not needed).
  DelayForCollectionView();
  EXPECT_EQ(1u, [apps_grid_controller_ pageCount]);
  EXPECT_EQ(0u, [[GetPageAt(0) content] count]);

  model()->PopulateApps(1);
  SinkEvents();
  EXPECT_FALSE([GetPageAt(0) animations]);

  EXPECT_EQ(1u, [[GetPageAt(0) content] count]);
  NSArray* subviews = [GetPageAt(0) subviews];
  EXPECT_EQ(1u, [subviews count]);

  // Note that using GetItemViewAt(0) here also works, and returns non-nil even
  // without the delay, but a "click" on it does not register without the delay.
  NSView* subview = [subviews objectAtIndex:0];

  // Launch the item.
  SimulateClick(subview);
  SinkEvents();
  EXPECT_EQ(1, delegate()->activate_count());
  EXPECT_EQ(std::string("Item 0"), delegate()->last_activated()->title());
}

// Test activating an item on the second page (the 17th item).
TEST_F(AppsGridControllerTest, DISABLED_TwoPageModel) {
  DelayForCollectionView();
  ReplaceTestModel(kItemsPerPage * 2);
  [apps_grid_controller_ scrollToPage:1];

  // The NSScrollView animator ignores the duration configured on the
  // NSAnimationContext (set by CocoaTest::Init), so we need to delay here.
  DelayForCollectionView();
  NSArray* subviews = [GetPageAt(1) subviews];
  NSView* subview = [subviews objectAtIndex:0];
  // Launch the item.
  SimulateClick(subview);
  SinkEvents();
  EXPECT_EQ(1, delegate()->activate_count());
  EXPECT_EQ(std::string("Item 16"), delegate()->last_activated()->title());
}

// Test setModel.
TEST_F(AppsGridControllerTest, ReplaceModel) {
  const size_t kOrigItems = 1;
  const size_t kNewItems = 2;

  model()->PopulateApps(kOrigItems);
  EXPECT_EQ(kOrigItems, [[GetPageAt(0) content] count]);

  ReplaceTestModel(kNewItems);
  EXPECT_EQ(kNewItems, [[GetPageAt(0) content] count]);
}

// Test pagination.
TEST_F(AppsGridControllerTest, Pagination) {
  model()->PopulateApps(1);
  EXPECT_EQ(1u, [apps_grid_controller_ pageCount]);
  EXPECT_EQ(1u, [[GetPageAt(0) content] count]);

  ReplaceTestModel(kItemsPerPage);
  EXPECT_EQ(1u, [apps_grid_controller_ pageCount]);
  EXPECT_EQ(kItemsPerPage, [[GetPageAt(0) content] count]);

  // Test adding an item onto the next page.
  model()->PopulateApps(1);  // Now 17 items.
  EXPECT_EQ(2u, [apps_grid_controller_ pageCount]);
  EXPECT_EQ(kItemsPerPage, [[GetPageAt(0) content] count]);
  EXPECT_EQ(1u, [[GetPageAt(1) content] count]);

  // Test N pages with the last page having one empty spot.
  const size_t kPagesToTest = 3;
  ReplaceTestModel(kPagesToTest * kItemsPerPage - 1);
  EXPECT_EQ(kPagesToTest, [apps_grid_controller_ pageCount]);
  for (size_t page_index = 0; page_index < kPagesToTest - 1; ++page_index) {
    EXPECT_EQ(kItemsPerPage, [[GetPageAt(page_index) content] count]);
  }
  EXPECT_EQ(kItemsPerPage - 1, [[GetPageAt(kPagesToTest - 1) content] count]);

  // Test removing pages.
  ReplaceTestModel(1);
  EXPECT_EQ(1u, [apps_grid_controller_ pageCount]);
  EXPECT_EQ(1u, [[GetPageAt(0) content] count]);
}

// Tests basic keyboard navigation on the first page.
TEST_F(AppsGridControllerTest, FirstPageKeyboardNavigation) {
  model()->PopulateApps(kItemsPerPage - 2);
  EXPECT_EQ(kItemsPerPage - 2, [[GetPageAt(0) content] count]);

  SimulateKeyAction(@selector(moveRight:));
  EXPECT_EQ(0u, [apps_grid_controller_ selectedItemIndex]);

  SimulateKeyAction(@selector(moveRight:));
  EXPECT_EQ(1u, [apps_grid_controller_ selectedItemIndex]);

  SimulateKeyAction(@selector(moveDown:));
  EXPECT_EQ(5u, [apps_grid_controller_ selectedItemIndex]);

  SimulateKeyAction(@selector(moveLeft:));
  EXPECT_EQ(4u, [apps_grid_controller_ selectedItemIndex]);

  SimulateKeyAction(@selector(moveUp:));
  EXPECT_EQ(0u, [apps_grid_controller_ selectedItemIndex]);

  // Go to the third item, and launch it.
  SimulateKeyAction(@selector(moveRight:));
  SimulateKeyAction(@selector(moveRight:));
  EXPECT_EQ(2u, [apps_grid_controller_ selectedItemIndex]);
  SimulateKeyAction(@selector(insertNewline:));
  EXPECT_EQ(1, delegate()->activate_count());
  EXPECT_EQ(std::string("Item 2"), delegate()->last_activated()->title());
}

// Tests keyboard navigation across pages.
TEST_F(AppsGridControllerTest, CrossPageKeyboardNavigation) {
  [AppsGridController setScrollAnimationDuration:0.0];

  model()->PopulateApps(2 * kItemsPerPage);
  EXPECT_EQ(kItemsPerPage, [[GetPageAt(0) content] count]);
  EXPECT_EQ(kItemsPerPage, [[GetPageAt(1) content] count]);

  // Moving Left, Up, or PageUp from the top-left corner of the first page does
  // nothing.
  [apps_grid_controller_ selectItemAtIndex:0];
  SimulateKeyAction(@selector(moveLeft:));
  EXPECT_EQ(0u, [apps_grid_controller_ selectedItemIndex]);
  SimulateKeyAction(@selector(moveUp:));
  EXPECT_EQ(0u, [apps_grid_controller_ selectedItemIndex]);
  SimulateKeyAction(@selector(scrollPageUp:));
  EXPECT_EQ(0u, [apps_grid_controller_ selectedItemIndex]);

  // Moving Right from the right side wraps to the next row.
  [apps_grid_controller_ selectItemAtIndex:3];
  SimulateKeyAction(@selector(moveRight:));
  EXPECT_EQ(4u, [apps_grid_controller_ selectedItemIndex]);

  // Moving Down from the bottom goes to the next page and selects the same
  // column. Moving Up again goes back to the first page.
  [apps_grid_controller_ selectItemAtIndex:13];
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);
  SimulateKeyAction(@selector(moveDown:));
  EXPECT_EQ(1u, [apps_grid_controller_ visiblePage]);
  EXPECT_EQ(kItemsPerPage + 1, [apps_grid_controller_ selectedItemIndex]);
  SimulateKeyAction(@selector(moveUp:));
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);
  EXPECT_EQ(13u, [apps_grid_controller_ selectedItemIndex]);

  // Moving Right from the bottom-right corner goes to the next page.
  // Moving Left again goes back to the first page.
  [apps_grid_controller_ selectItemAtIndex:15];
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);
  SimulateKeyAction(@selector(moveRight:));
  EXPECT_EQ(1u, [apps_grid_controller_ visiblePage]);
  EXPECT_EQ(kItemsPerPage, [apps_grid_controller_ selectedItemIndex]);
  SimulateKeyAction(@selector(moveLeft:));
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);
  EXPECT_EQ(15u, [apps_grid_controller_ selectedItemIndex]);

  // PageDown and PageUp switches pages while maintaining the same selection
  // position.
  [apps_grid_controller_ selectItemAtIndex:10];
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);
  SimulateKeyAction(@selector(scrollPageDown:));
  EXPECT_EQ(1u, [apps_grid_controller_ visiblePage]);
  EXPECT_EQ(kItemsPerPage + 10, [apps_grid_controller_ selectedItemIndex]);
  SimulateKeyAction(@selector(scrollPageUp:));
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);
  EXPECT_EQ(10u, [apps_grid_controller_ selectedItemIndex]);

  // Moving Right, Down, or PageDown from the bottom-right corner of the last
  // page does nothing.
  [apps_grid_controller_ selectItemAtIndex:(2 * kItemsPerPage - 1)];
  EXPECT_EQ(1u, [apps_grid_controller_ visiblePage]);
  SimulateKeyAction(@selector(moveRight:));
  EXPECT_EQ(kItemsPerPage + 15, [apps_grid_controller_ selectedItemIndex]);
  SimulateKeyAction(@selector(moveDown:));
  EXPECT_EQ(kItemsPerPage + 15, [apps_grid_controller_ selectedItemIndex]);
  SimulateKeyAction(@selector(scrollPageDown:));
  EXPECT_EQ(kItemsPerPage + 15, [apps_grid_controller_ selectedItemIndex]);

  // Moving down on the bottom of the last page does nothing.
  [apps_grid_controller_ selectItemAtIndex:(2 * kItemsPerPage - 4)];
  EXPECT_EQ(1u, [apps_grid_controller_ visiblePage]);
  SimulateKeyAction(@selector(moveDown:));
  EXPECT_EQ(kItemsPerPage + 12, [apps_grid_controller_ selectedItemIndex]);

  // Remove some items from the last page.
  ReplaceTestModel(kItemsPerPage + 8);
  EXPECT_EQ(8u, [[GetPageAt(1) content] count]);
  EXPECT_EQ(NSNotFound, [apps_grid_controller_ selectedItemIndex]);

  // PageUp/Down to an invalid selection does nothing.
  [apps_grid_controller_ selectItemAtIndex:10];
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);
  SimulateKeyAction(@selector(scrollPageUp:));
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);
  EXPECT_EQ(10u, [apps_grid_controller_ selectedItemIndex]);
  SimulateKeyAction(@selector(scrollPageDown:));
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);
  EXPECT_EQ(10u, [apps_grid_controller_ selectedItemIndex]);

  // After page switch, arrow keys select first item on current page.
  [apps_grid_controller_ scrollToPage:1];
  EXPECT_EQ(NSNotFound, [apps_grid_controller_ selectedItemIndex]);
  SimulateKeyAction(@selector(moveUp:));
  EXPECT_EQ(kItemsPerPage, [apps_grid_controller_ selectedItemIndex]);
}

// Highlighting an item should cause the page it's on to be visible.
TEST_F(AppsGridControllerTest, EnsureHighlightedVisible) {
  model()->PopulateApps(3 * kItemsPerPage);
  EXPECT_EQ(kItemsPerPage, [[GetPageAt(2) content] count]);

  // First and last items of first page.
  [apps_grid_controller_ selectItemAtIndex:0];
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);
  [apps_grid_controller_ selectItemAtIndex:kItemsPerPage - 1];
  EXPECT_EQ(0u, [apps_grid_controller_ visiblePage]);

  // First item of second page.
  [apps_grid_controller_ selectItemAtIndex:kItemsPerPage + 1];
  EXPECT_EQ(1u, [apps_grid_controller_ visiblePage]);

  // Last item in model.
  [apps_grid_controller_ selectItemAtIndex:3 * kItemsPerPage - 1];
  EXPECT_EQ(2u, [apps_grid_controller_ visiblePage]);
}


// Test runtime updates: adding items, removing items, and moving items (e.g. in
// response to app install, uninstall, and chrome sync changes. Also test
// changing titles and icons.
TEST_F(AppsGridControllerTest, ModelUpdates) {
  model()->PopulateApps(2);
  EXPECT_EQ(2u, [[GetPageAt(0) content] count]);
  EXPECT_EQ(std::string("|Item 0,Item 1|"), GetViewContent());

  // Add an item (PopulateApps will create a duplicate "Item 0").
  model()->PopulateApps(1);
  EXPECT_EQ(3u, [[GetPageAt(0) content] count]);
  NSButton* button = GetItemViewAt(2);
  EXPECT_NSEQ(@"Item 0", [button title]);
  EXPECT_EQ(std::string("|Item 0,Item 1,Item 0|"), GetViewContent());

  // Update the title via the ItemModelObserver.
  app_list::AppListItemModel* item_model = model()->apps()->GetItemAt(2);
  item_model->SetTitle("UpdatedItem");
  EXPECT_NSEQ(@"UpdatedItem", [button title]);
  EXPECT_EQ(std::string("|Item 0,Item 1,UpdatedItem|"), GetViewContent());

  // Update the icon, test by changing size.
  NSSize icon_size = [[button image] size];
  EXPECT_EQ(0, icon_size.width);
  EXPECT_EQ(0, icon_size.height);

  SkBitmap bitmap;
  const int kTestImageSize = 10;
  bitmap.setConfig(SkBitmap::kARGB_8888_Config, kTestImageSize, kTestImageSize);
  item_model->SetIcon(gfx::ImageSkia::CreateFrom1xBitmap(bitmap), false);
  icon_size = [[button image] size];
  EXPECT_EQ(kTestImageSize, icon_size.width);
  EXPECT_EQ(kTestImageSize, icon_size.height);

  // Test removing an item at the end.
  model()->apps()->DeleteAt(2);
  EXPECT_EQ(2u, [apps_grid_controller_ itemCount]);
  EXPECT_EQ(std::string("|Item 0,Item 1|"), GetViewContent());

  // Test removing in the middle.
  model()->AddItem("Item 2");
  EXPECT_EQ(3u, [apps_grid_controller_ itemCount]);
  EXPECT_EQ(std::string("|Item 0,Item 1,Item 2|"), GetViewContent());
  model()->apps()->DeleteAt(1);
  EXPECT_EQ(2u, [apps_grid_controller_ itemCount]);
  EXPECT_EQ(std::string("|Item 0,Item 2|"), GetViewContent());

  // Test inserting in the middle.
  model()->apps()->AddAt(1, model()->CreateItem("Item One"));
  EXPECT_EQ(3u, [apps_grid_controller_ itemCount]);
  EXPECT_EQ(std::string("|Item 0,Item One,Item 2|"), GetViewContent());

  // Test swapping items (e.g. rearranging via sync).
  model()->apps()->Move(1, 2);
  EXPECT_EQ(std::string("|Item 0,Item 2,Item One|"), GetViewContent());

  // Test removing multiple items via the model.
  model()->apps()->DeleteAll();
  EXPECT_EQ(0u, [apps_grid_controller_ itemCount]);
  EXPECT_EQ(std::string("||"), GetViewContent());

  // Test removing the last item when there is one item on the second page.
  ReplaceTestModel(kItemsPerPage + 1);
  EXPECT_EQ(kItemsPerPage + 1, [apps_grid_controller_ itemCount]);
  EXPECT_EQ(2u, [apps_grid_controller_ pageCount]);
  model()->apps()->DeleteAt(kItemsPerPage);
  EXPECT_EQ(kItemsPerPage, [apps_grid_controller_ itemCount]);
  EXPECT_EQ(1u, [apps_grid_controller_ pageCount]);
}

// Test mouseover selection.
TEST_F(AppsGridControllerTest, MouseoverSelects) {
  model()->PopulateApps(2);
  EXPECT_EQ(nil, GetSelectedView());

  // Test entering and exiting the first item.
  SimulateMouseEnterItemAt(0);
  EXPECT_EQ(GetItemViewAt(0), GetSelectedView());
  SimulateMouseExitItemAt(0);
  EXPECT_EQ(nil, GetSelectedView());

  // AppKit doesn't guarantee the order, so test moving between items.
  SimulateMouseEnterItemAt(0);
  EXPECT_EQ(GetItemViewAt(0), GetSelectedView());
  SimulateMouseEnterItemAt(1);
  EXPECT_EQ(GetItemViewAt(1), GetSelectedView());
  SimulateMouseExitItemAt(0);
  EXPECT_EQ(GetItemViewAt(1), GetSelectedView());
  SimulateMouseExitItemAt(1);
  EXPECT_EQ(nil, GetSelectedView());
}

// Test AppsGridPaginationObserver totalPagesChanged().
TEST_F(AppsGridControllerTest, PaginationObserverPagesChanged) {
  scoped_nsobject<TestPaginationObserver> observer(
      [[TestPaginationObserver alloc] init]);
  [apps_grid_controller_ setPaginationObserver:observer];

  // Test totalPagesChanged.
  model()->PopulateApps(kItemsPerPage);
  EXPECT_EQ(0, [observer totalPagesChangedCount]);
  EXPECT_EQ(1u, [apps_grid_controller_ pageCount]);
  model()->PopulateApps(1);
  EXPECT_EQ(1, [observer totalPagesChangedCount]);
  EXPECT_EQ(2u, [apps_grid_controller_ pageCount]);
  ReplaceTestModel(0);
  EXPECT_EQ(2, [observer totalPagesChangedCount]);
  EXPECT_EQ(1u, [apps_grid_controller_ pageCount]);
  ReplaceTestModel(kItemsPerPage * 3 + 1);
  EXPECT_EQ(3, [observer totalPagesChangedCount]);
  EXPECT_EQ(4u, [apps_grid_controller_ pageCount]);

  EXPECT_FALSE([observer readVisibilityDidChange]);
  EXPECT_EQ(0, [observer selectedPageChangedCount]);

  [apps_grid_controller_ setPaginationObserver:nil];
}

// Test AppsGridPaginationObserver selectedPageChanged().
TEST_F(AppsGridControllerTest, PaginationObserverSelectedPageChanged) {
  [AppsGridController setScrollAnimationDuration:0.0];
  scoped_nsobject<TestPaginationObserver> observer(
      [[TestPaginationObserver alloc] init]);
  [apps_grid_controller_ setPaginationObserver:observer];
  EXPECT_EQ(0, [[NSAnimationContext currentContext] duration]);

  ReplaceTestModel(kItemsPerPage * 3 + 1);
  EXPECT_EQ(1, [observer totalPagesChangedCount]);
  EXPECT_EQ(4u, [apps_grid_controller_ pageCount]);

  EXPECT_FALSE([observer readVisibilityDidChange]);
  EXPECT_EQ(0, [observer selectedPageChangedCount]);

  [apps_grid_controller_ scrollToPage:1];
  EXPECT_EQ(1, [observer selectedPageChangedCount]);
  EXPECT_EQ(1, [observer lastNewSelectedPage]);
  EXPECT_TRUE([observer readVisibilityDidChange]);
  EXPECT_FALSE([observer readVisibilityDidChange]);  // Testing test behaviour.
  EXPECT_EQ(0.0, [apps_grid_controller_ visiblePortionOfPage:0]);
  EXPECT_EQ(1.0, [apps_grid_controller_ visiblePortionOfPage:1]);
  EXPECT_EQ(0.0, [apps_grid_controller_ visiblePortionOfPage:2]);
  EXPECT_EQ(0.0, [apps_grid_controller_ visiblePortionOfPage:3]);

  [apps_grid_controller_ scrollToPage:0];
  EXPECT_EQ(2, [observer selectedPageChangedCount]);
  EXPECT_EQ(0, [observer lastNewSelectedPage]);
  EXPECT_TRUE([observer readVisibilityDidChange]);
  EXPECT_EQ(1.0, [apps_grid_controller_ visiblePortionOfPage:0]);
  EXPECT_EQ(0.0, [apps_grid_controller_ visiblePortionOfPage:1]);

  [apps_grid_controller_ scrollToPage:3];
  // Note: with no animations, there is only a single page change. However, with
  // animations we expect multiple updates depending on the rate that the scroll
  // view updates and sends out NSViewBoundsDidChangeNotification.
  EXPECT_EQ(3, [observer selectedPageChangedCount]);
  EXPECT_EQ(3, [observer lastNewSelectedPage]);
  EXPECT_TRUE([observer readVisibilityDidChange]);
  EXPECT_EQ(0.0, [apps_grid_controller_ visiblePortionOfPage:0]);
  EXPECT_EQ(1.0, [apps_grid_controller_ visiblePortionOfPage:3]);

  [apps_grid_controller_ setPaginationObserver:nil];
}

namespace {

// Generate a mouse event at the centre of the view in |page| with the given
// |index_in_page| that can be used to initiate, update and complete drag
// operations.
NSEvent* MouseEventInCell(NSCollectionView* page, size_t index_in_page) {
  NSRect cell_rect = [page frameForItemAtIndex:index_in_page];
  NSPoint point_in_view = NSMakePoint(NSMidX(cell_rect), NSMidY(cell_rect));
  NSPoint point_in_window = [page convertPoint:point_in_view
                                        toView:nil];
  return cocoa_test_event_utils::LeftMouseDownAtPoint(point_in_window);
}

}  // namespace

// Test basic item moves with two items; swapping them around, dragging outside
// of the view bounds, and dragging on the background.
TEST_F(AppsGridControllerTest, DragAndDropSimple) {
  model()->PopulateApps(2);
  NSCollectionView* page = [apps_grid_controller_ collectionViewAtPageIndex:0];
  NSEvent* mouse_at_cell_0 = MouseEventInCell(page, 0);
  NSEvent* mouse_at_cell_1 = MouseEventInCell(page, 1);
  NSEvent* mouse_at_page_centre = MouseEventInCell(page, 6);
  NSEvent* mouse_off_page = MouseEventInCell(page, kItemsPerPage * 2);

  const std::string kOrdered = "Item 0,Item 1";
  const std::string kSwapped = "Item 1,Item 0";
  const std::string kOrderedView = "|Item 0,Item 1|";
  const std::string kSwappedView = "|Item 1,Item 0|";

  EXPECT_EQ(kOrdered, model()->GetModelContent());
  EXPECT_EQ(kOrderedView, GetViewContent());
  AppsCollectionViewDragManager* drag_manager =
      [apps_grid_controller_ dragManager];

  // Drag first item over the second item and release.
  [drag_manager onMouseDownInPage:page
                        withEvent:mouse_at_cell_0];
  [drag_manager onMouseDragged:mouse_at_cell_1];
  EXPECT_EQ(kOrdered, model()->GetModelContent());
  EXPECT_EQ(kSwappedView, GetViewContent());  // View swaps first.
  [drag_manager onMouseUp:mouse_at_cell_1];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kSwappedView, GetViewContent());

  // Drag item back.
  [drag_manager onMouseDownInPage:page
                        withEvent:mouse_at_cell_1];
  [drag_manager onMouseDragged:mouse_at_cell_0];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kOrderedView, GetViewContent());
  [drag_manager onMouseUp:mouse_at_cell_0];
  EXPECT_EQ(kOrdered, model()->GetModelContent());
  EXPECT_EQ(kOrderedView, GetViewContent());

  // Drag first item to centre of view (should put in last place).
  [drag_manager onMouseDownInPage:page
                        withEvent:mouse_at_cell_0];
  [drag_manager onMouseDragged:mouse_at_page_centre];
  EXPECT_EQ(kOrdered, model()->GetModelContent());
  EXPECT_EQ(kSwappedView, GetViewContent());
  [drag_manager onMouseUp:mouse_at_page_centre];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kSwappedView, GetViewContent());

  // Drag item to centre again (should leave it in the last place).
  [drag_manager onMouseDownInPage:page
                        withEvent:mouse_at_cell_1];
  [drag_manager onMouseDragged:mouse_at_page_centre];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kSwappedView, GetViewContent());
  [drag_manager onMouseUp:mouse_at_page_centre];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kSwappedView, GetViewContent());

  // Drag starting in the centre of the view, should do nothing.
  [drag_manager onMouseDownInPage:page
                        withEvent:mouse_at_page_centre];
  [drag_manager onMouseDragged:mouse_at_cell_0];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kSwappedView, GetViewContent());
  [drag_manager onMouseUp:mouse_at_cell_0];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kSwappedView, GetViewContent());

  // Click off page.
  [drag_manager onMouseDownInPage:page
                        withEvent:mouse_off_page];
  [drag_manager onMouseDragged:mouse_at_cell_0];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kSwappedView, GetViewContent());
  [drag_manager onMouseUp:mouse_at_cell_0];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kSwappedView, GetViewContent());

  // Drag to first over second item, then off page.
  [drag_manager onMouseDownInPage:page
                        withEvent:mouse_at_cell_0];
  [drag_manager onMouseDragged:mouse_at_cell_1];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kOrderedView, GetViewContent());
  [drag_manager onMouseDragged:mouse_off_page];
  EXPECT_EQ(kSwapped, model()->GetModelContent());
  EXPECT_EQ(kOrderedView, GetViewContent());
  [drag_manager onMouseUp:mouse_off_page];
  EXPECT_EQ(kOrdered, model()->GetModelContent());
  EXPECT_EQ(kOrderedView, GetViewContent());

  // Replace with an empty model, and ensure we do not break.
  ReplaceTestModel(0);
  EXPECT_EQ(std::string(), model()->GetModelContent());
  EXPECT_EQ(std::string("||"), GetViewContent());
  [drag_manager onMouseDownInPage:page
                        withEvent:mouse_at_cell_0];
  [drag_manager onMouseDragged:mouse_at_cell_1];
  [drag_manager onMouseUp:mouse_at_cell_1];
  EXPECT_EQ(std::string(), model()->GetModelContent());
  EXPECT_EQ(std::string("||"), GetViewContent());
}

// Test item moves between pages.
TEST_F(AppsGridControllerTest, DragAndDropMultiPage) {
  [AppsGridController setScrollAnimationDuration:0.0];
  const size_t kPagesToTest = 3;
  // Put one item on the last page to hit more edge cases.
  ReplaceTestModel(kItemsPerPage * (kPagesToTest - 1) + 1);
  NSCollectionView* page[kPagesToTest];
  for (size_t i = 0; i < kPagesToTest; ++i)
    page[i] = [apps_grid_controller_ collectionViewAtPageIndex:i];

  const std::string kSecondItemMovedToSecondPage =
      "|Item 0,Item 2,Item 3,Item 4,Item 5,Item 6,Item 7,Item 8,"
      "Item 9,Item 10,Item 11,Item 12,Item 13,Item 14,Item 15,Item 16|"
      "|Item 17,Item 1,Item 18,Item 19,Item 20,Item 21,Item 22,Item 23,"
      "Item 24,Item 25,Item 26,Item 27,Item 28,Item 29,Item 30,Item 31|"
      "|Item 32|";

  NSEvent* mouse_at_cell_0 = MouseEventInCell(page[0], 0);
  NSEvent* mouse_at_cell_1 = MouseEventInCell(page[0], 1);
  AppsCollectionViewDragManager* drag_manager =
      [apps_grid_controller_ dragManager];
  [drag_manager onMouseDownInPage:page[0]
                        withEvent:mouse_at_cell_1];

  // Initiate dragging before changing pages.
  [drag_manager onMouseDragged:mouse_at_cell_0];

  // Scroll to the second page.
  [apps_grid_controller_ scrollToPage:1];
  [drag_manager onMouseDragged:mouse_at_cell_1];

  // Do one exhaustive check, and then spot-check corner cases.
  EXPECT_EQ(kSecondItemMovedToSecondPage, GetViewContent());
  EXPECT_EQ(0u, GetPageIndexForItem(0));
  EXPECT_EQ(1u, GetPageIndexForItem(1));
  EXPECT_EQ(0u, GetPageIndexForItem(2));
  EXPECT_EQ(0u, GetPageIndexForItem(16));
  EXPECT_EQ(1u, GetPageIndexForItem(17));
  EXPECT_EQ(1u, GetPageIndexForItem(31));
  EXPECT_EQ(2u, GetPageIndexForItem(32));

  // Scroll to the third page and drag some more.
  [apps_grid_controller_ scrollToPage:2];
  [drag_manager onMouseDragged:mouse_at_cell_1];
  EXPECT_EQ(2u, GetPageIndexForItem(1));
  EXPECT_EQ(1u, GetPageIndexForItem(31));
  EXPECT_EQ(1u, GetPageIndexForItem(32));

  // Scroll backwards.
  [apps_grid_controller_ scrollToPage:1];
  [drag_manager onMouseDragged:mouse_at_cell_1];
  EXPECT_EQ(kSecondItemMovedToSecondPage, GetViewContent());
  EXPECT_EQ(1u, GetPageIndexForItem(1));
  EXPECT_EQ(1u, GetPageIndexForItem(31));
  EXPECT_EQ(2u, GetPageIndexForItem(32));

  // Simulate installing an item while dragging (or have it appear during sync).
  model()->PopulateAppWithId(33);
  // Item should go back to its position before the drag.
  EXPECT_EQ(0u, GetPageIndexForItem(1));
  EXPECT_EQ(1u, GetPageIndexForItem(31));
  EXPECT_EQ(2u, GetPageIndexForItem(32));
  // New item should appear at end.
  EXPECT_EQ(2u, GetPageIndexForItem(33));

  // Scroll to end again, and keep dragging (should be ignored).
  [apps_grid_controller_ scrollToPage:2];
  [drag_manager onMouseDragged:mouse_at_cell_0];
  EXPECT_EQ(0u, GetPageIndexForItem(1));
  [drag_manager onMouseUp:mouse_at_cell_0];
  EXPECT_EQ(0u, GetPageIndexForItem(1));
}

}  // namespace test
}  // namespace app_list
