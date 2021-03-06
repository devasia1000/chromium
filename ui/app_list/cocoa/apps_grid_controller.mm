// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ui/app_list/cocoa/apps_grid_controller.h"

#include "base/mac/foundation_util.h"
#include "ui/app_list/app_list_model.h"
#include "ui/app_list/app_list_model_observer.h"
#include "ui/app_list/app_list_view_delegate.h"
#import "ui/app_list/cocoa/apps_collection_view_drag_manager.h"
#import "ui/app_list/cocoa/apps_grid_view_item.h"
#import "ui/app_list/cocoa/apps_pagination_model_observer.h"
#include "ui/base/models/list_model_observer.h"

namespace {

// OSX app list has hardcoded rows and columns for now.
const int kFixedRows = 4;
const int kFixedColumns = 4;
const int kItemsPerPage = kFixedRows * kFixedColumns;

// Padding space in pixels for fixed layout.
const CGFloat kLeftRightPadding = 16;
const CGFloat kScrollerPadding = 16;

// Preferred tile size when showing in fixed layout. These should be even
// numbers to ensure that if they are grown 50% they remain integers.
const CGFloat kPreferredTileWidth = 88;
const CGFloat kPreferredTileHeight = 98;

const CGFloat kViewWidth =
    kFixedColumns * kPreferredTileWidth + 2 * kLeftRightPadding;
const CGFloat kViewHeight = kFixedRows * kPreferredTileHeight;

NSTimeInterval g_scroll_duration = 0.18;

}  // namespace

@interface AppsGridController ()

// Cancel a currently running scroll animation.
- (void)cancelScrollAnimation;

// Index of the page with the most content currently visible.
- (size_t)nearestPageIndex;

// Bootstrap the views this class controls.
- (void)loadAndSetView;

- (void)boundsDidChange:(NSNotification*)notification;

// Action for buttons in the grid.
- (void)onItemClicked:(id)sender;

- (AppsGridViewItem*)itemAtPageIndex:(size_t)pageIndex
                         indexInPage:(size_t)indexInPage;

// Update the model in full, and rebuild subviews.
- (void)modelUpdated;

// Return the button of the selected item.
- (NSButton*)selectedButton;

// The scroll view holding the grid pages.
- (NSScrollView*)gridScrollView;

- (NSView*)pagesContainerView;

// Create any new pages after updating |items_|.
- (void)updatePages:(size_t)startItemIndex;

- (void)updatePageContent:(size_t)pageIndex
               resetModel:(BOOL)resetModel;

// Bridged methods for ui::ListModelObserver.
- (void)listItemsAdded:(size_t)start
                 count:(size_t)count;

- (void)listItemsRemoved:(size_t)start
                   count:(size_t)count;

- (void)listItemMovedFromIndex:(size_t)fromIndex
                  toModelIndex:(size_t)toIndex;

// Moves the selection by |indexDelta| items.
- (BOOL)moveSelectionByDelta:(int)indexDelta;

@end

namespace app_list {

class AppsGridDelegateBridge : public ui::ListModelObserver {
 public:
  AppsGridDelegateBridge(AppsGridController* parent) : parent_(parent) {}

 private:
  // Overridden from ui::ListModelObserver:
  virtual void ListItemsAdded(size_t start, size_t count) OVERRIDE {
    [parent_ listItemsAdded:start
                      count:count];
  }
  virtual void ListItemsRemoved(size_t start, size_t count) OVERRIDE {
    [parent_ listItemsRemoved:start
                        count:count];
  }
  virtual void ListItemMoved(size_t index, size_t target_index) OVERRIDE {
    [parent_ listItemMovedFromIndex:index
                       toModelIndex:target_index];
  }
  virtual void ListItemsChanged(size_t start, size_t count) OVERRIDE {
    NOTREACHED();
  }

  AppsGridController* parent_;  // Weak, owns us.

  DISALLOW_COPY_AND_ASSIGN(AppsGridDelegateBridge);
};

}  // namespace app_list

