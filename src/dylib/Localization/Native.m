#import "Native.h"

void DPInstallLocalizedUI(void) {
    if ([DPLocale() isEqual:@"en"]) return;
    DPInstallLocalizedBundle();
    NSLog(@"[DiaTweaks] Tooltip Text import: %@", DPInstallTooltipImport() ? @"installed" : @"unsupported; skipped");
    DPDiagnostics = [[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] boolForKey:@"localizationDiagnostics"];
    DPInstallLocalizedMenus();
    DPInstallLocalizedControls();
}
