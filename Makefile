# Network Fix: NetworkManager & iwd Conflict Resolution
# Makefile for installation and management

# Variables
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share/network-fix-nm-iwd
DOCDIR = $(PREFIX)/share/doc/network-fix-nm-iwd

# Script files
SCRIPTS = fix-network.sh restore-network.sh check-status.sh
DOCS = README.md CHANGELOG.md CONTRIBUTING.md LICENSE

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m

.PHONY: all install uninstall check clean test help

all: check
	@echo -e "$(GREEN)Network Fix scripts are ready to use$(NC)"
	@echo "Run 'make install' to install system-wide"
	@echo "Run 'make help' for more options"

# Check if all required files exist and have correct permissions
check:
	@echo -e "$(YELLOW)Checking script files...$(NC)"
	@for script in $(SCRIPTS); do \
		if [ ! -f