@interface PageContainerView : NSView;
@end

// The container view needs to flip coordinates so that it is laid out
// correctly whether or not there is a horizontal scrollbar.
@implementation PageContainerView

- (BOOL)isFlipped {
  return YES;
}

@end

@implementation AppsGridController

+ (void)setScrollAnimationDuration:(NSTimeInterval)duration {
  g_scroll_duration = duration;
}

@synthesize paginationObserver = paginationObserver_;

- (id)init {
  if ((self = [super init])) {
    bridge_.reset(new app_list::AppsGridDelegateBridge(self));
    NSSize cellSize = NSMakeSize(kPreferredTileWidth, kPreferredTileHeight);
    dragManager_.reset(
        [[AppsCollectionViewDragManager alloc] initWithCellSize:cellSize
                                                           rows:kFixedRows
                                                        columns:kFixedColumns
                                                 gridController:self]);
    pages_.reset([[NSMutableArray alloc] init]);
    items_.reset([[NSMutableArray alloc] init]);
    [self loadAndSetView];
    [self updatePages:0];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self setModel:scoped_ptr<app_list::AppListModel>()];
  [super dealloc];
}

- (NSCollectionView*)collectionViewAtPageIndex:(size_t)pageIndex {
  return [pages_ objectAtIndex:pageIndex];
}

- (size_t)pageIndexForCollectionView:(NSCollectionView*)page {
  for (size_t pageIndex = 0; pageIndex < [pages_ count]; ++pageIndex) {
    if (page == [self collectionViewAtPageIndex:pageIndex])
      return pageIndex;
  }
  return NSNotFound;
}

- (app_list::AppListModel*)model {
  return model_.get();
}

- (void)setModel:(scoped_ptr<app_list::AppListModel>)newModel {
  if (model_) {
    model_->apps()->RemoveObserver(bridge_.get());

    // Since the model is about to be deleted, and the AppKit objects might be
    // sitting in an NSAutoreleasePool, ensure there are no references to the
    // model.
    for (size_t i = 0; i < [items_ count]; ++i)
      [[self itemAtIndex:i] setModel:NULL];
  }

  model_.reset(newModel.release());
  if (model_)
    model_->apps()->AddObserver(bridge_.get());

  [self modelUpdated];
}

- (void)setDelegate:(app_list::AppListViewDelegate*)newDelegate {
  scoped_ptr<app_list::AppListModel> newModel(new app_list::AppListModel);
  delegate_ = newDelegate;
  if (delegate_)
    delegate_->SetModel(newModel.get());  // Populates items.
  [self setModel:newModel.Pass()];
}

- (size_t)visiblePage {
  return visiblePage_;
}

- (void)activateSelection {
  [[self selectedButton] performClick:self];
}

- (size_t)pageCount {
  return [pages_ count];
}

- (size_t)itemCount {
  return [items_ count];
}

- (void)scrollToPage:(size_t)pageIndex {
  NSClipView* clipView = [[self gridScrollView] contentView];
  NSPoint newOrigin = [clipView bounds].origin;

  // Scrolling outside of this range is edge elasticity, which animates
  // automatically.
  if ((pageIndex == 0 && (newOrigin.x <= 0)) ||
      (pageIndex + 1 == [self pageCount] &&
          newOrigin.x >= pageIndex * kViewWidth)) {
    return;
  }

  // Clear any selection on the current page (unless it has been removed).
  if (visiblePage_ < [pages_ count]) {
    [[self collectionViewAtPageIndex:visiblePage_]
        setSelectionIndexes:[NSIndexSet indexSet]];
  }

  newOrigin.x = pageIndex * kViewWidth;
  [NSAnimationContext beginGrouping];
  [[NSAnimationContext currentContext] setDuration:g_scroll_duration];
  [[clipView animator] setBoundsOrigin:newOrigin];
  [NSAnimationContext endGrouping];
  animatingScroll_ = YES;
}

