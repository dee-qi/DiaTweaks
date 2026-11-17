#import "Localization.h"
#import "StdPatch/StdPatch.h"

static char DPSourceKey;
static BOOL DPTranslating, DPDiagnostics;

NSString *DPOriginalText(id object, NSString *property, NSString *current) {
    NSDictionary *record = DPGet(object, &DPSourceKey)[property];
    return [record[@"shown"] isEqual:current] ? record[@"source"] : current;
}

static NSString *DPTranslate(id object, NSString *property, NSString *text, NSString *context) {
    NSString *source = DPOriginalText(object, property, text);
    NSString *shown = DPLocalize(source, context);
    if ([shown isEqual:source] && source.length && DPDiagnostics) {
        // Never log text: even native settings can contain account names or user titles.
        static NSMutableSet *reported;
        if (!reported) reported = [NSMutableSet new];
        NSString *site = [NSString stringWithFormat:@"%@.%@ (%@)", NSStringFromClass([object class]), property, context];
        if (![reported containsObject:site]) { [reported addObject:site]; NSLog(@"DiaTweaks localization: untranslated text at %@", site); }
    }
    NSMutableDictionary *records = DPGet(object, &DPSourceKey);
    if (!records) DPSet(object, &DPSourceKey, records = [NSMutableDictionary new]);
    records[property] = @{@"source": source ?: @"", @"shown": shown ?: @""};
    return shown;
}

// Translate linked runs separately so the link remains on its own translated label.
static NSAttributedString *DPRichTranslation(NSAttributedString *source, NSString *context) {
    if (!source.length) return source;
    __block BOOL linked = NO;
    [source enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, source.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) { if (value) linked = YES; }];
    NSMutableAttributedString *result = [source mutableCopy];
    if (!linked) {
        NSString *shown = DPLocalize(source.string, context);
        if (![shown isEqual:source.string]) [result replaceCharactersInRange:NSMakeRange(0, result.length) withString:shown];
        return result;
    }
    [source enumerateAttributesInRange:NSMakeRange(0, source.length) options:NSAttributedStringEnumerationReverse usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        NSString *part = [source.string substringWithRange:range];
        NSRange core = [part rangeOfString:[part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
        if (!core.length) return;
        NSString *original = [part substringWithRange:core], *shown = DPLocalize(original, context);
        if (![shown isEqual:original]) [result replaceCharactersInRange:NSMakeRange(range.location + core.location, core.length) withString:shown];
    }];
    return result;
}

static BOOL DPHasAncestor(NSView *view, NSString *fragment) {
    for (NSView *ancestor = view; ancestor; ancestor = ancestor.superview)
        if ([NSStringFromClass(ancestor.class) containsString:fragment]) return YES;
    return NO;
}

static NSString *DPBookmarkCount(NSString *source) {
    static NSRegularExpression *rule;
    if (!rule) rule = [NSRegularExpression regularExpressionWithPattern:@"^([0-9]+) items?$" options:0 error:nil];
    NSTextCheckingResult *match = [rule firstMatchInString:source options:0 range:NSMakeRange(0, source.length)];
    return match ? [NSString stringWithFormat:DPLocalized(@"bookmarks.itemCount", @"%@ items"), [source substringWithRange:[match rangeAtIndex:1]]] : source;
}

