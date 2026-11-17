#import "Native.h"

void DPTranslateViewOnly(NSView *view) {
    NSString *name = NSStringFromClass(view.class);
    if (DPIsKind(view, DPDiaTabView) && DPBookmarksTab(view)) {
        NSString *title = view.accessibilityTitle;
        if (title.length) view.accessibilityTitle = DPTranslate(view, @"accessibilityTitle", title, @"settings");
    }
    if ([name containsString:@DPDiaLocaleBookmarksPageView] && [view.window.title isEqual:@"Bookmarks"]) view.window.title = DPLocalize(@"Bookmarks", @"settings");
    if ([name containsString:@"RenderWidget"] || [name containsString:@"WKWebView"]) return;
    if ([view isKindOfClass:NSTextField.class] && DPHasAncestor(view, @DPDiaLocaleAddressTableCellView)) {
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