- (void)cancelScrollAnimation {
  NSClipView* clipView = [[self gridScrollView] contentView];
  [NSAnimationContext beginGrouping];
  [[NSAnimationContext currentContext] setDuration:0];
  [[clipView animator] setBoundsOrigin:[clipView bounds].origin];
  [NSAnimationContext endGrouping];
  animatingScroll_ = NO;
}

- (size_t)nearestPageIndex {
  return lround(
      NSMinX([[[self gridScrollView] contentView] bounds]) / kViewWidth);
}

- (void)userScrolling:(BOOL)isScrolling {
  if (isScrolling) {
    if (animatingScroll_)
      [self cancelScrollAnimation];
  } else {
    [self scrollToPage:[self nearestPageIndex]];
  }
}

- (void)loadAndSetView {
  scoped_nsobject<PageContainerView> pagesContainer(
      [[PageContainerView alloc] initWithFrame:NSZeroRect]);

  NSRect scrollFrame = NSMakeRect(0, 0, kViewWidth,
                                  kViewHeight + kScrollerPadding);
  scoped_nsobject<ScrollViewWithNoScrollbars> scrollView(
      [[ScrollViewWithNoScrollbars alloc] initWithFrame:scrollFrame]);
  [scrollView setBorderType:NSNoBorder];
  [scrollView setLineScroll:kViewWidth];
  [scrollView setPageScroll:kViewWidth];
  [scrollView setDelegate:self];
  [scrollView setDocumentView:pagesContainer];
  [scrollView setDrawsBackground:NO];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(boundsDidChange:)
             name:NSViewBoundsDidChangeNotification
           object:[scrollView contentView]];

  [self setView:scrollView];
}

- (void)boundsDidChange:(NSNotification*)notification {
  size_t newPage = [self nearestPageIndex];
  if (newPage == visiblePage_) {
    [paginationObserver_ pageVisibilityChanged];
    return;
  }

  visiblePage_ = newPage;
  [paginationObserver_ selectedPageChanged:newPage];
  [paginationObserver_ pageVisibilityChanged];
}

- (void)onItemClicked:(id)sender {
  for (size_t i = 0; i < [items_ count]; ++i) {
    AppsGridViewItem* item = [self itemAtIndex:i];
    if ([[item button] isEqual:sender])
      delegate_->ActivateAppListItem([item model], 0);
  }
}

- (AppsGridViewItem*)itemAtPageIndex:(size_t)pageIndex
                         indexInPage:(size_t)indexInPage {
  return base::mac::ObjCCastStrict<AppsGridViewItem>(
      [[self collectionViewAtPageIndex:pageIndex] itemAtIndex:indexInPage]);
}

- (AppsGridViewItem*)itemAtIndex:(size_t)itemIndex {
  const size_t pageIndex = itemIndex / kItemsPerPage;
  return [self itemAtPageIndex:pageIndex
                   indexInPage:itemIndex - pageIndex * kItemsPerPage];
}

- (void)modelUpdated {
  [items_ removeAllObjects];
  if (model_ && model_->apps()->item_count()) {
    [self listItemsAdded:0
                   count:model_->apps()->item_count()];
  } else {
    [self updatePages:0];
  }
  [self scrollToPage:0];
}

- (NSUInteger)selectedItemIndex {
  NSCollectionView* page = [self collectionViewAtPageIndex:visiblePage_];
  NSUInteger indexOnPage = [[page selectionIndexes] firstIndex];
  if (indexOnPage == NSNotFound)
    return NSNotFound;

  return indexOnPage + visiblePage_ * kItemsPerPage;
}

- (NSButton*)selectedButton {
  NSUInteger index = [self selectedItemIndex];
  if (index == NSNotFound)
    return nil;

  return [[self itemAtIndex:index] button];
}

- (NSScrollView*)gridScrollView {
  return base::mac::ObjCCastStrict<NSScrollView>([self view]);
}

- (NSView*)pagesContainerView {
  return [[self gridScrollView] documentView];
}

