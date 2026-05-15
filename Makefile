PROJECT_ROOT := $(shell pwd)
VERSION_FILE := $(PROJECT_ROOT)/VERSION
APP_ZON      := $(PROJECT_ROOT)/app.zon
DESKTOP_FILE := $(HOME)/.local/share/applications/switchboard.desktop
ICON_TARGET  := $(HOME)/.local/share/icons/switchboard.png
ICON_SOURCE  := $(PROJECT_ROOT)/assets/icon.png
ZIG          := $(shell which zig)
BUMP         := $(PROJECT_ROOT)/scripts/bump-build.sh

.DEFAULT_GOAL := help

.PHONY: help build run dev rebuild clean sync package install uninstall version bump-major bump-minor bump-patch commit _sync-zon

help:
	@echo "Switchboard Makefile targets:"
	@echo ""
	@echo "  make build         bump BUILD, sync app.zon, then zig build"
	@echo "  make run           build, then zig build run"
	@echo "  make dev           zig build dev (no version bump)"
	@echo "  make rebuild       clean + build"
	@echo "  make clean         remove zig-out/, .zig-cache/, frontend/.next/, frontend/out/"
	@echo "  make sync          run ~/bin/switchboard-sync"
	@echo "  make package       zig build package"
	@echo "  make install       install desktop entry + icon (idempotent)"
	@echo "  make uninstall     remove desktop entry + icon"
	@echo "  make version       print current version"
	@echo "  make bump-major    bump MAJOR, reset MINOR/PATCH/BUILD"
	@echo "  make bump-minor    bump MINOR, reset PATCH/BUILD"
	@echo "  make bump-patch    bump PATCH, reset BUILD"
	@echo "  make commit        stage all + commit (interactive message, refuses 'claude')"

version:
	@cat $(VERSION_FILE)

# Internal: sync a version into app.zon's .version field.
# Accepts V= as override; falls back to current VERSION_FILE contents.
_sync-zon:
	@v="$(V)"; \
	if [ -z "$$v" ]; then v="$$(tr -d '[:space:]' < $(VERSION_FILE))"; fi; \
	sed -i.bak.makesync 's/\.version = "[^"]*"/.version = "'"$$v"'"/' $(APP_ZON); \
	rm -f $(APP_ZON).bak.makesync; \
	echo "synced app.zon -> $$v"

build:
	@set -e; \
	OLD_V="$$(tr -d '[:space:]' < $(VERSION_FILE))"; \
	NEW_V="$$($(BUMP) $(VERSION_FILE))"; \
	echo "VERSION bumped -> $$NEW_V"; \
	$(MAKE) --no-print-directory _sync-zon V=$$NEW_V; \
	if ! $(ZIG) build; then \
		echo "zig build failed — rolling VERSION back to $$OLD_V"; \
		printf '%s\n' "$$OLD_V" > $(VERSION_FILE); \
		$(MAKE) --no-print-directory _sync-zon V=$$OLD_V; \
		exit 1; \
	fi; \
	echo "built $$NEW_V"

run: build
	@$(ZIG) build run

dev:
	@$(ZIG) build dev

rebuild: clean build

clean:
	@rm -rf $(PROJECT_ROOT)/zig-out $(PROJECT_ROOT)/.zig-cache \
		$(PROJECT_ROOT)/frontend/.next $(PROJECT_ROOT)/frontend/out
	@echo "cleaned build artifacts"

sync:
	@$(HOME)/bin/switchboard-sync

package:
	@$(ZIG) build package

install:
	@mkdir -p $(HOME)/.local/share/icons $(HOME)/.local/share/applications
	@if [ -f "$(ICON_SOURCE)" ]; then \
		cp -f "$(ICON_SOURCE)" "$(ICON_TARGET)"; \
		echo "icon -> $(ICON_TARGET)"; \
	else \
		echo "warn: $(ICON_SOURCE) missing, skipping icon copy"; \
	fi
	@if [ ! -f "$(DESKTOP_FILE)" ]; then \
		printf '%s\n' \
			'[Desktop Entry]' \
			'Name=Switchboard' \
			'Comment=Claude Code CLI toolkit dashboard' \
			'Exec=bash -c "cd $(PROJECT_ROOT) && $(ZIG) build run"' \
			'Icon=$(ICON_TARGET)' \
			'Terminal=false' \
			'Type=Application' \
			'Categories=Development;Utility;' \
			'StartupWMClass=claude-feature-flag-app' \
			> "$(DESKTOP_FILE)"; \
		echo "desktop entry -> $(DESKTOP_FILE)"; \
	else \
		echo "desktop entry exists: $(DESKTOP_FILE) (not overwriting)"; \
	fi
	@command -v update-desktop-database >/dev/null 2>&1 && \
		update-desktop-database "$(HOME)/.local/share/applications" >/dev/null 2>&1 || true
	@echo "note: COSMIC dock favorites are managed separately; pin via the dock UI."

uninstall:
	@rm -f "$(DESKTOP_FILE)" "$(ICON_TARGET)"
	@command -v update-desktop-database >/dev/null 2>&1 && \
		update-desktop-database "$(HOME)/.local/share/applications" >/dev/null 2>&1 || true
	@echo "removed $(DESKTOP_FILE) and $(ICON_TARGET)"
	@echo "note: COSMIC dock favorites are managed separately; unpin via the dock UI."

bump-major:
	@v="$$(tr -d '[:space:]' < $(VERSION_FILE))"; \
	IFS=. read -r maj min pat bld <<<"$$v"; \
	new="$$((maj+1)).0.0.0"; \
	echo "$$new" > $(VERSION_FILE); \
	echo "VERSION -> $$new"
	@$(MAKE) --no-print-directory _sync-zon

bump-minor:
	@v="$$(tr -d '[:space:]' < $(VERSION_FILE))"; \
	IFS=. read -r maj min pat bld <<<"$$v"; \
	new="$$maj.$$((min+1)).0.0"; \
	echo "$$new" > $(VERSION_FILE); \
	echo "VERSION -> $$new"
	@$(MAKE) --no-print-directory _sync-zon

bump-patch:
	@v="$$(tr -d '[:space:]' < $(VERSION_FILE))"; \
	IFS=. read -r maj min pat bld <<<"$$v"; \
	new="$$maj.$$min.$$((pat+1)).0"; \
	echo "$$new" > $(VERSION_FILE); \
	echo "VERSION -> $$new"
	@$(MAKE) --no-print-directory _sync-zon

commit:
	@git add -A
	@read -r -p "commit message: " msg; \
	lower=$$(printf '%s' "$$msg" | tr '[:upper:]' '[:lower:]'); \
	case "$$lower" in \
		*claude*) echo "refused: commit message must not reference 'claude'"; exit 1 ;; \
	esac; \
	if git -c commit.gpgsign=true commit -S -m "$$msg"; then \
		echo "signed commit ok"; \
	else \
		echo "signed commit failed — load your SSH key (e.g. 'ssh-add ~/.ssh/id_ed25519' or unlock 1Password) and retry"; \
		exit 1; \
	fi
