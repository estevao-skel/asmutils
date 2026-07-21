NASM   := nasm
LD     := ld
STRIP  := strip

AFLAGS := -f elf64 -O3

LFLAGS := -static -nostdlib -n -N \
          --build-id=none \
          --no-dynamic-linker \
          --no-eh-frame-hdr \
          --no-ld-generated-unwind-info \
          -z norelro \
          --hash-style=sysv \
          --gc-sections

SFLAGS := -s \
          -R .comment \
          -R .gnu.version \
          -R .gnu.version_r \
          -R .gnu.hash \
          -R .note \
          -R .note.gnu.build-id \
          -R .note.ABI-tag \
          -R .eh_frame \
          -R .eh_frame_hdr

SRCDIR := src
OBJDIR := obj
BINDIR := bin

PREFIX  := /usr/local
DESTDIR :=

UTILS := cat chmod chown clear cp dd df echo free gatito grep \
         head id kill ls lsblk mkdir mke2fs mount mv \
         nice ps reboot rm sh sync tail time touch \
         uname uptime wc whoami install part sleep test

BINS := $(addprefix $(BINDIR)/,$(UTILS))
OBJS := $(addprefix $(OBJDIR)/,$(addsuffix .o,$(UTILS)))

.PHONY: all install clean size

all: $(BINDIR) $(OBJDIR) $(BINS)

SHTSTRIP := python3 tools/shtstrip.py

$(BINDIR)/%: $(OBJDIR)/%.o
	$(LD) $(LFLAGS) -o $@ $< 2>&1 | grep -v 'RWX\|has RWX' || true
	$(STRIP) $(SFLAGS) $@ 2>/dev/null || true
	@$(SHTSTRIP) $@ > /dev/null

$(OBJDIR)/%.o: $(SRCDIR)/%.asm
	$(NASM) $(AFLAGS) -o $@ $< 2>/dev/null

$(BINDIR) $(OBJDIR):
	mkdir -p $@

install: all
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(BINS) $(DESTDIR)$(PREFIX)/bin/

clean:
	rm -rf $(OBJDIR) $(BINDIR)

size: all
	@echo "Binary sizes:"
	@printf "%-12s %8s  %s\n" NAME BYTES TARGET
	@printf "%-12s %8s  %s\n" ---- ----- ------
	@for b in $(BINS); do \
	    name=$$(basename $$b); \
	    sz=$$(stat -c%s "$$b"); \
	    if   [ $$sz -le 1024 ];     then tag="< 1KB  ✓"; \
	    elif [ $$sz -le 2048 ];     then tag="< 2KB  ✓"; \
	    else                             tag="> 2KB"; fi; \
	    printf "%-12s %8d  %s\n" "$$name" "$$sz" "$$tag"; \
	done | sort -k2 -n

.PHONY: $(UTILS)
$(UTILS): %: $(BINDIR)/%
