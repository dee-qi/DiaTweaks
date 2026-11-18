#define DP_LOCALIZATION_TEST 1
#import "Localization/Native.h"
#import "StdPatch/Hook.m"
#include <assert.h>
BOOL DPInstallTooltipImport(void) { return NO; }
id DPGet(id o, const void *k) { return objc_getAssociatedObject(o,k); }
void DPSet(id o, const void *k, id v) { objc_setAssociatedObject(o,k,v,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
BOOL DPIsKind(id o, const char *name) { Class cls=objc_getClass(name); return cls && [o isKindOfClass:cls]; }
void DPOnLaunch(void (^block)(void)) {}
@interface TestSplitTargetView : NSView @end
@implementation TestSplitTargetView @end
@interface TestBookmarkTableCellView : NSView @end
@implementation TestBookmarkTableCellView @end
@interface TestAddressTableCellView : NSView @end
@implementation TestAddressTableCellView @end
// Test helper; production never recursively walks a window or newly attached tree.
#ifdef DP_LOCALIZATION_TEST
static void DPTranslateView(NSView *view) {
    DPTranslateViewOnly(view);
    for (NSView *child in view.subviews) DPTranslateView(child);
}

#endif

int main(void) { @autoreleasepool {
    NSString *domain = [@"com.diapatches.localization-test." stringByAppendingString:NSUUID.UUID.UUIDString];
    setenv("DIATWEAKS_DOMAIN", domain.UTF8String, 1);
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:domain];
    [prefs setObject:@"zh-Hans" forKey:@"interfaceLanguage"];
    [NSApplication sharedApplication];
    DPInstallLocalizedUI();
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,400,200) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.identifier = @"preferencesWindow";
    NSPopUpButton *picker = [NSPopUpButton new];
    [picker addItemsWithTitles:@[@"Off", @"12 hours", @"24 hours"]];
    [window.contentView addSubview:picker];
    for (NSInteger i=0;i<picker.numberOfItems;i++) [picker itemAtIndex:i].representedObject=@(i);
    [picker selectItemWithTitle:@"Off"];
    for (int i=0;i<10;i++) DPTranslateView(window.contentView);
    assert(picker.numberOfItems==3);
    assert([picker.title isEqual:@"关闭"]);
    assert([picker.selectedItem.representedObject isEqual:@0]);
    [picker selectItemWithTitle:@"24 hours"];
    assert([picker.title isEqual:@"24 小时"]);
    assert([picker.selectedItem.representedObject isEqual:@2]);
    // No notification or run-loop spin: the pre-draw callback and subsequent
    // assignments must contain translated text. Attachment must not scan a tree.
    NSView *pane=[NSView new];
    NSTextField *firstFrame=[NSTextField labelWithString:@"General"];
    [pane addSubview:firstFrame];
    assert([firstFrame.stringValue isEqual:@"General"]);
    NSTextField *sibling=[NSTextField labelWithString:@"Privacy"];
    [pane addSubview:sibling];
    [window.contentView addSubview:pane];
    assert([firstFrame.stringValue isEqual:@"General"]);
    [firstFrame viewWillDraw];
    assert([sibling.stringValue isEqual:@"Privacy"]); // no sibling/subtree traversal
    assert([firstFrame.stringValue isEqual:@"通用"]);
    firstFrame.stringValue=@"Privacy";
    assert([firstFrame.stringValue isEqual:@"隐私"]);
    firstFrame.attributedStringValue=[[NSAttributedString alloc] initWithString:@"General"];
    assert([firstFrame.stringValue isEqual:@"通用"]);
    assert([DPOriginalText(firstFrame,@"stringValue",firstFrame.stringValue) isEqual:@"General"]);
    NSButton *dynamicButton=[NSButton new]; [pane addSubview:dynamicButton];
    dynamicButton.title=@"New Folder";
    assert([dynamicButton.title isEqual:@"新建文件夹"]);
    NSTextField *editable=[NSTextField new]; [pane addSubview:editable];
    editable.stringValue=@"General"; editable.placeholderString=@"Search";
    assert([editable.stringValue isEqual:@"General"]);
    assert([editable.placeholderString isEqual:@"搜索"]);
    NSTextField *outside=[NSTextField labelWithString:@"General"];
    outside.stringValue=@"Privacy"; assert([outside.stringValue isEqual:@"Privacy"]);
    NSWindow *lateWindow=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,400,200) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    NSTextField *lateLabel=[NSTextField labelWithString:@"Privacy"];
    [lateWindow.contentView addSubview:lateLabel];
    assert([lateLabel.stringValue isEqual:@"Privacy"]);
    lateWindow.identifier=@"preferencesWindow";
    [lateLabel viewWillDraw];
    assert([lateLabel.stringValue isEqual:@"隐私"]);
    // A plain selected sidebar label must not become an attributed white snapshot.
    NSTextField *selectionLabel=[NSTextField labelWithString:@"General"];
    selectionLabel.textColor=NSColor.whiteColor;
    [window.contentView addSubview:selectionLabel];
    [selectionLabel viewWillDraw];
    assert([selectionLabel.stringValue isEqual:@"通用"]);
    assert(![selectionLabel.objectValue isKindOfClass:NSAttributedString.class]);
    selectionLabel.textColor=NSColor.labelColor;
    [selectionLabel viewWillDraw];
    assert([selectionLabel.textColor isEqual:NSColor.labelColor]);
    assert(![selectionLabel.objectValue isKindOfClass:NSAttributedString.class]);
    Class tooltipClass=objc_allocateClassPair(NSView.class, "_TtC10DiaTooltip11TooltipView", 0);
    objc_registerClassPair(tooltipClass);
    NSView *tooltip=[tooltipClass new];
    NSTextField *tip=[NSTextField labelWithString:@"Toggle sidebar"];
    [tooltip addSubview:tip]; [tip viewWillDraw];
    assert([tip.stringValue isEqual:@"切换侧边栏"]);
    tip.stringValue=@"Split tabs";
    assert([tip.stringValue isEqual:@"分屏标签页"]);
    assert([[NSBundle.mainBundle localizedStringForKey:@"Site menu" value:nil table:nil] isEqual:@"网站菜单"]);
    assert([[NSBundle.mainBundle localizedAttributedStringForKey:@"Split tabs" value:nil table:nil].string isEqual:@"分屏标签页"]);
    if (@available(macOS 15.4, *)) assert([[NSBundle.mainBundle localizedStringForKey:@"Toggle sidebar" value:nil table:nil localizations:@[@"en"]] isEqual:@"切换侧边栏"]);
    assert([[NSBundle.mainBundle localizedStringForKey:@"Uncatalogued tooltip" value:nil table:nil] isEqual:@"Uncatalogued tooltip"]);
    assert([DPLocalize(@"Automatic Picture-In-Picture", @"menu") isEqual:@"自动画中画"]);
    assert([DPLocalize(@"Site Settings", @"menu") isEqual:@"网站设置"]);
    assert([DPLocalize(@"Connection is secure", @"menu") isEqual:@"连接安全"]);
    // Installer reasons reach Software Update verbatim; translate the wrapper only.
    NSString *reason = @"the download holds build 199, not 200";
    assert([DPLocalize([@"Couldn’t verify this version: " stringByAppendingString:reason], @"tweaks")
        isEqual:[@"无法验证此版本：" stringByAppendingString:reason]]);
    assert([DPLocalize(@"Couldn’t patch this version: /Users/test/Dia.app: Code 6 %2$@", @"tweaks")
        isEqual:@"无法修补此版本：/Users/test/Dia.app: Code 6 %2$@"]);
    assert([DPLocalize(@"Couldn’t verify this version: User title", @"website")
        isEqual:@"Couldn’t verify this version: User title"]);
    Class errorClass=objc_allocateClassPair(NSViewController.class, "TestNativeErrorViewController", 0);
    objc_registerClassPair(errorClass);
    NSViewController *errorController=[errorClass new];
    NSView *errorRoot=[NSView new]; errorController.view=errorRoot;
    errorRoot.nextResponder=errorController;
    NSTextField *errorTitle=[NSTextField labelWithString:@"This tab needs to reload"];
    [errorRoot addSubview:errorTitle]; [errorTitle viewWillDraw];
    assert([errorTitle.stringValue isEqual:@"此标签页需要重新加载"]);
    NSTextField *errorCode=[NSTextField labelWithString:@"Code 6"];
    [errorRoot addSubview:errorCode]; [errorCode viewWillDraw];
    assert([errorCode.stringValue isEqual:@"错误代码 6"]);
    assert([[NSBundle.mainBundle localizedStringForKey:@"This chat isn’t available here" value:nil table:nil] isEqual:@"此聊天在当前设备上不可用"]);
    NSTextField *webText=[NSTextField labelWithString:@"This tab needs to reload"];
    [webText viewWillDraw];
    assert([webText.stringValue isEqual:@"This tab needs to reload"]);
    Class welcomeClass=objc_allocateClassPair(NSView.class, "NewTabPage.ConnectAppsUpsellView", 0);
    objc_registerClassPair(welcomeClass);
    NSView *welcome=[welcomeClass new];
    NSTextField *welcomeLabel=[NSTextField labelWithString:@"Connect Slack and Google to get started."];
    [welcome addSubview:welcomeLabel]; [welcomeLabel viewWillDraw];
    assert([welcomeLabel.stringValue isEqual:@"连接 Slack 和 Google，开始使用。"]);
    NSMutableAttributedString *footnote=[[NSMutableAttributedString alloc] initWithString:@"Use other apps? Connect others or dismiss."];
    NSURL *connectURL=[NSURL URLWithString:@"dia-test://connect"], *dismissURL=[NSURL URLWithString:@"dia-test://dismiss"];
    [footnote addAttribute:NSLinkAttributeName value:connectURL range:[footnote.string rangeOfString:@"Connect others"]];
    [footnote addAttribute:NSLinkAttributeName value:dismissURL range:[footnote.string rangeOfString:@"dismiss"]];
    NSAttributedString *localizedFootnote=DPRichTranslation(footnote,@"newtab");
    assert([localizedFootnote.string containsString:@"连接更多"]);
    assert([[localizedFootnote attribute:NSLinkAttributeName atIndex:[localizedFootnote.string rangeOfString:@"连接更多"].location effectiveRange:NULL] isEqual:connectURL]);
    assert([[localizedFootnote attribute:NSLinkAttributeName atIndex:[localizedFootnote.string rangeOfString:@"关闭"].location effectiveRange:NULL] isEqual:dismissURL]);
    assert([[NSBundle.mainBundle localizedStringForKey:@"Open Dia’s Settings." value:nil table:nil] isEqual:@"打开 Dia 的设置。"]);
    assert([[NSBundle.mainBundle localizedStringForKey:@"Create a new tab inside the current tab group, or a regular new tab if not in a group." value:nil table:nil] isEqual:@"在当前标签组内新建标签页；如果当前标签页不属于任何分组，则新建普通标签页。"]);
    assert([[NSBundle.mainBundle localizedStringForKey:@"Switch to Profile 9." value:nil table:nil] isEqual:@"切换到个人资料 9。"]);
    NSMenu *menu=[NSMenu new];
    NSMenuItem *command=[[NSMenuItem alloc] initWithTitle:@"Move to Window" action:NULL keyEquivalent:@"w"];
    [menu addItem:command];
    assert([command.title isEqual:@"移至窗口"]);
    command.title=@"Edit Pinned Page";
    assert([command.title isEqual:@"编辑固定页面"]);
    assert([menu itemWithTitle:@"Edit Pinned Page"]==command);
    assert([command.keyEquivalent isEqual:@"w"]);
    NSTextField *input=[NSTextField new]; input.stringValue=@"General";
    input.placeholderAttributedString=[[NSAttributedString alloc] initWithString:@"Search" attributes:@{NSForegroundColorAttributeName:NSColor.secondaryLabelColor}];
    [window.contentView addSubview:input]; DPTranslateView(input);
    assert([input.stringValue isEqual:@"General"]);
    assert([input.placeholderAttributedString.string isEqual:@"搜索"]);
    assert([[input.placeholderAttributedString attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL] isEqual:NSColor.secondaryLabelColor]);
    NSTextField *label=[NSTextField labelWithString:@"General"];
    [window.contentView addSubview:label]; DPTranslateView(label);
    assert([label.stringValue isEqual:@"通用"]);
    assert([DPOriginalText(label,@"stringValue",label.stringValue) isEqual:@"General"]);
    assert([DPLocalize(@"Switch to Profile 1 — Work %2$@", @"menu") isEqual:@"切换至个人资料 1 — Work %2$@"]);
    assert([DPLocalize(@"Yesterday at 23:04", @"settings") isEqual:@"昨天 23:04"]);
    TestSplitTargetView *split=[TestSplitTargetView new];
    NSTextField *left=[NSTextField labelWithString:@"Add left split"];
    NSTextField *right=[NSTextField labelWithString:@"Add right split"];
    [split addSubview:left]; [split addSubview:right];
    DPTranslateView(split);
    assert([left.stringValue isEqual:@"添加左侧分屏"]);
    assert([right.stringValue isEqual:@"添加右侧分屏"]);
    assert([DPBookmarkCount(@"0 items") isEqual:@"0 项"]);
    assert([DPBookmarkCount(@"1 item") isEqual:@"1 项"]);
    assert([DPBookmarkCount(@"125 items") isEqual:@"125 项"]);
    assert([DPBookmarkCount(@"https://example.com/2 items") isEqual:@"https://example.com/2 items"]);
    TestBookmarkTableCellView *userCell=[TestBookmarkTableCellView new];
    NSTextField *userTitle=[NSTextField labelWithString:@"Bookmarks"];
    [userCell addSubview:userTitle]; [window.contentView addSubview:userCell];
    DPTranslateView(userCell); assert([userTitle.stringValue isEqual:@"Bookmarks"]);
    NSMutableAttributedString *linked=[[NSMutableAttributedString alloc] initWithString:@"Block common components found across the web by using additional rules and filters. "];
    [linked appendAttributedString:[[NSAttributedString alloc] initWithString:@"Learn more" attributes:@{NSLinkAttributeName:@"https://example.com/help"}]];
    NSAttributedString *translated=DPRichTranslation(linked,@"settings");
    assert([translated.string containsString:@"使用额外的规则"]);
    NSRange link=[translated.string rangeOfString:@"了解更多"];
    assert(link.location!=NSNotFound);
    assert([[translated attribute:NSLinkAttributeName atIndex:link.location effectiveRange:NULL] isEqual:@"https://example.com/help"]);
    assert([translated attribute:NSLinkAttributeName atIndex:0 effectiveRange:NULL]==nil);
    command.attributedTitle=[[NSAttributedString alloc] initWithString:@"Recently Visited"];
    assert([command.attributedTitle.string isEqual:@"最近访问"]);
    [NSUserDefaults.standardUserDefaults removePersistentDomainForName:domain];
    puts("localization-native: popup count, source selection, values, editable text and original labels passed");
} }
