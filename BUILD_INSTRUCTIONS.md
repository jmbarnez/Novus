# Building Space Drone Adventure into a .love File

## Quick Start

### Option 1: Simple Build (Recommended)
1. Double-click `BUILD_SIMPLE.bat`
2. Wait for the build to complete
3. The `.love` file will be created in the `dist/` folder

### Option 2: Detailed Build
1. Double-click `BUILD.bat` for additional information and colored output
2. Watch the build process
3. The `.love` file will be created in the `dist/` folder

---

## What is a .love File?

A `.love` file is a ZIP archive containing your entire LÖVE project. It's a single file that can be:
- Run by double-clicking (if LÖVE is installed and associated)
- Distributed to other players
- Executed on Windows, macOS, or Linux (as long as LÖVE is installed)

---

## Prerequisites

### LÖVE Framework
You need LÖVE 11.3 installed on your system.

**Download from**: https://love2d.org

1. Download LÖVE 11.3
2. Run the installer
3. When prompted, associate `.love` files with LÖVE

### Build Tool (One of the following)

#### Option A: 7-Zip (Recommended)
- More reliable and faster
- Download from: https://www.7-zip.org
- Installation adds 7z command to PATH

#### Option B: PowerShell
- Built-in to Windows 10+
- Requires no additional installation

---

## Running the Build Script

### Windows 10/11
1. Navigate to your project folder in File Explorer
2. Double-click `BUILD.bat` or `BUILD_SIMPLE.bat`
3. The script will:
   - Check for required tools
   - Create a `dist/` folder
   - Compress your project into a `.love` file
   - Display the completion message

### Running from Command Prompt
```cmd
cd C:\Users\YourName\Desktop\test2
BUILD.bat
```

Or for the simple version:
```cmd
BUILD_SIMPLE.bat
```

---

## What Gets Included in the .love File

The build script includes:
- ✅ `conf.lua` - LÖVE configuration
- ✅ `main.lua` - Game entry point
- ✅ `README.md` - Project documentation
- ✅ `GEMINI.md` - AI documentation
- ✅ `docs/` - All documentation
- ✅ `src/` - All source code
- ✅ `assets/` - All assets (fonts, etc.)

Excluded:
- ❌ `.git/` - Git repository
- ❌ `dist/` - Build output folder
- ❌ Other `.love` files

---

## Running the Game

### Method 1: Double-Click (Easiest)
1. Open `dist/` folder
2. Double-click `space-drone-adventure.love`
3. Game launches!

### Method 2: Drag and Drop
1. Locate LÖVE's `love.exe`
2. Drag `space-drone-adventure.love` onto `love.exe`
3. Game launches!

### Method 3: Command Line
```cmd
"C:\Program Files\LÖVE\love.exe" space-drone-adventure.love
```

### Method 4: Associate .love Files
If `.love` files aren't associated:
1. Right-click a `.love` file
2. Select "Open with..."
3. Choose "LÖVE (love.exe)"
4. Check "Always use this app"
5. Now you can double-click any `.love` file

---

## Distributing Your Game

Once you have the `.love` file:

1. **For Windows Players**:
   - Share the `.love` file
   - They need LÖVE 11.3 installed
   - They can double-click to run

2. **Cross-Platform**:
   - Same `.love` file works on Windows, macOS, Linux
   - Just needs LÖVE installed on each platform

3. **Creating Standalone Executables**:
   - You can wrap the `.love` file with `love.exe` for true .exe
   - Use tools like `fuse` or create a batch wrapper
   - (Advanced topic - not covered here)

---

## Troubleshooting

### Issue: "love.exe is not recognized"
**Solution**: Make sure LÖVE is in your PATH
- Reinstall LÖVE and check "Add to PATH"
- Or manually add `C:\Program Files\LÖVE` to PATH

### Issue: "7z is not recognized"
**Solution**: 7-Zip isn't in PATH
- Option A: Reinstall 7-Zip, check "Add to PATH"
- Option B: Use BUILD.bat instead (tries PowerShell)
- The script will automatically fall back to PowerShell

### Issue: "PowerShell is not recognized"
**Solution**: Rare, but try:
- Update Windows
- Run Command Prompt as Administrator
- Try 7-Zip instead

### Issue: .love file won't open
**Solutions**:
1. Right-click → "Open with..." → Choose LÖVE
2. Install LÖVE 11.3 specifically
3. Verify file size > 100KB (not corrupted)

### Issue: Game crashes on startup
**Debugging**:
1. Run from command line to see error messages:
   ```cmd
   "C:\Program Files\LÖVE\love.exe" space-drone-adventure.love 2>&1
   ```
2. Check error logs
3. Ensure all source files are included in the .love file

---

## Advanced: Manual .love Creation

If the batch scripts don't work, you can manually create the .love file:

### Using 7-Zip:
```cmd
7z a -tzip space-drone-adventure.love conf.lua main.lua README.md GEMINI.md docs src assets
```

### Using PowerShell:
```powershell
Compress-Archive -Path 'conf.lua','main.lua','README.md','GEMINI.md','docs','src','assets' -DestinationPath 'space-drone-adventure.love'
```

### Using Windows Explorer:
1. Select all files and folders
2. Right-click → Send to → Compressed (zipped) folder
3. Rename the `.zip` to `.love`

---

## Development Workflow

During development:
1. Run the game directly: `love .` from project folder
2. Edit and test
3. When ready to distribute, run BUILD.bat
4. Test the `.love` file
5. Share or archive

For quick distribution updates:
1. Make your code changes
2. Run BUILD.bat again
3. The old `.love` file is automatically replaced

---

## Tips and Tricks

### Reduce File Size
- Remove debug files before building
- Compress art assets
- Remove comments from production code

### Faster Builds
- Use 7-Zip instead of PowerShell (faster compression)
- Only include necessary files
- Consider using `love fuse` for .exe wrapping

### Multiple Versions
- Keep old builds: Rename dist/space-drone-adventure.love to space-drone-adventure-v1.0.love
- Version your builds for rollback capability

---

## Support

If you encounter issues:
1. Check LÖVE documentation: https://love2d.org/wiki
2. Verify your project structure matches the original
3. Ensure all required libraries are included in `src/`
4. Test with the uncompressed version first (`love .`)

