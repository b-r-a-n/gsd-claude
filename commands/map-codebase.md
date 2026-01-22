---
name: gsd-map-codebase
description: Analyze and document an existing codebase
args: "[path]"
---

# Map Codebase

You are analyzing an existing codebase to create a comprehensive map for future reference.

## Input

- **Path**: $ARGUMENTS (default: current directory)

## Purpose

Create a codebase map that helps:
- New developers understand the project
- Claude agents work more effectively
- Identify patterns and conventions
- Document technical decisions

## Workflow

### Step 1: Root-Level Analysis

Examine root directory for:

**Configuration Files**
- Package managers: package.json, Cargo.toml, go.mod, requirements.txt, etc.
- Build configs: webpack.config.js, vite.config.ts, tsconfig.json, etc.
- CI/CD: .github/workflows/, .gitlab-ci.yml, Jenkinsfile
- Code quality: .eslintrc, .prettierrc, .editorconfig

**Documentation**
- README files
- CONTRIBUTING guides
- Architecture docs

**Project Type Indicators**
- Framework markers
- Entry points

### Step 2: Directory Structure

Map the directory layout:

```bash
# List directories (read-only)
ls -la
find . -type d -maxdepth 3 | head -50
```

Identify:
- Source code location (src/, lib/, app/)
- Test location (tests/, __tests__/, spec/)
- Assets (public/, static/, assets/)
- Configuration (config/, .config/)
- Documentation (docs/)

### Step 3: Tech Stack Detection

Identify technologies:

| Category | Detection Method |
|----------|------------------|
| Language | File extensions, configs |
| Framework | Dependencies, file patterns |
| Database | Connection strings, ORMs |
| Testing | Test configs, test files |
| CI/CD | Pipeline files |

### Step 4: Architecture Analysis

Identify patterns:

**Code Organization**
- Monolith vs microservices
- Module boundaries
- Layer separation (MVC, Clean Architecture, etc.)

**State Management**
- Global state approach
- Data flow patterns

**API Structure**
- REST, GraphQL, gRPC
- Route organization

### Step 5: Key Files

Identify important files:

- Entry points
- Configuration
- Core modules
- Shared utilities
- Type definitions

### Step 6: Generate Map

Create `.planning/research/codebase-map.md`:

```markdown
# Codebase Map

Generated: [YYYY-MM-DD]
Path: [analyzed path]

## Overview

[1-2 paragraph description of what this codebase does]

## Tech Stack

| Category | Technology | Version | Config File |
|----------|------------|---------|-------------|
| Language | TypeScript | 5.x | tsconfig.json |
| Framework | Next.js | 14.x | next.config.js |
| Database | PostgreSQL | - | prisma/schema.prisma |
| Testing | Jest | 29.x | jest.config.js |
| ...

## Directory Structure

```
[project]/
├── src/                    # Application source
│   ├── app/                # Next.js app router pages
│   ├── components/         # React components
│   │   ├── ui/             # Generic UI components
│   │   └── features/       # Feature-specific components
│   ├── lib/                # Shared libraries
│   ├── hooks/              # Custom React hooks
│   └── types/              # TypeScript types
├── prisma/                 # Database schema and migrations
├── public/                 # Static assets
├── tests/                  # Test files
└── ...
```

## Key Files

| File | Purpose |
|------|---------|
| src/app/layout.tsx | Root layout |
| src/lib/db.ts | Database client |
| src/lib/auth.ts | Authentication |
| ...

## Architecture

### Code Organization
[Description of how code is organized]

### Data Flow
[How data moves through the application]

### Authentication
[How auth works]

### API Structure
[API organization]

## Patterns & Conventions

### Naming
- Components: PascalCase
- Files: kebab-case
- Constants: UPPER_SNAKE_CASE

### File Organization
[How files are organized within directories]

### Code Patterns
[Notable patterns used]

## External Dependencies

### Third-Party Services
| Service | Purpose | Config |
|---------|---------|--------|
| Stripe | Payments | STRIPE_KEY |
| ...

### APIs
| Endpoint | Purpose |
|----------|---------|
| /api/auth | Authentication |
| ...

## Complexity Areas

[Parts of the codebase that are particularly complex]

## Technical Debt

[Observed issues or areas needing attention]

## Notes

[Other relevant observations]
```

### Step 7: Summary

```
✓ Codebase Map Generated

Analyzed: [path]
Tech Stack: [primary language] / [framework]
Files: [count]
Directories: [count]

Key findings:
- [Finding 1]
- [Finding 2]
- [Finding 3]

Map saved: .planning/research/codebase-map.md

Tip: Reference this map when running /gsd-new-project
```

## Guidelines

- Be thorough but efficient
- Focus on structure, not implementation details
- Document patterns, not every instance
- Identify what's unique about this codebase
- Note anything unusual or important
- Keep the map useful for future reference
