#import "Native.h"

BOOL DPHasAncestor(NSView *view, NSString *fragment) {
    for (NSView *ancestor = view; ancestor; ancestor = ancestor.superview)
        if ([NSStringFromClass(ancestor.class) containsString:fragment]) return YES;
    return NO;
}

NSString *DPBookmarkCount(NSString *source) {
    static NSRegularExpression *rule;
    if (!rule) rule = [NSRegularExpression regularExpressionWithPattern:@"^([0-9]+) items?$" options:0 error:nil];
    NSTextCheckingResult *match = [rule firstMatchInString:source options:0 range:NSMakeRange(0, source.length)];
    return match ? [NSString stringWithFormat:DPLocalized(@"bookmarks.itemCount", @"%@ items"), [source substringWithRange:[match rangeAtIndex:1]]] : source;
}

static BOOL DPSettingsWindow(NSWindow *window) {
    return [window.identifier isEqual:@"preferencesWindow"] || [window.accessibilityIdentifier isEqual:@"preferencesWindow"]
        || [NSStringFromClass(window.windowController.class) containsString:@DPDiaLocalePreferences];
}
BOOL DPBookmarksTab(NSView *view) {
    for (NSView *tab = view; tab; tab = tab.superview) {
        if (!DPIsKind(tab, DPDiaTabView)) continue;
        if (!DPTextMatches(tab.accessibilityLabel ?: tab.accessibilityTitle, @"Bookmarks")) return NO;
        BOOL split = NO;
        for (NSAccessibilityCustomAction *action in tab.accessibilityCustomActions) {
            if ([action.name isEqual:@"Pin"] || [action.name isEqual:@"Unpin"] || [action.name isEqual:@"Pin as Tab"]) return NO;
            if ([action.name isEqual:@"Open as Split"]) split = YES;
        }
        return split;
    }
    return NO;
}

BOOL DPSettingsView(NSView *view) {
    if (DPBookmarksTab(view)) return YES;
    // NativeError uses ordinary AppKit labels under its view controller.
    for (NSView *ancestor = view; ancestor; ancestor = ancestor.superview)
        if ([NSStringFromClass(ancestor.nextResponder.class) containsString:@DPDiaLocaleNativeErrorViewController]) return YES;
    if (DPHasAncestor(view, @DPDiaChatHeader)
        || [view.accessibilityIdentifier isEqual:@"commandBarToolbarButton"]) return YES;
    if (DPHasAncestor(view, @DPDiaLocaleChatPlaceholderMessageView) || DPHasAncestor(view, @DPDiaLocaleAssistantPanelContextBundleUpsellView)) return YES;
    if (DPHasAncestor(view, @DPDiaLocaleNewTabPageConnectAppsUpsellView)
        || DPHasAncestor(view, @DPDiaLocaleNewTabPageConnectAppRowView)) return YES;
    if (DPHasAncestor(view, @DPDiaLocaleBookmarkTableCellView) || DPHasAncestor(view, @DPDiaLocaleAddressTableCellView)) return NO;
    if (DPSettingsWindow(view.window) || view.window.sheetParent) return YES;
    // Dia's shortcut-aware hover cards live outside the browser window.
    // Limit adaptation to its tooltip containers, not webpage tooltips.
    if (DPHasAncestor(view, @DPDiaTooltip)
        || DPHasAncestor(view, @DPDiaArcTooltip)
        || DPHasAncestor(view, @DPDiaTooltipRequest)) return YES;
    for (NSView *ancestor = view; ancestor; ancestor = ancestor.superview)
        if (DPIsKind(ancestor, DPDiaNewTabButton) || DPIsKind(ancestor, DPDiaTabSurfaceButton)
            || DPIsKind(ancestor, DPDiaCapabilityButton) || DPIsKind(ancestor, DPDiaLibraryButton)
            || DPIsKind(ancestor, DPDiaLibraryCell)) return YES;
    for (NSView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        NSString *name = NSStringFromClass(ancestor.class);
        if ([name containsString:@DPDiaLocaleLibraryItemCellView] || [name containsString:@DPDiaLocaleRecentTabView]) return NO;
        if ([name containsString:@DPDiaLocaleBookmarksPageView] || [name containsString:@DPDiaLocaleSplitTargetView]
            || [name containsString:@DPDiaLocaleBookmarkInterstitialView] || [name containsString:@DPDiaLocaleLibraryFilter] || [name containsString:@DPDiaLocaleLibrarySearchField]
            || [name containsString:@DPDiaLocaleLibrarySectionHeader] || [name containsString:@DPDiaLocaleLibraryEmptyState]
            || [name containsString:@DPDiaLocaleTabOverflowMenuContentView] || [name containsString:@DPDiaLocaleMenuSearchField] || [name containsString:@DPDiaLocaleCustomInsetSearchField]) return YES;
    }
    return [view.accessibilityIdentifier hasPrefix:@"navigationBar"] && [view isKindOfClass:NSButton.class];
}

