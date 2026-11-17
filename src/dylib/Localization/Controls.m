#import "Native.h"

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
             && DPHasAncestor(self, @DPDiaLocaleAddressTableCellView)) value = DPBookmarkCount(value);
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


void DPInstallLocalizedControls(void) {
    DPHook(DPDiaTextWithPlaceholder, @selector(placeholderAttributedString), (IMP)DPPlaceholder_localized);
    DPHookClass(NSView.class, @selector(viewWillDraw), (IMP)DPView_willDraw);
    DPHookClass(NSControl.class, @selector(setStringValue:), (IMP)DPControl_string);
    DPHookClass(NSControl.class, @selector(setAttributedStringValue:), (IMP)DPControl_attributed);
    DPHookClass(NSButton.class, @selector(setTitle:), (IMP)DPButton_title);
    DPHookClass(NSTextField.class, @selector(setPlaceholderString:), (IMP)DPField_placeholder);
    DPHookClass(NSTextField.class, @selector(setPlaceholderAttributedString:), (IMP)DPField_richPlaceholder);
}