- (void)updatePages:(size_t)startItemIndex {
  // Note there is always at least one page.
  size_t targetPages = 1;
  if ([items_ count] != 0)
    targetPages = ([items_ count] - 1) / kItemsPerPage + 1;

  const size_t currentPages = [self pageCount];
  // First see if the number of pages have changed.
  if (targetPages != currentPages) {
    if (targetPages < currentPages) {
      // Pages need to be removed.
      [pages_ removeObjectsInRange:NSMakeRange(targetPages,
                                               currentPages - targetPages)];
    } else {
      // Pages need to be added.
      for (size_t i = currentPages; i < targetPages; ++i) {
        NSRect pageFrame = NSMakeRect(
            kLeftRightPadding + kViewWidth * i, 0,
            kViewWidth, kViewHeight);
        [pages_ addObject:[dragManager_ makePageWithFrame:pageFrame]];
      }
    }

    [[self pagesContainerView] setSubviews:pages_];
    NSSize pagesSize = NSMakeSize(kViewWidth * targetPages, kViewHeight);
    [[self pagesContainerView] setFrameSize:pagesSize];
    [paginationObserver_ totalPagesChanged];
  }

  const size_t startPage = startItemIndex / kItemsPerPage;
  // All pages on or after |startPage| may need items added or removed.
  for (size_t pageIndex = startPage; pageIndex < targetPages; ++pageIndex) {
    [self updatePageContent:pageIndex
                 resetModel:YES];
  }
}

- (void)updatePageContent:(size_t)pageIndex
               resetModel:(BOOL)resetModel {
  NSCollectionView* pageView = [self collectionViewAtPageIndex:pageIndex];
  if (resetModel) {
    // Clear the models first, otherwise removed items could be autoreleased at
    // an unknown point in the future, when the model owner may have gone away.
    for (size_t i = 0; i < [[pageView content] count]; ++i) {
      AppsGridViewItem* item = base::mac::ObjCCastStrict<AppsGridViewItem>(
          [pageView itemAtIndex:i]);
      [item setModel:NULL];
    }
  }

  NSRange inPageRange = NSIntersectionRange(
      NSMakeRange(pageIndex * kItemsPerPage, kItemsPerPage),
      NSMakeRange(0, [items_ count]));
  NSArray* pageContent = [items_ subarrayWithRange:inPageRange];
  [pageView setContent:pageContent];
  if (!resetModel)
    return;

  for (size_t i = 0; i < [pageContent count]; ++i) {
    AppsGridViewItem* item = base::mac::ObjCCastStrict<AppsGridViewItem>(
        [pageView itemAtIndex:i]);
    [item setModel:static_cast<app_list::AppListItemModel*>(
        [[pageContent objectAtIndex:i] pointerValue])];
  }
}

- (void)moveItemInView:(size_t)fromIndex
           toItemIndex:(size_t)toIndex {
  scoped_nsobject<NSValue> item([[items_ objectAtIndex:fromIndex] retain]);
  [items_ removeObjectAtIndex:fromIndex];
  [items_ insertObject:item
               atIndex:toIndex];

  size_t fromPageIndex = fromIndex / kItemsPerPage;
  size_t toPageIndex = toIndex / kItemsPerPage;
  if (fromPageIndex == toPageIndex) {
    [self updatePageContent:fromPageIndex
                 resetModel:NO];  // Just reorder items.
    return;
  }

  if (fromPageIndex > toPageIndex)
    std::swap(fromPageIndex, toPageIndex);

  for (size_t i = fromPageIndex; i <= toPageIndex; ++i) {
    [self updatePageContent:i
                 resetModel:YES];
  }
}

// Compare with views implementation in AppsGridView::MoveItemInModel().
- (void)moveItemWithIndex:(size_t)itemIndex
             toModelIndex:(size_t)modelIndex {
  // Ingore no-op moves. Note that this is always the case when canceled.
  if (itemIndex == modelIndex)
    return;

  model_->apps()->RemoveObserver(bridge_.get());
  model_->apps()->Move(itemIndex, modelIndex);
  model_->apps()->AddObserver(bridge_.get());
}

