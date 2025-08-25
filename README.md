# PhatPKG

Create universal macOS installer packages from separate ARM64 and Intel x86_64 applications.

![PhatPKG Banner](https://github.com/gilburns/PhatPKG/wiki/images/phatpkg-logo.png)

## What is PhatPKG?

PhatPKG combines your ARM64 (Apple Silicon) and Intel x86_64 app versions into a single universal installer package (`.pkg`) that automatically installs the correct version based on the user's Mac architecture.

**✅ One package for both architectures**  
**✅ Automatic architecture detection**  
**✅ Professional installer experience**  
**✅ GUI and CLI versions included**

## Supported Formats

- Application bundles (`.app`)
- ZIP archives (`.zip`) 
- Disk images (`.dmg`)
- Tar bzip2 archives (`.tar.bz2`, `.tbz`)
- Bzip2 files (`.bz2`)
- HTTPS URLs to any of the above

## Quick Start

1. **Download** the latest release
2. **Install** PhatPKG.app to Applications
3. **Launch** and select your ARM64 and Intel apps
4. **Create** your universal package!

For command-line usage:
```bash
PhatPKG-CLI --arm64 MyApp-arm64.zip --intel MyApp-intel.zip --output ~/Desktop
```

## Requirements

- macOS 13.5 or later
- Administrator privileges (for testing installations)

## Documentation

📚 **[Visit the Wiki](https://github.com/gilburns/PhatPKG/wiki)** for complete guides:
- **[GUI Guide](https://github.com/gilburns/PhatPKG/wiki/GUI-Guide)** - Step-by-step visual instructions
- **[CLI Guide](https://github.com/gilburns/PhatPKG/wiki/CLI-Guide)** - Command-line reference and automation

## Support

- 🐛 [Report Issues](../../issues)
- 💡 [Request Features](../../issues/new)

---

*PhatPKG makes universal macOS app distribution simple and professional.*