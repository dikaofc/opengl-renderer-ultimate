# Contributing to OpenGL Renderer Ultimate

Thanks for your interest in contributing! This guide will help you get started.

---

## Development Setup

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| **Git** | 2.30+ | Version control |
| **Bash** | 4.0+ | Shell scripts |
| **Node.js** | 18+ | WebUI JS validation |
| **ShellCheck** | Latest | Shell linting |
| **Android device** | 7.0+ with root | Testing |

### Clone & Setup

```bash
# Clone the repo
git clone https://github.com/dikaofc/opengl-renderer-ultimate.git
cd opengl-renderer-ultimate

# Make scripts executable
chmod -R +x *.sh scripts/*.sh META-INF/com/google/android/update-binary

# Validate syntax
bash -n *.sh scripts/*.sh
node --check webroot/app.js
```

### Project Structure

```
.
├── META-INF/                    # Magisk/KernelSU installer
│   └── com/google/android/
│       ├── update-binary        # Installer entry point
│       └── updater-script       # #MAGISK header
├── module.prop                  # Module metadata (id, name, version)
├── customize.sh                 # Installation script
├── post-fs-data.sh              # Early boot (before animation)
├── service.sh                   # Late boot (after services)
├── uninstall.sh                 # Cleanup on removal
├── opengl.sh                    # Standalone OpenGL apply
├── scripts/
│   ├── functions.sh             # Shared helpers (log, sp, detect, config)
│   ├── default.conf             # Default config values
│   ├── apply_cpu.sh             # CPU governor, freq, scheduler
│   ├── apply_gpu.sh             # GPU vendor-specific (Adreno/Mali/Xclipse)
│   ├── apply_ram.sh             # RAM, ZRAM, KSM, I/O, THP
│   ├── apply_kernel.sh          # Kernel sysctl, scheduler
│   ├── apply_network.sh         # TCP, buffers, WiFi
│   ├── apply_thermal.sh         # Thermal zones, throttling
│   ├── apply_overclock.sh       # Max CPU+GPU+Bus+I/O
│   ├── apply_profile.sh         # Profile save/load/delete/export
│   ├── apply_gamemode.sh        # Game presets + app scanner
│   ├── benchmark.sh             # CPU/RAM/GPU/IO benchmarks
│   ├── auto_detect.sh           # Hardware detection + recommendations
│   └── dashboard.sh             # System status JSON
├── webroot/
│   ├── index.html               # WebUI (12 tabs, SVG icons)
│   ├── style.css                # Neo-Brutalism theme
│   └── app.js                   # WebUI logic (KernelSU API)
└── .github/
    └── workflows/
        └── build.yml            # CI: auto-build flashable ZIP
```

---

## Code Style

### Shell Scripts

```bash
# Use lowercase for variables
my_var="value"

# Use UPPER_CASE for constants
CONSTANT="value"

# Use descriptive function names
apply_cpu_preset() {
    # ...
}

# Always quote variables
echo "$my_var"

# Use [[ ]] for tests, not [ ]
if [[ "$var" == "value" ]]; then
    # ...
fi

# Use $(command) not `command`
result=$(command)

# Always handle errors
command 2>/dev/null || true

# Log important actions
log "apply_cpu: Starting CPU optimization"

# Use write_sys for sysfs writes
write_sys "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" "performance"

# Use sp for setprop
sp "debug.hwui.renderer" "skiagl"
```

### WebUI (HTML/CSS/JS)

```javascript
// Use const/let, never var
const MODDIR = '/data/adb/modules/opengl_renderer_ultimate';

// Use async/await for shell calls
async function loadConfig() {
    const raw = await shell(`cat ${CONF_FILE} 2>/dev/null`);
    // ...
}

// Escape HTML for user content
element.textContent = escapeHtml(userInput);

// Use template literals for HTML generation
container.innerHTML = `
    <div class="card">
        <span>${escapeHtml(name)}</span>
    </div>
`;
```

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Shell functions | snake_case | `apply_cpu_preset` |
| Shell variables | snake_case | `cpu_max_freq` |
| JS functions | camelCase | `loadDashboard` |
| JS constants | UPPER_SNAKE | `MODDIR` |
| CSS classes | kebab-case | `dash-stat-card` |
| Config keys | snake_case | `cpu_governor` |
| HTML IDs | snake_case | `cpu_max_freq` |

---

## Adding a New Feature

### 1. New Shell Script

```bash
# Create the script
cat > scripts/apply_my_feature.sh << 'EOF'
#!/system/bin/sh
MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

log "apply_my_feature: Starting..."

# Your logic here
write_sys "/some/sysfs/path" "value"

log "apply_my_feature: Done"
EOF

chmod +x scripts/apply_my_feature.sh
```

### 2. New WebUI Tab

**HTML** — Add tab button:
```html
<button class="tab" data-tab="myfeature">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
        <!-- SVG icon path -->
    </svg>
    <span class="tab-label">My Feature</span>
</button>
```

