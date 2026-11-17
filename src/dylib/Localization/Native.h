#pragma once
#import "Localization.h"
#import "StdPatch/StdPatch.h"

extern BOOL DPTranslating, DPDiagnostics;
NSString *DPTranslate(id object, NSString *property, NSString *text, NSString *context);
NSAttributedString *DPRichTranslation(NSAttributedString *source, NSString *context);
BOOL DPHasAncestor(NSView *view, NSString *fragment);
NSString *DPBookmarkCount(NSString *source);
BOOL DPBookmarksTab(NSView *view);
BOOL DPSettingsView(NSView *view);
void DPTranslateViewOnly(NSView *view);
void DPMenuTranslate(NSMenu *menu);
void DPInstallLocalizedMenus(void);
void DPInstallLocalizedControls(void);
void DPInstallLocalizedBundle(void);
BOOL DPInstallTooltipImport(void);
