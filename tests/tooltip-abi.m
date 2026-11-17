#import <Foundation/Foundation.h>
#import <dlfcn.h>
BOOL DPTooltipTestScope=YES;
extern void *DPTooltipOriginal;
extern BOOL DPInstallTooltipImport(void);
void DPTooltipTestStart(void) {
    setenv("DIATWEAKS_DOMAIN","com.diapatches.tooltip-abi-test",1);
    NSUserDefaults *prefs=[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches.tooltip-abi-test"];
    [prefs setObject:@"zh-Hans" forKey:@"interfaceLanguage"];
    DPTooltipOriginal=dlsym(RTLD_DEFAULT,"$s7SwiftUI4TextVyACxcSyRzlufC");
    assert(DPTooltipOriginal);
    assert(!DPInstallTooltipImport()); // Wrong executable UUID must fail closed.
}
void DPTooltipTestSetScope(int scope) { DPTooltipTestScope=scope; }
void DPTooltipTestEnd(void) {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:@"com.diapatches.tooltip-abi-test"];
}
