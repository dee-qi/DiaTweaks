#import "Native.h"

void DPMenuTranslate(NSMenu *menu) {
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

static NSInteger DPMenu_indexOfTitle(NSMenu *self, SEL _cmd, NSString *title) {
    NSInteger index = DPCallOriginal(DPMenu_indexOfTitle, self, title);
    if (index < 0) for (NSInteger i = 0; i < self.numberOfItems; i++) {
        NSMenuItem *item = [self itemAtIndex:i];
        if ([DPOriginalText(item, @"title", item.title) isEqual:title]) return i;
    }
    return index;
}

void DPInstallLocalizedMenus(void) {
    DPHookClass(NSMenu.class, @selector(update), (IMP)DPMenu_update);
    DPHookClass(NSMenu.class, @selector(insertItem:atIndex:), (IMP)DPMenu_insert);
    DPHookClass(NSMenu.class, @selector(itemWithTitle:), (IMP)DPMenu_itemWithTitle);
    DPHookClass(NSMenu.class, @selector(indexOfItemWithTitle:), (IMP)DPMenu_indexOfTitle);
    DPHookClass(NSMenuItem.class, @selector(setTitle:), (IMP)DPItem_title);
    DPHookClass(NSMenuItem.class, @selector(setAttributedTitle:), (IMP)DPItem_attributedTitle);
    DPOnLaunch(^{ DPMenuTranslate(NSApp.mainMenu); });
}