static BOOL DPSettingsWindow(NSWindow *window) {
    return [window.identifier isEqual:@"preferencesWindow"] || [window.accessibilityIdentifier isEqual:@"preferencesWindow"]
        || [NSStringFromClass(window.windowController.class) containsString:@"Preferences"];
}
static BOOL DPBookmarksTab(NSView *view) {
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

static BOOL DPSettingsView(NSView *view) {
    if (DPBookmarksTab(view)) return YES;
    // NativeError uses ordinary AppKit labels under its view controller.
    for (NSView *ancestor = view; ancestor; ancestor = ancestor.superview)
        if ([NSStringFromClass(ancestor.nextResponder.class) containsString:@"NativeErrorViewController"]) return YES;
    if (DPHasAncestor(view, @"_TtC14AssistantPanel24AssistantPanelHeaderView")
        || [view.accessibilityIdentifier isEqual:@"commandBarToolbarButton"]) return YES;
    if (DPHasAncestor(view, @"ChatPlaceholderMessageView") || DPHasAncestor(view, @"AssistantPanel.ContextBundleUpsellView")) return YES;
    if (DPHasAncestor(view, @"NewTabPage.ConnectAppsUpsellView")
        || DPHasAncestor(view, @"NewTabPage.ConnectAppRowView")) return YES;
    if (DPHasAncestor(view, @"BookmarkTableCellView") || DPHasAncestor(view, @"AddressTableCellView")) return NO;
    if (DPSettingsWindow(view.window) || view.window.sheetParent) return YES;
    // Dia's shortcut-aware hover cards live outside the browser window.
    // Limit adaptation to its tooltip containers, not webpage tooltips.
    if (DPHasAncestor(view, @"_TtC10DiaTooltip11TooltipView")
        || DPHasAncestor(view, @"_TtC10ArcTooltip11TooltipView")
        || DPHasAncestor(view, @"_TtC14TooltipRequest18TooltipRequestView")) return YES;
    for (NSView *ancestor = view; ancestor; ancestor = ancestor.superview)
        if (DPIsKind(ancestor, DPDiaNewTabButton) || DPIsKind(ancestor, DPDiaTabSurfaceButton)
            || DPIsKind(ancestor, DPDiaCapabilityButton) || DPIsKind(ancestor, DPDiaLibraryButton)
            || DPIsKind(ancestor, DPDiaLibraryCell)) return YES;
    for (NSView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        NSString *name = NSStringFromClass(ancestor.class);
        if ([name containsString:@"LibraryItemCellView"] || [name containsString:@"RecentTabView"]) return NO;
        if ([name containsString:@"BookmarksPageView"] || [name containsString:@"SplitTargetView"]
            || [name containsString:@"BookmarkInterstitialView"] || [name containsString:@"LibraryFilter"] || [name containsString:@"LibrarySearchField"]
            || [name containsString:@"LibrarySectionHeader"] || [name containsString:@"LibraryEmptyState"]
            || [name containsString:@"TabOverflowMenuContentView"] || [name containsString:@"MenuSearchField"] || [name containsString:@"CustomInsetSearchField"]) return YES;
    }
    return [view.accessibilityIdentifier hasPrefix:@"navigationBar"] && [view isKindOfClass:NSButton.class];
}

static void DPTranslateViewOnly(NSView *view) {
    NSString *name = NSStringFromClass(view.class);
    if (DPIsKind(view, DPDiaTabView) && DPBookmarksTab(view)) {
        NSString *title = view.accessibilityTitle;
        if (title.length) view.accessibilityTitle = DPTranslate(view, @"accessibilityTitle", title, @"settings");
    }
    if ([name containsString:@"BookmarksPageView"] && [view.window.title isEqual:@"Bookmarks"]) view.window.title = DPLocalize(@"Bookmarks", @"settings");
    if ([name containsString:@"RenderWidget"] || [name containsString:@"WKWebView"]) return;
    if ([view isKindOfClass:NSTextField.class] && DPHasAncestor(view, @"AddressTableCellView")) {
        NSTextField *field = (id)view;
        if (!field.isEditable) { NSString *shown = DPBookmarkCount(field.stringValue); if (![shown isEqual:field.stringValue]) field.stringValue = shown; }
    }
    if (!DPSettingsView(view)) {
        return;
    }
    if ([view isKindOfClass:NSTableView.class]) {
        for (NSTableColumn *column in [(NSTableView *)view tableColumns]) {
            NSString *title = DPLocalize(column.headerCell.stringValue, @"settings");
            if (![title isEqual:column.headerCell.stringValue]) column.headerCell.stringValue = title;
        }
    }
    if ([view isKindOfClass:NSTextField.class]) {
        NSTextField *field = (id)view;
        NSAttributedString *attributedPlaceholder = field.placeholderAttributedString;
        NSString *placeholder = DPLocalize(attributedPlaceholder.string ?: field.placeholderString, @"settings");
        if (attributedPlaceholder && ![placeholder isEqual:attributedPlaceholder.string]) {
            NSMutableAttributedString *rich = [attributedPlaceholder mutableCopy];
            [rich replaceCharactersInRange:NSMakeRange(0, rich.length) withString:placeholder];
            field.placeholderAttributedString = rich;
        }
        if (!attributedPlaceholder && placeholder && ![placeholder isEqual:field.placeholderString]) field.placeholderString = placeholder;
    }
    if ([view isKindOfClass:NSTextField.class] && ![(NSTextField *)view isEditable]) {
        NSTextField *field = (id)view;
        NSString *text = DPTranslate(field, @"stringValue", field.stringValue, @"settings");
        // attributedStringValue synthesizes attributes even for a plain label.
        // Writing that snapshot back freezes its current selection color. Keep
        // plain controls plain so Dia/AppKit can update their selection styling.
        if (![field.objectValue isKindOfClass:NSAttributedString.class]) {
            if (![text isEqual:field.stringValue]) field.stringValue = text;
        } else {
            NSAttributedString *translated = DPRichTranslation(field.attributedStringValue, @"settings");
            if (![translated isEqualToAttributedString:field.attributedStringValue]) field.attributedStringValue = translated;
        }
    }
    if ([view isKindOfClass:NSTextView.class] && ![(NSTextView *)view isEditable]) {
        NSTextView *text = (id)view;
        NSString *shown = DPTranslate(text, @"string", text.string, @"settings");
        NSAttributedString *translated = DPRichTranslation(text.textStorage, @"settings");
        if (![shown isEqual:text.string]) [text.textStorage replaceCharactersInRange:NSMakeRange(0, text.string.length) withString:shown];
        else if (![translated isEqualToAttributedString:text.textStorage]) [text.textStorage setAttributedString:translated];
    }
    if ([view isKindOfClass:NSPopUpButton.class]) {
        for (NSMenuItem *item in [(NSPopUpButton *)view itemArray]) {
            NSString *title = DPTranslate(item, @"title", item.title, @"settings");
            if (![title isEqual:item.title]) item.title = title;
        }
    }
    if ([view isKindOfClass:NSButton.class] && ![view isKindOfClass:NSPopUpButton.class]) {
        NSButton *button = (id)view;
        NSString *title = DPTranslate(button, @"title", button.title, @"settings");
        if (![title isEqual:button.title]) button.title = title;
    }
    NSString *label = view.accessibilityLabel;
    if (label.length) {
        NSString *shown = DPTranslate(view, @"accessibilityLabel", label, @"settings");
        if (![shown isEqual:label]) view.accessibilityLabel = shown;
    }
    if (view.toolTip.length) view.toolTip = DPTranslate(view, @"toolTip", view.toolTip, @"settings");
}

// Test helper; production never recursively walks a window or newly attached tree.
#ifdef DP_LOCALIZATION_TEST
static void DPTranslateView(NSView *view) {
    DPTranslateViewOnly(view);
    for (NSView *child in view.subviews) DPTranslateView(child);
}

#endif

static void DPMenuTranslate(NSMenu *menu) {
    for (NSMenuItem *item in menu.itemArray) {
        // Catalog contains static commands only, never arbitrary substring replacements.
        NSString *title = DPTranslate(item, @"title", item.title, @"menu");
        if (![title isEqual:item.title]) item.title = title;
        if (item.submenu) DPMenuTranslate(item.submenu);
    }
}

static void DPMenu_update(NSMenu *self, SEL _cmd) {
    DPCallOriginal(DPMenu_update, self);
    DPMenuTranslate(self);
}
static void DPMenu_insert(NSMenu *self, SEL _cmd, NSMenuItem *item, NSInteger index) {
    DPCallOriginal(DPMenu_insert, self, item, index);
    // Translate only after construction; representedObject and actions remain untouched.
    NSString *title = DPTranslate(item, @"title", item.title, @"menu");
        if (![title isEqual:item.title]) item.title = title;
}
static NSMenuItem *DPMenu_itemWithTitle(NSMenu *self, SEL _cmd, NSString *title) {
    NSMenuItem *item = DPCallOriginal(DPMenu_itemWithTitle, self, title);
    if (!item) for (NSMenuItem *candidate in self.itemArray)
        if ([DPOriginalText(candidate, @"title", candidate.title) isEqual:title]) return candidate;
    return item;
}

static void DPItem_attributedTitle(NSMenuItem *self, SEL _cmd, NSAttributedString *title) {
    DPCallOriginal(DPItem_attributedTitle, self, DPRichTranslation(title, @"menu"));
}

static void DPItem_title(NSMenuItem *self, SEL _cmd, NSString *title) {
    DPCallOriginal(DPItem_title, self, DPTranslate(self, @"title", title, @"menu"));
}

static NSAttributedString *DPPlaceholder_localized(NSView *self, SEL _cmd) {
    NSAttributedString *source = DPCallOriginal(DPPlaceholder_localized, self);
    if (!DPSettingsView(self) && ![self.accessibilityIdentifier isEqual:@"commandBarTextField"]) {
        // Only the placeholder getter, never the editor contents or chat response.
        return DPRichTranslation(source, @"chat");
    }
    NSString *text = DPLocalize(source.string, @"settings");
    if (!source || [text isEqual:source.string]) return source;
    NSMutableAttributedString *translated = [source mutableCopy];
    [translated replaceCharactersInRange:NSMakeRange(0, translated.length) withString:text];
    return translated;
}

static NSInteger DPMenu_indexOfTitle(NSMenu *self, SEL _cmd, NSString *title) {
    NSInteger index = DPCallOriginal(DPMenu_indexOfTitle, self, title);
    if (index < 0) for (NSInteger i = 0; i < self.numberOfItems; i++) {
        NSMenuItem *item = [self itemAtIndex:i];
        if ([DPOriginalText(item, @"title", item.title) isEqual:title]) return i;
    }
    return index;
}


// AppKit calls this on views participating in the upcoming display. Translate
// only the current native control, never its descendants or the whole window.
static void DPView_willDraw(NSView *self, SEL _cmd) {
    DPCallOriginal(DPView_willDraw, self);
    if (DPTranslating) return;
    if (![self isKindOfClass:NSControl.class] && ![self isKindOfClass:NSTextView.class]
        && !DPIsKind(self, DPDiaTabView)) return;
    DPTranslating = YES;
    @try { DPTranslateViewOnly(self); }
    @finally { DPTranslating = NO; }
}
static BOOL DPTranslateControlValue(NSControl *control) {
    return !DPTranslating && [control isKindOfClass:NSTextField.class]
        && ![(NSTextField *)control isEditable] && DPSettingsView(control);
}
static void DPControl_string(NSControl *self, SEL _cmd, NSString *value) {
    if (DPTranslateControlValue(self)) value = DPTranslate(self, @"stringValue", value, @"settings");
    else if (!DPTranslating && [self isKindOfClass:NSTextField.class] && ![(NSTextField *)self isEditable]
             && DPHasAncestor(self, @"AddressTableCellView")) value = DPBookmarkCount(value);
    DPCallOriginal(DPControl_string, self, value);
}
static void DPControl_attributed(NSControl *self, SEL _cmd, NSAttributedString *value) {
    if (DPTranslateControlValue(self)) {
        DPTranslate(self, @"stringValue", value.string, @"settings");
        value = DPRichTranslation(value, @"settings");
    }
    DPCallOriginal(DPControl_attributed, self, value);
}
static void DPButton_title(NSButton *self, SEL _cmd, NSString *title) {
    if (!DPTranslating && ![self isKindOfClass:NSPopUpButton.class] && DPSettingsView(self))
        title = DPTranslate(self, @"title", title, @"settings");
    DPCallOriginal(DPButton_title, self, title);
}
static void DPField_placeholder(NSTextField *self, SEL _cmd, NSString *value) {
    if (!DPTranslating && DPSettingsView(self)) value = DPLocalize(value, @"settings");
    DPCallOriginal(DPField_placeholder, self, value);
}
static void DPField_richPlaceholder(NSTextField *self, SEL _cmd, NSAttributedString *value) {
    if (!DPTranslating && DPSettingsView(self)) value = DPRichTranslation(value, @"settings");
    DPCallOriginal(DPField_richPlaceholder, self, value);
}

// SwiftUI tooltip content requests localized resources instead of NSTextField
// values. Only exact catalogued tooltip keys from Dia's main bundle qualify.
static NSString *DPBundle_tooltip(NSBundle *self, SEL _cmd, NSString *key, NSString *value, NSString *table) {
    NSString *original = DPCallOriginal(DPBundle_tooltip, self, key, value, table);
    if (self != NSBundle.mainBundle) return original;
    return DPLocalize(DPLocalize(DPLocalize(DPLocalize(DPLocalize(original, @"tooltip"), @"newtab"), @"shortcut"), @"chat"), @"native-error");
}

static NSString *DPBundle_tooltipLocales(NSBundle *self, SEL _cmd, NSString *key, NSString *value, NSString *table, NSArray *localizations) {
    NSString *original = DPCallOriginal(DPBundle_tooltipLocales, self, key, value, table, localizations);
    return self == NSBundle.mainBundle ? DPLocalize(DPLocalize(DPLocalize(DPLocalize(DPLocalize(original, @"tooltip"), @"newtab"), @"shortcut"), @"chat"), @"native-error") : original;
}
static NSAttributedString *DPBundle_tooltipAttributed(NSBundle *self, SEL _cmd, NSString *key, NSString *value, NSString *table) {
    NSAttributedString *original = DPCallOriginal(DPBundle_tooltipAttributed, self, key, value, table);
    return self == NSBundle.mainBundle ? DPRichTranslation(DPRichTranslation(DPRichTranslation(DPRichTranslation(DPRichTranslation(original, @"tooltip"), @"newtab"), @"shortcut"), @"chat"), @"native-error") : original;
}

extern BOOL DPInstallTooltipImport(void);

void DPInstallLocalizedUI(void) {
    if ([DPLocale() isEqual:@"en"]) return;
    DPHookClass(NSBundle.class, @selector(localizedStringForKey:value:table:), (IMP)DPBundle_tooltip);
    DPHookClass(NSBundle.class, @selector(localizedAttributedStringForKey:value:table:), (IMP)DPBundle_tooltipAttributed);
    if (@available(macOS 15.4, *)) DPHookClass(NSBundle.class, @selector(localizedStringForKey:value:table:localizations:), (IMP)DPBundle_tooltipLocales);
    NSLog(@"[DiaTweaks] Tooltip Text import: %@", DPInstallTooltipImport() ? @"installed" : @"unsupported; skipped");
    DPDiagnostics = [[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] boolForKey:@"localizationDiagnostics"];
    DPHookClass(NSMenu.class, @selector(update), (IMP)DPMenu_update);
    DPHookClass(NSMenu.class, @selector(insertItem:atIndex:), (IMP)DPMenu_insert);
    DPHookClass(NSMenu.class, @selector(itemWithTitle:), (IMP)DPMenu_itemWithTitle);
    DPHookClass(NSMenu.class, @selector(indexOfItemWithTitle:), (IMP)DPMenu_indexOfTitle);
    DPHookClass(NSMenuItem.class, @selector(setTitle:), (IMP)DPItem_title);
    DPHook("_TtC5ARCUI23TextViewWithPlaceholder", @selector(placeholderAttributedString), (IMP)DPPlaceholder_localized);
    DPHookClass(NSMenuItem.class, @selector(setAttributedTitle:), (IMP)DPItem_attributedTitle);
    DPOnLaunch(^{ DPMenuTranslate(NSApp.mainMenu); });
    DPHookClass(NSView.class, @selector(viewWillDraw), (IMP)DPView_willDraw);
    DPHookClass(NSControl.class, @selector(setStringValue:), (IMP)DPControl_string);
    DPHookClass(NSControl.class, @selector(setAttributedStringValue:), (IMP)DPControl_attributed);
    DPHookClass(NSButton.class, @selector(setTitle:), (IMP)DPButton_title);
    DPHookClass(NSTextField.class, @selector(setPlaceholderString:), (IMP)DPField_placeholder);
    DPHookClass(NSTextField.class, @selector(setPlaceholderAttributedString:), (IMP)DPField_richPlaceholder);
}
