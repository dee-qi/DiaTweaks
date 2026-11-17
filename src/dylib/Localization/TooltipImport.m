#import "Localization.h"
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach/mach_vm.h>
#import <dlfcn.h>

// Dia 1.57.1 (90935), arm64. Addresses are unslid and intentionally fail
// closed on other builds. These seven Text constructors belong to DiaTooltip.
static const uintptr_t DPTooltipCalls[] = {
    0x101262814, 0x101263628, 0x101263fa0, 0x1012641f4,
    0x10126e1e0, 0x10126e678, 0x10126edd4,
};
static intptr_t DPTooltipSlide;
void *DPTooltipOriginal;
extern void DPRewriteTooltipString(void *, const void *);

void *DPTooltipLookup(const void *source) {
    NSString *text=(__bridge NSString *)source;
    NSString *translated=DPLocalize(text,@"tooltip");
    return [translated isEqualToString:text] ? NULL : (void *)CFBridgingRetain(translated);
}

void DPTooltipPrepare(void *argument, const void *metadata, uintptr_t caller) {
#ifdef DP_TOOLTIP_ABI_TEST
    extern BOOL DPTooltipTestScope;
    if (DPTooltipTestScope) DPRewriteTooltipString(argument,metadata);
#else
    uintptr_t address=caller-DPTooltipSlide-4;
    for (size_t i=0;i<sizeof DPTooltipCalls/sizeof *DPTooltipCalls;i++) {
        if (address==DPTooltipCalls[i]) { DPRewriteTooltipString(argument,metadata); return; }
    }
#endif
}

// Preserve the Swift calling convention, including indirect-result x8 and
// swiftself x20 (callee-saved by C). Tail-call the original initializer, so
// its Text result and ownership behavior are unchanged. No renderer hooks.
__attribute__((naked)) void DPTooltipTextEntry(void) {
    __asm__ volatile(
        "sub sp, sp, #96\n"
        "stp x29, x30, [sp, #80]\n"
        "add x29, sp, #80\n"
        "stp x0, x1, [sp]\n"
        "stp x2, x3, [sp, #16]\n"
        "stp x4, x5, [sp, #32]\n"
        "stp x6, x7, [sp, #48]\n"
        "str x8, [sp, #64]\n"
        "mov x2, x30\n"
        "bl _DPTooltipPrepare\n"
        "ldp x0, x1, [sp]\n"
        "ldp x2, x3, [sp, #16]\n"
        "ldp x4, x5, [sp, #32]\n"
        "ldp x6, x7, [sp, #48]\n"
        "ldr x8, [sp, #64]\n"
        "ldp x29, x30, [sp, #80]\n"
        "add sp, sp, #96\n"
        "adrp x16, _DPTooltipOriginal@PAGE\n"
        "ldr x16, [x16, _DPTooltipOriginal@PAGEOFF]\n"
        "br x16\n");
}

BOOL DPInstallTooltipImport(void) {
    const struct mach_header_64 *header=(const void *)_dyld_get_image_header(0);
    if (!header || header->magic!=MH_MAGIC_64 || header->cputype!=CPU_TYPE_ARM64) return NO;
    const uint8_t expected[16]={0x0e,0xa7,0x85,0xd3,0xf3,0x13,0x3d,0x02,0xa8,0x6f,0x3a,0x1c,0x7b,0xe1,0x59,0x96};
    BOOL matches=NO;
    const struct load_command *command=(const void *)(header+1);
    for (uint32_t i=0;i<header->ncmds;i++) {
        if (command->cmd==LC_UUID) matches=!memcmp(((const struct uuid_command *)command)->uuid,expected,16);
        command=(const void *)((const char *)command+command->cmdsize);
    }
    if (!matches) return NO;
    intptr_t slide=_dyld_get_image_vmaddr_slide(0);
    const uintptr_t stub=0x1066b93f8;
    for (size_t i=0;i<sizeof DPTooltipCalls/sizeof *DPTooltipCalls;i++) {
        uint32_t instruction=*(const uint32_t *)(DPTooltipCalls[i]+slide);
        int64_t offset=((int64_t)(int32_t)(instruction<<6))>>4;
        if ((instruction & 0xfc000000)!=0x94000000 || DPTooltipCalls[i]+offset!=stub) return NO;
    }
    void **slot=(void **)(0x107a67628+slide);
    void *original=dlsym(RTLD_DEFAULT,"$s7SwiftUI4TextVyACxcSyRzlufC");
    if (!original || *slot!=original) return NO;
    mach_vm_address_t page=(uintptr_t)slot & ~((uintptr_t)vm_page_size-1);
    mach_vm_address_t region=page;
    mach_vm_size_t regionSize=0;
    vm_region_basic_info_data_64_t info={0};
    mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object=MACH_PORT_NULL;
    kern_return_t status=mach_vm_region(mach_task_self(),&region,&regionSize,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&object);
    if (object!=MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),object);
    if (status!=KERN_SUCCESS || region>page || region+regionSize<page+vm_page_size) return NO;
    // Only the import data page is changed; no executable instructions patched.
    if (mach_vm_protect(mach_task_self(),page,vm_page_size,FALSE,VM_PROT_READ|VM_PROT_WRITE|VM_PROT_COPY)!=KERN_SUCCESS) return NO;
    DPTooltipSlide=slide;
    DPTooltipOriginal=original;
    __atomic_store_n(slot,(void *)DPTooltipTextEntry,__ATOMIC_RELEASE);
    mach_vm_protect(mach_task_self(),page,vm_page_size,FALSE,info.protection);
    return YES;
}