**HTML** — Add tab content:
```html
<section class="tab-content" id="tab-myfeature">
    <h2>My Feature</h2>
    <!-- Controls here -->
</section>
```

**JS** — Add logic:
```javascript
async function myFeatureAction() {
    setStatus('Working...', 'warning');
    const result = await shell(`${MODDIR}/scripts/apply_my_feature.sh`);
    setStatus(result.includes('OK') ? 'Done!' : 'Error', result.includes('OK') ? 'success' : 'error');
}
```

### 3. New Game Preset

**In `apply_gamemode.sh`:**
```bash
# Add to detect_running_game()
*my.game.package*)
    echo "my.game.package"
    return
    ;;

# Add to get_game_genre()
*my.game.package*)
    echo "battle_royale"  # or moba, open_world, fps, racing, casual
    ;;
```

**In `app.js`:**
```javascript
const GAME_PRESETS = [
    // ... existing presets
    { name: 'My Game', pkg: 'com.my.game', genre: 'battle_royale' },
];
```

### 4. New Config Option

**In `scripts/default.conf`:**
```bash
# My new setting (description)
my_new_setting=default_value
```

**In WebUI:**
```html
<div class="control-row">
    <label>My New Setting</label>
    <input type="number" id="my_new_setting" value="default_value">
</div>
```

The WebUI auto-reads/writes config keys matching element IDs.

---

## Testing

### Local Testing (with ADB)

```bash
# Connect device via ADB
adb devices

# Push module to device
adb push . /sdcard/opengl_renderer_ultimate/

# Test scripts via ADB shell
adb shell su -c "sh /sdcard/opengl_renderer_ultimate/scripts/apply_cpu.sh"
adb shell su -c "sh /sdcard/opengl_renderer_ultimate/scripts/benchmark.sh all"

# Build and flash
cd /sdcard/opengl_renderer_ultimate
zip -r9 /sdcard/test_module.zip . -x ".git/*"
# Flash via KernelSU Manager
```

### CI Testing

Every push triggers:
1. **Shell syntax check** — `bash -n` on all `.sh` files
2. **JS syntax check** — `node --check webroot/app.js`
3. **ShellCheck lint** — Static analysis for shell scripts
4. **ZIP build** — Full flashable ZIP creation
5. **Artifact upload** — Downloadable for manual testing

### Manual Testing Checklist

- [ ] Module installs without errors
- [ ] Reboot applies all settings
- [ ] WebUI opens from KernelSU Manager
- [ ] All 12 tabs load correctly
- [ ] Dashboard shows real device data
- [ ] CPU/GPU/RAM controls work
- [ ] Benchmark runs and returns results
- [ ] Game Mode presets apply correctly
- [ ] Custom game add/remove works
- [ ] App scanner detects installed games
- [ ] Profile save/load/delete works
- [ ] Profile export/import works
- [ ] Auto-detect hardware works
- [ ] Config saves and loads on reboot
- [ ] Uninstall cleanly removes everything

---

## Pull Request Process

### 1. Fork & Branch

```bash
git fork
git checkout -b feature/my-feature
```

### 2. Make Changes

Follow the code style guide above.

### 3. Validate

```bash
# Syntax check
bash -n *.sh scripts/*.sh
node --check webroot/app.js

# Build test
zip -r9 test.zip . -x ".git/*"
```

### 4. Commit

Use conventional commits:

```
feat: add new CPU governor option
fix: correct thermal zone detection on Mali
docs: update README with new screenshots
ci: add ShellCheck to workflow
refactor: extract common GPU detection logic
```

### 5. Push & PR

```bash
git push origin feature/my-feature
# Open PR on GitHub
```

### PR Template

```markdown
## Description
What does this PR do?

## Type
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] CI/CD
- [ ] Refactor

## Testing
- [ ] Tested on device (model: ___)
- [ ] All syntax checks pass
- [ ] WebUI loads correctly
- [ ] No regressions

## Screenshots (if applicable)
```

---

## Release Process

### Manual Release

```bash
# 1. Update version in module.prop
sed -i 's/version=v3.0.0/version=v3.1.0/' module.prop

# 2. Commit
git add -A
git commit -m "release: v3.1.0"

# 3. Tag
git tag v3.1.0

# 4. Push
git push origin main --tags

# 5. CI auto-creates GitHub Release with flashable ZIP!
```

### What Happens on Tag Push

1. CI builds flashable ZIP
2. Validates all scripts
3. Creates GitHub Release
4. Attaches ZIP to release
5. Generates release notes

---

## Reporting Issues

When reporting a bug, please include:

1. **Device**: Brand, model, Android version
2. **Root**: KernelSU/Magisk/APatch version
3. **ROM**: Stock/Custom (which ROM)
4. **Steps**: How to reproduce
5. **Logs**: Relevant logcat output

```bash
# Get relevant logs
adb logcat -d | grep -i "opengl\|gpu\|hwui" > logs.txt
adb shell su -c "cat /data/local/opengl_renderer/logs/service_*.log" > module_logs.txt
```

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
