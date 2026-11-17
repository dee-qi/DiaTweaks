#import "Localization.h"
#include <assert.h>
static uint32_t Read(const uint8_t *p) { uint32_t v; memcpy(&v,p,4); return v; }
int main(void) { @autoreleasepool {
    // Two resources and one alias; no vendor data in the test fixture.
    uint8_t fixture[] = {5,0,0,0,1,0,0,0,2,0,1,0, 1,0,34,0,0,0, 2,0,37,0,0,0, 0,0,40,0,0,0, 3,0,0,0, 'O','n','e','T','w','o'};
    NSData *input = [NSData dataWithBytes:fixture length:sizeof fixture];
    NSData *output = DPTranslateLocalePack(input, @{@"One": @"一"});
    assert(output && output.length == input.length);
    assert([DPTranslateLocalePack(output, @{@"One":@"一"}) isEqual:output]);
    const uint8_t *p = output.bytes;
    assert(Read(p+20)==37 && Read(p+26)==40);
    assert(!memcmp(p+30, fixture+30,4)); // alias index preserved
    assert(!memcmp(p+37,"Two",3));
    assert([DPTranslateLocalePack(input, @{}) isEqual:input]);
    assert(!DPTranslateLocalePack([input subdataWithRange:NSMakeRange(0,20)], @{}));
    fixture[20]=2;
    assert(!DPTranslateLocalePack([NSData dataWithBytes:fixture length:sizeof fixture], @{}));
    NSDictionary *hints = @{@"zh-cn": @{@"Hint": @"提示"}};
    NSString *fixtureJS = @"const marker='--hint-image-width'; label(t.hint.title); title(t.hint.title); subtitle(t.hint.subtitle); response(message.text);";
    NSString *patched = DPTranslateChatHints(fixtureJS, hints);
    assert([patched containsString:@"label(__dpHintText(t.hint.title))"]);
    assert([patched containsString:@"response(message.text)"]);
    assert([DPTranslateChatHints(patched, hints) isEqual:patched]);
    assert([DPTranslateChatHints(@"title(t.hint.title); response(message.text)", hints) isEqual:@"title(t.hint.title); response(message.text)"]);
    puts("locale-pack: offsets, aliases, untouched bytes, idempotence and corrupt input passed");
} }
