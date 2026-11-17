#import "Localization.h"
#import "Settings/Settings.h"

@interface DPLanguagePicker : NSPopUpButton
@end
@implementation DPLanguagePicker
- (void)chooseLanguage:(id)sender {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    [prefs setObject:self.selectedItem.representedObject forKey:@"interfaceLanguage"];
    [prefs synchronize];
    NSAlert *alert = [NSAlert new];
    alert.messageText = DPLocalized(@"language.restart", @"Relaunch Dia to change the language");
    alert.informativeText = DPLocalized(@"language.restartDetail", @"The interface and preferred website language will change the next time Dia opens.");
    [alert addButtonWithTitle:DPLocalized(@"language.relaunch", @"Relaunch")];
    [alert addButtonWithTitle:DPLocalized(@"language.later", @"Later")];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) DPHandOffAndQuit(@[@"apply"]);
    }];
}
@end

NSView *DPLanguageRow(void) {
    DPLanguagePicker *picker = [DPLanguagePicker new];
    NSMutableArray *keys = [NSMutableArray arrayWithObject:@"system"];
    NSMutableArray *names = [NSMutableArray arrayWithObject:DPLocalized(@"language.system", @"Follow System")];
    for (NSDictionary *language in DPSupportedLanguages()) { [keys addObject:language[@"id"]]; [names addObject:language[@"name"]]; }
    for (NSUInteger i = 0; i < keys.count; i++) {
        [picker addItemWithTitle:names[i]];
        picker.lastItem.representedObject = keys[i];
    }
    NSString *chosen = [[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] stringForKey:@"interfaceLanguage"] ?: @"system";
    for (NSMenuItem *item in picker.itemArray) if ([item.representedObject isEqual:chosen]) [picker selectItem:item];
    picker.target = picker;
    picker.action = @selector(chooseLanguage:);
    picker.accessibilityLabel = DPLocalized(@"language.patchTitle", @"Language Patch");
    return DPRow(DPLabel(picker.accessibilityLabel, 13, NSFontWeightRegular, NSColor.labelColor), picker);
}
