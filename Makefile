# Main Makefile: Orchestrates the project setup.

# Include the other Makefiles
include Makefile.dirs
include Makefile.files

# Default target: creates the entire project structure.
# Running 'make' or 'make all' will execute this target.
.PHONY: all
all: create-dirs create-files

# Clean target: removes all generated directories and files.
.PHONY: clean
clean:
	@echo "Cleaning up generated project structure..."
	@if [ -d ".husky" ]; then rm -rf .husky; fi
	@if [ -d "kubernetes" ]; then rm -rf kubernetes; fi
	@if [ -d ".github" ]; then rm -rf .github; fi
	@if [ -d ".vscode" ]; then rm -rf .vscode; fi
	@if [ -d "public" ]; then rm -rf public; fi
	@if [ -d "src" ]; then rm -rf src; fi
	@if [ -d "supabase" ]; then rm -rf supabase; fi
	@if [ -d "tests" ]; then rm -rf tests; fi
	@if [ -d "docs" ]; then rm -rf docs; fi
	@if [ -d "scripts" ]; then rm -rf scripts; fi
	@if [ -d "tools" ]; then rm -rf tools; fi
	@if [ -d "configs" ]; then rm -rf configs; fi
	@if [ -d "infrastructure" ]; then rm -rf infrastructure; fi
	@if [ -d "monitoring" ]; then rm -rf monitoring; fi
	@if [ -d "security" ]; then rm -rf security; fi
	@if [ -d "backups" ]; then rm -rf backups; fi
	@if [ -d "analytics" ]; then rm -rf analytics; fi
	@if [ -d "integrations" ]; then rm -rf integrations; fi
	@if [ -d "mobile" ]; then rm -rf mobile; fi
	@rm -f .env.local.example .env.example .env.test .env.production .eslintrc.js .gitignore .prettierrc .sentryclirc commitlint.config.js lint-staged.config.js next.config.js package.json pnpm-lock.yaml postcss.config.js README.md release.config.js tailwind.config.ts tsconfig.json tsconfig.build.json vitest.config.ts playwright.config.ts codegen.yml docker-compose.yml Dockerfile Dockerfile.dev
	@echo "Cleanup complete."