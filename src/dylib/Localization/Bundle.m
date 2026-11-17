#import "Native.h"

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


void DPInstallLocalizedBundle(void) {
    DPHookClass(NSBundle.class, @selector(localizedStringForKey:value:table:), (IMP)DPBundle_tooltip);
    DPHookClass(NSBundle.class, @selector(localizedAttributedStringForKey:value:table:), (IMP)DPBundle_tooltipAttributed);
    if (@available(macOS 15.4, *)) DPHookClass(NSBundle.class, @selector(localizedStringForKey:value:table:localizations:), (IMP)DPBundle_tooltipLocales);
}
