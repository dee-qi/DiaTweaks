CFLAGS := -arch arm64 -mmacosx-version-min=14.0 -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter
DYLIB_SOURCES := $(shell find src/dylib -name '*.[hm]')
DYLIB_SWIFT := $(shell find src/dylib -name '*.swift')
SDK := $(shell xcrun --show-sdk-path)
SWIFT_LIB := $(SDK)/usr/lib/swift
# FoundationModels is macOS 26+ only: weak-link it, stop Swift auto-linking it, and skip it when the SDK lacks it.
FOUNDATION_MODELS := $(if $(wildcard $(SDK)/System/Library/Frameworks/FoundationModels.framework),-weak_framework FoundationModels)
SWIFTFLAGS := -target arm64-apple-macos14.0 -O -parse-as-library -wmo -module-name DiaPatchesSwift \
	-Xfrontend -disable-autolink-framework -Xfrontend FoundationModels
PASSKEYS := src/dylib/Patches/Passkeys/extension
EXTENSION := $(foreach file,manifest.json page.js bridge.js worker.js,-Wl,-sectcreate,__TEXT,__pk_$(basename $(file)),$(PASSKEYS)/$(file))

COMMIT := $(shell git rev-parse HEAD 2>/dev/null)

all: build/diapatch build/DiaPatches.dylib build/patches.json

build/commit: FORCE | build
	@echo '$(COMMIT)' | cmp -s - $@ || echo '$(COMMIT)' > $@

FORCE:

build/diapatch: $(wildcard src/diapatch/*.[hm]) build/commit build/Catalog.inc | build
	clang $(CFLAGS) -Ibuild -DDIATWEAKS_COMMIT='"$(COMMIT)"' -framework AppKit -framework CoreGraphics -framework Security -o $@ $(filter %.m,$^)

build/DiaPatchesSwift.o: $(DYLIB_SWIFT) | build
	swiftc $(SWIFTFLAGS) -emit-object -o $@ $^

DYLIB_OBJECTS := $(patsubst src/dylib/%.m,build/obj/%.o,$(filter %.m,$(DYLIB_SOURCES)))

build/obj/%.o: src/dylib/%.m $(filter %.h,$(DYLIB_SOURCES))
	@mkdir -p $(dir $@)
	clang $(CFLAGS) -Isrc/dylib -Ibuild -c -o $@ $<

build/obj/Localization/Catalog.o: build/Catalog.inc

build/DiaPatches.dylib: $(DYLIB_OBJECTS) build/DiaPatchesSwift.o $(wildcard $(PASSKEYS)/*) | build
	clang $(CFLAGS) -Isrc/dylib -Ibuild -dynamiclib $(EXTENSION) -framework AppKit -framework QuartzCore -framework Metal -framework AVFoundation -framework VideoToolbox -framework CoreMedia -framework CoreVideo \
		-L$(SWIFT_LIB) -Wl,-rpath,/usr/lib/swift $(FOUNDATION_MODELS) -o $@ $(filter %.o,$^)

# With DIAPATCH_MANIFEST set, the dylib writes the patch list and exits as it loads, so diapatch never runs.
build/patches.json: build/DiaPatches.dylib build/diapatch
	DIAPATCH_MANIFEST=$@ DYLD_INSERT_LIBRARIES=$< build/diapatch

build:
	mkdir -p $@

GROUP_TABS := $(addprefix src/dylib/Commands/GroupTabs/,Plan.m Title.m Registrable.m Messages.m)

build/group-tabs: tests/group-tabs.m $(GROUP_TABS) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ $^

build/mouse-back-forward: tests/mouse-back-forward.m src/dylib/Patches/MouseBackForward/MouseBackForward.m src/dylib/StdPatch/Hook.m $(wildcard src/dylib/StdPatch/*.h) | build
	clang $(CFLAGS) -Isrc/dylib -framework AppKit -o $@ tests/mouse-back-forward.m src/dylib/StdPatch/Hook.m

SPLIT := src/dylib/Patches/SplitClientHello

build/split-client-hello: tests/split-client-hello.m $(wildcard $(SPLIT)/Split.[hm] $(SPLIT)/Write.[hm]) | build
	clang $(CFLAGS) -fsanitize=address,undefined -fno-sanitize-recover=all -Isrc/dylib -framework Foundation -o $@ \
		tests/split-client-hello.m $(SPLIT)/Split.m $(SPLIT)/Write.m

build/vertical-tab-glow: tests/vertical-tab-glow.m src/dylib/Localization/Catalog.m build/Catalog.inc $(wildcard src/dylib/Patches/HideVerticalTabGlow/*.[hm]) | build
	clang $(CFLAGS) -Isrc/dylib -Ibuild -framework AppKit -framework QuartzCore -o $@ $< src/dylib/Localization/Catalog.m

check: build/diapatch build/group-tabs build/mouse-back-forward build/vertical-tab-glow build/split-client-hello build/patches.json
	tests/tweaks-update
	build/group-tabs
	build/mouse-back-forward
	build/vertical-tab-glow
	build/split-client-hello
	tests/sidebar-grain
	scripts/check-patches

test: build/DiaPatches.dylib
	./test.sh

patch:
	@scripts/new-patch "$(NAME)"

clean:
	rm -rf build

.PHONY: all check clean test patch

build/Catalog.inc: $(wildcard locales/*/*.json) locales/languages.json scripts/build-localizations | build
	scripts/build-localizations

build/localization: tests/localization.m src/dylib/Localization/Catalog.m build/Catalog.inc | build
	clang $(CFLAGS) -Isrc/dylib -Ibuild -framework AppKit -o $@ $(filter %.m,$^)

check: check-localization
check-localization: build/localization build/locale-pack
	scripts/build-localizations --check
	build/localization
	build/locale-pack
.PHONY: check-localization

build/locale-pack: tests/locale-pack.m src/diapatch/Localization.m build/Catalog.inc | build
	clang $(CFLAGS) -Isrc/diapatch -Ibuild -framework Foundation -o $@ $(filter %.m,$^)

build/localization-native: tests/localization-native.m src/dylib/Localization/Native.m src/dylib/Localization/Catalog.m build/Catalog.inc | build
	clang $(CFLAGS) -Isrc/dylib -Ibuild -framework AppKit -framework QuartzCore -o $@ tests/localization-native.m src/dylib/Localization/Catalog.m
check-localization-native: build/localization-native
	build/localization-native
check: check-localization-native
.PHONY: check-localization-native

build/tooltip-abi.o: src/dylib/Localization/TooltipImport.m
	clang $(CFLAGS) -DDP_TOOLTIP_ABI_TEST -Isrc/dylib -Ibuild -c -o $@ $<

build/tooltip-test.o: tests/tooltip-abi.m
	clang $(CFLAGS) -c -o $@ $<

build/localization-tooltip: tests/localization-tooltip.swift src/dylib/Localization/Tooltip.swift build/tooltip-abi.o build/tooltip-test.o build/obj/Localization/Catalog.o
	swiftc -O -parse-as-library -framework AppKit -o $@ $^

check: check-localization-tooltip
check-localization-tooltip: build/localization-tooltip
	build/localization-tooltip
.PHONY: check-localization-tooltip
