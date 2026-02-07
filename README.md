# Clean System Guide

> A collection of battle-tested guides from my journey through Linux system administration and problem-solving.

---

## What is this?

This repository documents my ongoing journey of maintaining a clean, efficient Linux system. Every guide here represents a real problem I faced and solved. This isn't theoretical documentation—it's the accumulated wisdom from actual troubleshooting sessions, broken systems, and hard-won victories.

**Philosophy:** Keep the system clean, stay away from unnecessary dependencies, and understand what you're installing before you install it.

---

## Current Environment

- **Distro:** openSUSE (subject to change as the journey continues)
- **Approach:** Minimal installations, portable apps where possible, manual control over system components
- **Storage:** Self-contained app structure in `/data/itachi/AppImages/`

---

## Guides

### Development Tools
- **[VS Code Without Microsoft's Repo](vscode-installation.md)** - Portable VS Code/VSCodium setup with zero package manager dependencies

*More guides coming as I encounter and solve new problems...*

---

## Why This Exists

**Problem:** Most Linux guides assume you're okay with:
- Adding random third-party repositories
- Installing dependencies you'll never audit
- Trusting package maintainers blindly
- Cluttering your system with automated installers

**Solution:** This repository.

Every guide here prioritizes:
- ✅ **Transparency** - Know exactly what you're installing
- ✅ **Portability** - Self-contained installations where possible
- ✅ **Clean rollback** - Easy to undo if things break
- ✅ **Minimal trust** - Reduce the number of parties you need to trust
- ✅ **Automation-friendly** - Scripts that are readable and modifiable

---

## Structure

Each guide follows a consistent format:
1. **The Problem** - What broke or what I needed to accomplish
2. **The Clean Solution** - How to solve it without polluting the system
3. **Automation** - Scripts to make it repeatable
4. **Alternatives** - Other approaches and why I chose this one

---

## Contributing

Found a better way to solve something? Have a cleaner approach? PRs welcome.

**Rules:**
- Solutions must actually work (no theoretical "this should work" guides)
- Prioritize system cleanliness over convenience
- Explain the *why*, not just the *how*
- No "just trust this random script" submissions

---

## Disclaimer

These guides reflect **my** journey and **my** preferences. Your threat model, use case, and system requirements may differ. Read, understand, and adapt—don't blindly copy-paste.

**This is a living document.** As I learn better approaches, I'll update existing guides. Old solutions that become obsolete won't be deleted—they'll be marked as deprecated with explanations.

---

## License

MIT License - Do whatever you want with these guides. If they help you keep your system clean, that's payment enough.

---

**Status:** Active | **Last Updated:** 2025-02

*"The best system is one you understand completely."*