- (AppsCollectionViewDragManager*)dragManager {
  return dragManager_;
}

- (void)listItemsAdded:(size_t)start
                 count:(size_t)count {
  // Cancel any drag, to ensure the model stays consistent.
  [dragManager_ cancelDrag];

  for (size_t i = start; i < start + count; ++i) {
    app_list::AppListItemModel* itemModel = model_->apps()->GetItemAt(i);
    [items_ insertObject:[NSValue valueWithPointer:itemModel]
                 atIndex:i];
  }

  [self updatePages:start];
}

- (void)listItemsRemoved:(size_t)start
                   count:(size_t)count {
  [dragManager_ cancelDrag];

  // Clear the models explicitly to avoid surprises from autorelease.
  for (size_t i = start; i < start + count; ++i)
    [[self itemAtIndex:i] setModel:NULL];

  [items_ removeObjectsInRange:NSMakeRange(start, count)];
  [self updatePages:start];
}

- (void)listItemMovedFromIndex:(size_t)fromIndex
                  toModelIndex:(size_t)toIndex {
  [dragManager_ cancelDrag];
  [self moveItemInView:fromIndex
           toItemIndex:toIndex];
}

- (CGFloat)visiblePortionOfPage:(int)page {
  CGFloat scrollOffsetOfPage =
      NSMinX([[[self gridScrollView] contentView] bounds]) / kViewWidth - page;
  if (scrollOffsetOfPage <= -1.0 || scrollOffsetOfPage >= 1.0)
    return 0.0;

  if (scrollOffsetOfPage <= 0.0)
    return scrollOffsetOfPage + 1.0;

  return -1.0 + scrollOffsetOfPage;
}

- (void)onPagerClicked:(AppListPagerView*)sender {
  int selectedSegment = [sender selectedSegment];
  if (selectedSegment < 0)
    return;  // No selection.

  int pageIndex = [[sender cell] tagForSegment:selectedSegment];
  if (pageIndex >= 0)
    [self scrollToPage:pageIndex];
}

- (BOOL)moveSelectionByDelta:(int)indexDelta {
  if (indexDelta == 0)
    return NO;

  NSUInteger oldIndex = [self selectedItemIndex];

  // If nothing is currently selected, select the first item on the page.
  if (oldIndex == NSNotFound) {
    [self selectItemAtIndex:visiblePage_ * kItemsPerPage];
    return YES;
  }

  if ((indexDelta < 0 && static_cast<NSUInteger>(-indexDelta) > oldIndex) ||
      oldIndex + indexDelta >= [items_ count]) {
    return NO;
  }

  [self selectItemAtIndex:oldIndex + indexDelta];
  return YES;
}

- (void)selectItemAtIndex:(NSUInteger)index {
  if (index >= [items_ count])
    return;

  if (index / kItemsPerPage != visiblePage_)
    [self scrollToPage:index / kItemsPerPage];

  [[self itemAtIndex:index] setSelected:YES];
}

- (BOOL)handleCommandBySelector:(SEL)command {
  if (command == @selector(insertNewline:) ||
      command == @selector(insertLineBreak:)) {
    [self activateSelection];
    return YES;
  }

  if (command == @selector(moveLeft:))
    return [self moveSelectionByDelta:-1];

  if (command == @selector(moveRight:))
    return [self moveSelectionByDelta:1];

  if (command == @selector(moveUp:))
    return [self moveSelectionByDelta:-kFixedColumns];

  if (command == @selector(moveDown:))
    return [self moveSelectionByDelta:kFixedColumns];

  if (command == @selector(pageUp:) ||
      command == @selector(scrollPageUp:))
    return [self moveSelectionByDelta:-kItemsPerPage];

  if (command == @selector(pageDown:) ||
      command == @selector(scrollPageDown:))
    return [self moveSelectionByDelta:kItemsPerPage];

  return NO;
}

@end
