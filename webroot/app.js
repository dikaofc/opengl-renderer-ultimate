/* ============================================================
   OpenGL Renderer Ultimate — WebUI App Logic
   Neo-Brutalism + Retro Theme
   ============================================================ */

// ---- KernelSU API ----
const CONF_DIR = '/data/local/opengl_renderer';
const CONF_FILE = `${CONF_DIR}/config.conf`;
const MODDIR = '/data/adb/modules/opengl_renderer_ultimate';

// ---- Shell Execution ----
const API_URL = `${window.location.protocol}//${window.location.hostname}:8080`;
let useApi = false;

async function shell(cmd) {
    // 1) KernelSU native exec (works inside KSU Manager WebUI)
    if (typeof ksu !== 'undefined' && ksu.exec) {
        // KernelSU 0.6+ uses Promise-based API; older versions use callbacks
        const result = ksu.exec(cmd);

        // If ksu.exec returned a Promise (KernelSU 0.6+)
        if (result && typeof result.then === 'function') {
            try {
                const resolved = await result;
                if (typeof resolved === 'string') return resolved;
                if (resolved && typeof resolved.stdout === 'string') return resolved.stdout;
                if (resolved && typeof resolved.stderr === 'string') return resolved.stderr;
                if (resolved != null) return String(resolved);
                return '';
            } catch (e) {
                console.warn('[Shell] KSU Promise exec error:', e.message);
                return '';
            }
        }

        // Fallback: old callback API — wrap into a Promise
        return new Promise((resolve) => {
            let resolved = false;
            try {
                ksu.exec(cmd, (callbackResult) => {
                    if (resolved) return;
                    resolved = true;
                    if (typeof callbackResult === 'string') resolve(callbackResult);
                    else if (callbackResult && typeof callbackResult.stdout === 'string') resolve(callbackResult.stdout);
                    else if (callbackResult != null) resolve(String(callbackResult));
                    else resolve('');
                });
            } catch (e) {
                console.warn('[Shell] KSU callback exec error:', e.message);
                resolved = true;
                resolve('');
            }
            // Timeout fallback — if callback never fires after 10s
            setTimeout(() => { if (!resolved) { resolved = true; resolve(''); } }, 10000);
        });
    }

    // 2) HTTP API fallback (Magisk / Kitsune / APatch / SukiSU / browser)
    try {
        const resp = await fetch(`${API_URL}/api/exec`, {
            method: 'POST',
            body: cmd,
        });
        const text = await resp.text();
        useApi = true;
        return text;
    } catch (e) {
        console.warn('[Shell] API unavailable:', e.message);
        return '';
    }
}

// ---- Tab Navigation ----
// ---- Tab Navigation (Bottom Nav + Sheet) ----
const NAV_LABELS = {
    home: 'Dashboard', cpu: 'CPU', gpu: 'GPU', ram: 'RAM',
    kernel: 'Kernel', network: 'Network', thermal: 'Thermal',
    overclock: 'Overclock', opengl: 'OpenGL', profiles: 'Profiles',
    benchmark: 'Benchmark', detect: 'Detect', game: 'Game Mode'
};

function switchTab(tabName) {
    document.querySelectorAll('.bottom-nav-item').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));

    const navBtn = document.querySelector(`.bottom-nav-item[data-tab="${tabName}"]`);
    if (navBtn) navBtn.classList.add('active');

    const target = document.getElementById(`tab-${tabName}`);
    if (target) target.classList.add('active');

    document.getElementById('header-subtitle').textContent = NAV_LABELS[tabName] || tabName;
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

function openTab(tabName) {
    closeSheet();
    setTimeout(() => switchTab(tabName), 200);
}

function openSheet(name) {
    const overlay = document.getElementById('sheet-overlay');
    const sheet = document.getElementById(`sheet-${name}`);
    if (!sheet) return;
    overlay.classList.add('active');
    sheet.classList.add('active');
    document.body.style.overflow = 'hidden';
}

function closeSheet() {
    document.getElementById('sheet-overlay').classList.remove('active');
    document.querySelectorAll('.sheet').forEach(s => s.classList.remove('active'));
    document.body.style.overflow = '';
}

// Bottom nav click
document.querySelectorAll('.bottom-nav-item[data-tab]').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
});

// Sheet trigger buttons
document.querySelectorAll('.bottom-nav-item[data-sheet]').forEach(btn => {
    btn.addEventListener('click', () => openSheet(btn.dataset.sheet));
});

// Swipe down to close sheet
let sheetStartY = 0;
document.querySelectorAll('.sheet').forEach(sheet => {
    sheet.addEventListener('touchstart', e => { sheetStartY = e.touches[0].clientY; }, { passive: true });
    sheet.addEventListener('touchend', e => {
        const diff = e.changedTouches[0].clientY - sheetStartY;
        if (diff > 80) closeSheet();
    }, { passive: true });
});

// ---- Range Slider Live Values ----
document.querySelectorAll('input[type="range"]').forEach(slider => {
    const valEl = document.getElementById(`${slider.id}-val`);
    if (valEl) {
        slider.addEventListener('input', () => { valEl.textContent = slider.value; });
    }
});

// ---- Status Display ----
function setStatus(msg, type = '') {
    const bar = document.getElementById('status-bar');
    const text = document.getElementById('status-text');
    bar.className = `status-bar ${type}`;
    text.textContent = msg;
    if (type) {
        setTimeout(() => { bar.className = 'status-bar'; text.textContent = 'Ready'; }, 5000);
    }
}

// ---- HTML Helpers ----
function escapeHtml(str) {
    const d = document.createElement('div');
    d.textContent = str;
    return d.innerHTML;
}

function escapeAttr(str) {
    return str.replace(/'/g, "\\'").replace(/"/g, '&quot;');
}

// ============================================================
// CONFIG READ / WRITE
// ============================================================

async function loadConfig() {
    setStatus('Loading config...', 'warning');
    try {
        const raw = await shell(`cat ${CONF_FILE} 2>/dev/null`);
        if (!raw.trim()) { setStatus('No config found, using defaults', 'warning'); return; }

        for (const line of raw.split('\n')) {
            if (line.startsWith('#') || !line.includes('=')) continue;
            const [key, ...valParts] = line.split('=');
            const val = valParts.join('=').trim();
            const k = key.trim();
            const el = document.getElementById(k);
            if (!el) continue;

            if (el.type === 'checkbox') {
                el.checked = (val === '1' || val === 'true' || val === 'Y');
            } else if (el.type === 'range') {
                el.value = val;
                const valEl = document.getElementById(`${k}-val`);
                if (valEl) valEl.textContent = val;
            } else {
                el.value = val;
            }
        }
        setStatus('Config loaded!', 'success');
    } catch (e) {
        setStatus('Error: ' + e.message, 'error');
    }
}

async function saveConfig() {
    setStatus('Saving config...', 'warning');
    let conf = '# OpenGL Renderer Ultimate\n';
    const seen = new Set();
    document.querySelectorAll('input, select').forEach(el => {
        if (!el.id || seen.has(el.id)) return;
        seen.add(el.id);
        const val = el.type === 'checkbox' ? (el.checked ? '1' : '0') : el.value;
        conf += `${el.id}=${val}\n`;
    });
    const escaped = conf.replace(/'/g, "'\\''");
    await shell(`echo '${escaped}' > ${CONF_FILE}`);
    await shell(`chmod 644 ${CONF_FILE}`);
    setStatus('Config saved!', 'success');
}

// ============================================================
// APPLY ALL SETTINGS
// ============================================================

async function applyAll() {
    setStatus('Applying all settings...', 'warning');
    let cmds = [];

    // OpenGL
    const renderer = document.getElementById('opengl_renderer')?.value || 'skiagl';
    const reBackend = document.getElementById('renderengine_backend')?.value || 'skiagl';
    const hwuiCpu = document.getElementById('hwui_cpu_time')?.value || '25';
    const texCache = document.getElementById('hwui_texture_cache')?.value || '96';
    const layerCache = document.getElementById('hwui_layer_cache')?.value || '48';
    const framePacing = document.getElementById('hwui_frame_pacing')?.checked;
    const multiThread = document.getElementById('hwui_multi_thread')?.checked;

    cmds.push(
        `setprop debug.hwui.renderer ${renderer}`,
        `setprop debug.renderengine.backend ${reBackend}`,
        `setprop debug.hwui.target_cpu_time_percent ${hwuiCpu}`,
        `setprop debug.hwui.texture_cache_size ${texCache}`,
        `setprop debug.hwui.layer_cache_size ${layerCache}`,
        `setprop debug.hwui.frame_pacing ${framePacing}`,
        `setprop debug.hwui.use_multi_threaded_pipeline ${multiThread}`,
        `setprop persist.debug.hwui.renderer ${renderer}`,
        `setprop persist.debug.renderengine.backend ${reBackend}`
    );

    // Animation
    const winAnim = document.getElementById('window_animation_scale')?.value || '0.5';
    const transAnim = document.getElementById('transition_animation_scale')?.value || '0.5';
    const animDur = document.getElementById('animator_duration_scale')?.value || '0.5';
    cmds.push(
        `setprop window_animation_scale ${winAnim}`,
        `setprop transition_animation_scale ${transAnim}`,
        `setprop animator_duration_scale ${animDur}`,
        `setprop persist.window_animation_scale ${winAnim}`,
        `setprop persist.transition_animation_scale ${transAnim}`,
        `setprop persist.animator_duration_scale ${animDur}`
    );

    // CPU
    const cpuGov = document.getElementById('cpu_governor')?.value || 'performance';
    const govLock = document.getElementById('governor_lock')?.checked;
    if (govLock) cmds.push(`for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -w "$i" ] && echo ${cpuGov} > "$i" 2>/dev/null; done`);

    const cpuMax = document.getElementById('cpu_max_freq')?.value;
    if (cpuMax) cmds.push(`for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do [ -w "$i" ] && echo ${cpuMax} > "$i" 2>/dev/null; done`);

    // GPU
    const gpuGov = document.getElementById('gpu_governor')?.value || 'performance';
    const gpuOc = document.getElementById('gpu_overclock_enabled')?.checked;
    cmds.push(
        `KGSL="/sys/class/kgsl/kgsl-3d0"`,
        `[ -w "$KGSL/devfreq/governor" ] && echo ${gpuOc ? 'performance' : gpuGov} > "$KGSL/devfreq/governor" 2>/dev/null`
    );

    const gpuMaxFreq = document.getElementById('gpu_freq_max')?.value;
    if (gpuMaxFreq) cmds.push(`[ -w "$KGSL/max_gpuclk" ] && echo ${gpuMaxFreq} > "$KGSL/max_gpuclk" 2>/dev/null`);

    // RAM
    cmds.push(
        `echo ${document.getElementById('swappiness')?.value || 100} > /proc/sys/vm/swappiness`,
        `echo ${document.getElementById('dirty_ratio')?.value || 40} > /proc/sys/vm/dirty_ratio`,
        `echo ${document.getElementById('dirty_background_ratio')?.value || 10} > /proc/sys/vm/dirty_background_ratio`,
        `echo ${document.getElementById('vfs_cache_pressure')?.value || 50} > /proc/sys/vm/vfs_cache_pressure`,
        `echo ${document.getElementById('min_free_kbytes')?.value || 12288} > /proc/sys/vm/min_free_kbytes`
    );

    // I/O
    cmds.push(`for q in /sys/block/*/queue/scheduler; do [ -w "$q" ] && echo ${document.getElementById('io_scheduler')?.value || 'bfq'} > "$q" 2>/dev/null; done`);

    // Network
    cmds.push(
        `echo ${document.getElementById('tcp_congestion')?.value || 'bbr'} > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null`,
        `echo ${document.getElementById('default_qdisc')?.value || 'fq'} > /proc/sys/net/core/default_qdisc 2>/dev/null`
    );

    // Thermal
    if (document.getElementById('thermal_mode')?.value === 'performance') {
        cmds.push(`for tz in /sys/class/thermal/thermal_zone*/mode; do [ -w "$tz" ] && echo disabled > "$tz" 2>/dev/null; done`);
    }

    await shell(cmds.join(' && '));
    await saveConfig();
    setStatus('All settings applied! Reboot recommended.', 'success');
}

// ============================================================
// OVERCLOCK
// ============================================================

async function applyOverclock() {
    setStatus('Applying overclock...', 'warning');
    let cmds = [];

    if (document.getElementById('overclock_enabled')?.checked) {
        cmds.push(`for i in /sys/devices/system/cpu/cpu*/cpufreq; do [ -d "$i" ] && echo performance > "$i/scaling_governor" 2>/dev/null && cat "$i/cpuinfo_max_freq" > "$i/scaling_max_freq" 2>/dev/null; done`);
    }
    if (document.getElementById('gpu_overclock_enabled')?.checked) {
        cmds.push(
            `KGSL="/sys/class/kgsl/kgsl-3d0"`,
            `[ -d "$KGSL" ] && echo performance > "$KGSL/devfreq/governor" 2>/dev/null`,
            `[ -f "$KGSL/gpu_available_frequencies" ] && MAX=$(cat "$KGSL/gpu_available_frequencies" | tr ' ' '\\n' | sort -n | tail -1) && echo "$MAX" > "$KGSL/max_gpuclk" 2>/dev/null`,
            `[ -w "$KGSL/force_clk_on" ] && echo 1 > "$KGSL/force_clk_on"`,
            `[ -w "$KGSL/force_bus_on" ] && echo 1 > "$KGSL/force_bus_on"`,
            `[ -w "$KGSL/force_rail_on" ] && echo 1 > "$KGSL/force_rail_on"`,
            `[ -w "$KGSL/idle_timer" ] && echo 0 > "$KGSL/idle_timer"`
        );
    }
    if (document.getElementById('bus_overclock')?.checked) {
        cmds.push(`for ddr in /sys/class/devfreq/*ddr* /sys/class/devfreq/*memlat*; do [ -d "$ddr" ] && echo performance > "$ddr/governor" 2>/dev/null; done`);
    }
    if (document.getElementById('io_overclock')?.checked) {
        cmds.push(`for q in /sys/block/*/queue; do [ -d "$q" ] && echo bfq > "$q/scheduler" 2>/dev/null && echo 256 > "$q/nr_requests" 2>/dev/null; done`);
    }

    await shell(cmds.join(' && '));
    setStatus('Overclock applied!', 'success');
}

// ============================================================
// DEVICE INFO
// ============================================================

async function loadDeviceInfo() {
    const q = async (cmd) => {
        try {
            const r = await shell(cmd);
            return r ? r.trim() : '';
        } catch(e) { return ''; }
    };
    const safeInt = (s, fallback) => { const n = parseInt(s); return isNaN(n) ? fallback : n; };
    const safeFreq = (khz) => { const n = safeInt(khz, 0); return n > 0 ? `${(n/1000).toFixed(0)} MHz` : '-'; };

    // Show refresh indicators on active info grids
    const grids = document.querySelectorAll('.info-grid');
    grids.forEach(g => g.classList.add('refreshing'));

    document.getElementById('cpu-cores').textContent = (await q('nproc 2>/dev/null')) || '-';
    document.getElementById('cpu-max-freq').textContent = safeFreq(await q('cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null'));
    document.getElementById('cpu-min-freq').textContent = safeFreq(await q('cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null'));
    document.getElementById('cpu-governor').textContent = (await q('cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null')) || '-';

    const egl = await q('getprop ro.hardware.egl 2>/dev/null');
    const vk = await q('getprop ro.hardware.vulkan 2>/dev/null');
    document.getElementById('gpu-egl').textContent = egl || '-';
    document.getElementById('gpu-vulkan').textContent = vk || '-';

    let vendor = 'Unknown', renderer = '-';
    const el = (egl || '').toLowerCase();
    if (el.includes('adreno') || el.includes('kgsl')) { vendor = 'Qualcomm'; renderer = 'Adreno'; }
    else if (el.includes('mali')) { vendor = 'ARM'; renderer = 'Mali'; }
    else if (el.includes('xclipse')) { vendor = 'Samsung'; renderer = 'Xclipse'; }
    document.getElementById('gpu-vendor').textContent = vendor;
    document.getElementById('gpu-renderer').textContent = renderer;

    const memT = safeInt(await q('grep MemTotal /proc/meminfo | awk \'{print $2}\''), 0);
    const memA = safeInt(await q('grep MemAvailable /proc/meminfo | awk \'{print $2}\''), 0);
    document.getElementById('ram-total').textContent = memT > 0 ? `${(memT/1024).toFixed(0)} MB` : '-';
    document.getElementById('ram-avail').textContent = memA > 0 ? `${(memA/1024).toFixed(0)} MB` : '-';
    document.getElementById('ram-zram').textContent = (await q('lsblk -o NAME,SIZE 2>/dev/null | grep zram | head -1')) || 'None';
    const swapRaw = safeInt(await q('free 2>/dev/null | grep Swap | awk \'{print $2}\''), 0);
    document.getElementById('ram-swap').textContent = swapRaw > 0 ? `${(swapRaw/1024).toFixed(0)} MB` : 'None';

    document.getElementById('gl-hwui').textContent = (await q('getprop debug.hwui.renderer 2>/dev/null')) || '-';
    document.getElementById('gl-renderengine').textContent = (await q('getprop debug.renderengine.backend 2>/dev/null')) || '-';
    document.getElementById('gl-msaa').textContent = (await q('getprop debug.egl.force_msaa 2>/dev/null')) || '-';
    document.getElementById('gl-framepacing').textContent = (await q('getprop debug.hwui.frame_pacing 2>/dev/null')) || '-';

    document.getElementById('thermal-zones').textContent = (await q('ls -d /sys/class/thermal/thermal_zone* 2>/dev/null | wc -l')) || '-';
    const temp = safeInt(await q('cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null'), 0);
    document.getElementById('thermal-current').textContent = temp > 0 ? `${(temp/1000).toFixed(1)}°C` : '-';

    // Remove refresh indicators after short delay
    setTimeout(() => grids.forEach(g => g.classList.remove('refreshing')), 300);
}

// ============================================================
// BENCHMARK
// ============================================================

async function runBenchmark(type) {
    const loading = document.getElementById('bench-loading');
    const results = document.getElementById('bench-results');
    loading.style.display = 'flex';
    results.style.display = 'none';
    setStatus(`Running ${type} benchmark...`, 'warning');

    const raw = await shell(`${MODDIR}/scripts/benchmark.sh ${type} 2>/dev/null`);
    loading.style.display = 'none';

    try {
        // Parse JSON from output (may have extra lines)
        const jsonStart = raw.indexOf('{');
        const jsonEnd = raw.lastIndexOf('}');
        if (jsonStart === -1 || jsonEnd === -1) throw new Error('No JSON in output');
        const data = JSON.parse(raw.substring(jsonStart, jsonEnd + 1));

        let cards = '';
        if (data.cpu) {
            cards += benchCard('CPU Combined', data.cpu.combined, 'ops/ms', 'yellow');
            cards += benchCard('CPU Integer', data.cpu.integer_ops, 'ops/ms', 'orange');
            cards += benchCard('CPU Float', data.cpu.float_ops, 'ops/ms', 'pink');
            cards += benchCard('CPU Processes', data.cpu.process_score, 'ops/ms', 'blue');
            cards += benchCard('CPU Cores', data.cpu.cores, '', 'teal');
            cards += benchCard('CPU Max', data.cpu.max_freq ? `${(data.cpu.max_freq/1000).toFixed(0)}MHz` : '-', '', 'lime');
        }
        if (data.ram) {
            cards += benchCard('RAM Write', data.ram.write_bandwidth, 'KB/ms', 'teal');
            cards += benchCard('RAM Read', data.ram.read_bandwidth, 'KB/ms', 'lime');
            cards += benchCard('RAM Latency', data.ram.alloc_latency_ms, 'ms', 'blue');
            cards += benchCard('RAM Total', data.ram.total_kb ? `${(data.ram.total_kb/1024).toFixed(0)}MB` : '-', '', 'accent');
        }
        if (data.io) {
            cards += benchCard('I/O Seq Write', data.io.seq_write, 'KB/ms', 'purple');
            cards += benchCard('I/O Seq Read', data.io.seq_read, 'KB/ms', 'orange');
            cards += benchCard('I/O Rand 4K', data.io.rand_4k_read, 'KB/ms', 'pink');
            cards += benchCard('I/O Scheduler', data.io.scheduler, '', 'teal');
        }
        if (data.gpu) {
            cards += benchCard('GPU Score', data.gpu.score, 'pts', 'lime');
            cards += benchCard('GPU Backend', data.gpu.backend || '-', '', 'blue');
        }

        document.getElementById('bench-cards').innerHTML = cards;
        results.style.display = 'block';
        setStatus('Benchmark complete!', 'success');
    } catch (e) {
        setStatus('Benchmark parse error: ' + e.message, 'error');
        document.getElementById('bench-cards').innerHTML = `<div class="profile-empty">Error parsing results. Raw output available in console.</div>`;
        results.style.display = 'block';
        console.log('[Benchmark Raw]', raw);
    }
}

function benchCard(label, value, unit, color) {
    return `<div class="bench-card ${color || ''}"><div class="bench-label">${label}</div><div class="bench-value">${value ?? '-'}</div><div class="bench-unit">${unit}</div></div>`;
}

async function saveBenchmark(label) {
    setStatus(`Saving ${label} baseline...`, 'warning');
    await shell(`${MODDIR}/scripts/benchmark.sh ${label} 2>/dev/null`);
    setStatus(`${label} baseline saved!`, 'success');
}

async function compareBenchmarks() {
    setStatus('Comparing before vs after...', 'warning');
    const raw = await shell(`${MODDIR}/scripts/benchmark.sh compare 2>/dev/null`);

    const container = document.getElementById('compare-results');
    container.style.display = 'block';

    if (raw.includes('ERROR')) {
        container.innerHTML = `<div class="control-group"><div class="warning-box">${escapeHtml(raw)}</div></div>`;
        return;
    }

    // Parse the comparison lines
    const lines = raw.split('\n').filter(l => l.includes('Before:'));
    if (lines.length === 0) {
        container.innerHTML = `<div class="control-group"><div class="profile-empty">No comparison data. Save before/after first.</div></div>`;
        return;
    }

    let table = '<div class="control-group"><h3>Results</h3><table class="compare-table"><tr><th>Metric</th><th>Before</th><th>After</th><th>Change</th></tr>';
    for (const line of lines) {
        const parts = line.trim().split(/\s+/);
        // Format: "section.key  Before: X  After: Y  +/-Z%"
        const match = line.match(/(\S+)\s+Before:\s+(\S+)\s+After:\s+(\S+)\s+([+-]?\d+)%/);
        if (match) {
            const [, metric, before, after, pct] = match;
            const pctNum = parseInt(pct);
            const cls = pctNum > 0 ? 'improved' : pctNum < 0 ? 'degraded' : 'neutral';
            const sign = pctNum > 0 ? '+' : '';
            table += `<tr><td>${escapeHtml(metric)}</td><td>${escapeHtml(before)}</td><td>${escapeHtml(after)}</td><td class="${cls}">${sign}${pctNum}%</td></tr>`;
        }
    }
    table += '</table></div>';
    container.innerHTML = table;
    setStatus('Comparison complete!', 'success');
}

// ============================================================
// AUTO-DETECT
// ============================================================

async function runDetect() {
    const loading = document.getElementById('detect-loading');
    const results = document.getElementById('detect-results');
    loading.style.display = 'flex';
    results.style.display = 'none';
    setStatus('Scanning hardware...', 'warning');

    const raw = await shell(`${MODDIR}/scripts/auto_detect.sh scan 2>/dev/null`);
    loading.style.display = 'none';

    try {
        const jsonStart = raw.indexOf('{');
        const jsonEnd = raw.lastIndexOf('}');
        if (jsonStart === -1) throw new Error('No JSON');
        const data = JSON.parse(raw.substring(jsonStart, jsonEnd + 1));

        let html = '';

        // Device
        if (data.device) {
            html += detectCard('Device', [
                ['Model', data.device.model],
                ['Brand', data.device.brand],
                ['Device', data.device.device],
                ['Android', data.device.android],
                ['SDK', data.device.sdk],
                ['Custom ROM', data.device.is_custom_rom ? 'Yes' : 'No'],
            ]);
        }

        // SoC
        if (data.soc) {
            html += detectCard('SoC', [
                ['Platform', data.soc.platform],
                ['Model', data.soc.model],
                ['Manufacturer', data.soc.manufacturer],
                ['Architecture', data.soc.arch],
            ]);
        }

        // CPU
        if (data.cpu) {
            html += detectCard('CPU', [
                ['Cores', data.cpu.cores],
                ['Max Frequency', data.cpu.max_freq ? `${(data.cpu.max_freq/1000).toFixed(0)} MHz` : '-'],
                ['big.LITTLE', data.cpu.has_big_lITTLE ? 'Yes' : 'No'],
                ['Governor', data.cpu.governor],
            ]);
        }

        // GPU
        if (data.gpu) {
            html += detectCard('GPU', [
                ['Vendor', data.gpu.vendor],
                ['Renderer', data.gpu.renderer],
                ['Model', data.gpu.model],
                ['Max Clock', data.gpu.max_clock ? `${(data.gpu.max_clock/1000000).toFixed(0)} MHz` : '-'],
            ]);
        }

        // RAM
        if (data.ram) {
            html += detectCard('Memory', [
                ['Total', `${data.ram.total_mb} MB`],
                ['Available', `${(data.ram.available_kb/1024).toFixed(0)} MB`],
                ['Speed', data.ram.speed || '-'],
            ]);
        }

        // Thermal
        if (data.thermal) {
            html += detectCard('Thermal', [
                ['Zones', data.thermal.zones],
                ['Current Temp', `${data.thermal.current_temp_c} C`],
            ]);
        }

        // Kernel
        html += detectCard('System', [
            ['Kernel', data.kernel],
            ['Storage', data.storage?.type || '-'],
        ]);

        // Recommendation
        const recRaw = await shell(`${MODDIR}/scripts/auto_detect.sh recommend 2>/dev/null`);
        const recStart = recRaw.indexOf('{');
        const recEnd = recRaw.lastIndexOf('}');
        if (recStart !== -1) {
            const rec = JSON.parse(recRaw.substring(recStart, recEnd + 1));
            html += `<div class="detect-card" style="background:var(--yellow);border-color:var(--border)">
                <h4><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg> RECOMMENDATION</h4>
                <div class="detect-row"><span class="k">Profile</span><span class="v" style="font-size:16px">${escapeHtml(rec.profile.toUpperCase())}</span></div>
                <div class="detect-row"><span class="k">Reason</span><span class="v" style="font-weight:500;font-size:12px">${escapeHtml(rec.reason)}</span></div>
            </div>`;
        }

        results.innerHTML = html;
        results.style.display = 'block';
        setStatus('Hardware scan complete!', 'success');
    } catch (e) {
        setStatus('Scan error: ' + e.message, 'error');
        results.innerHTML = `<div class="control-group"><div class="profile-empty">Error: ${escapeHtml(e.message)}</div></div>`;
        results.style.display = 'block';
    }
}

function detectCard(title, rows) {
    let svg = '';
    switch(title) {
        case 'Device': svg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>'; break;
        case 'SoC': svg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/></svg>'; break;
        case 'CPU': svg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="4" width="16" height="16" rx="2"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/></svg>'; break;
        case 'GPU': svg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 12h4"/><path d="M14 12h4"/></svg>'; break;
        case 'Memory': svg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="6" width="20" height="12" rx="2"/><line x1="6" y1="10" x2="6" y2="14"/></svg>'; break;
        case 'Thermal': svg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 14.76V3.5a2.5 2.5 0 0 0-5 0v11.26a4.5 4.5 0 1 0 5 0z"/></svg>'; break;
        case 'System': svg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 1v2"/><path d="M12 21v2"/></svg>'; break;
    }
    const rowsHtml = rows.map(([k, v]) => `<div class="detect-row"><span class="k">${escapeHtml(k)}</span><span class="v">${escapeHtml(String(v ?? '-'))}</span></div>`).join('');
    return `<div class="detect-card"><h4>${svg} ${escapeHtml(title)}</h4>${rowsHtml}</div>`;
}

async function applyAutoDetect() {
    setStatus('Applying optimal settings...', 'warning');
    await shell(`${MODDIR}/scripts/auto_detect.sh apply 2>/dev/null`);
    await loadConfig();
    setStatus('Optimal settings applied! Reboot recommended.', 'success');
}

// ============================================================
// PROFILES
// ============================================================

let profileList = [];
let activeProfile = '';

async function profileShell(cmd) {
    return await shell(`${MODDIR}/scripts/apply_profile.sh ${cmd}`);
}

async function loadProfiles() {
    const raw = await profileShell('list');
    profileList = [];
    activeProfile = '';

    let current = null;
    for (const line of raw.split('\n')) {
        const trimmed = line.trim();
        if (trimmed.match(/^[a-zA-Z0-9_-]+/) && !trimmed.startsWith('Created') && !trimmed.startsWith('Device') && !trimmed.startsWith('Total') && !trimmed.startsWith('Auto') && !trimmed.startsWith('===') && !trimmed.startsWith('No ') && trimmed.length > 0 && !trimmed.includes(':')) {
            if (current) profileList.push(current);
            const isActive = trimmed.includes('ACTIVE');
            const name = trimmed.replace(/\s*\u2605?\s*ACTIVE/, '').trim();
            current = { name, active: isActive, created: '', device: '' };
            if (isActive) activeProfile = name;
        } else if (trimmed.startsWith('Created') && current) {
            current.created = trimmed.split(':').slice(1).join(':').trim();
        } else if (trimmed.startsWith('Device') && current) {
            current.device = trimmed.split(':').slice(1).join(':').trim();
        }
    }
    if (current) profileList.push(current);

    renderProfileList();
    renderProfileSelects();

    const nameEl = document.getElementById('active-profile-name');
    const totalEl = document.getElementById('total-profiles');
    if (nameEl) nameEl.textContent = activeProfile || 'None';
    if (totalEl) totalEl.textContent = profileList.length;
}

function renderProfileList() {
    const container = document.getElementById('profile-list');
    if (!container) return;
    if (profileList.length === 0) {
        container.innerHTML = '<div class="profile-empty">No profiles saved yet.</div>';
        return;
    }
    container.innerHTML = profileList.map(p => `
        <div class="profile-card ${p.active ? 'active' : ''}">
            <div class="profile-card-header">
                <span class="profile-card-name">${escapeHtml(p.name)}${p.active ? ' <span class="active-badge">ACTIVE</span>' : ''}</span>
            </div>
            <div class="profile-card-meta">${p.created ? 'Created: ' + escapeHtml(p.created) : ''} ${p.device ? ' - ' + escapeHtml(p.device) : ''}</div>
            <div class="profile-card-actions">
                <button class="profile-btn load" onclick="loadProfile('${escapeAttr(p.name)}')">Load</button>
                <button class="profile-btn delete" onclick="deleteProfile('${escapeAttr(p.name)}')">Delete</button>
                <button class="profile-btn export" onclick="exportSingleProfile('${escapeAttr(p.name)}')">Export</button>
            </div>
        </div>
    `).join('');
}

function renderProfileSelects() {
    ['auto-apply-select', 'rename-source'].forEach(id => {
        const sel = document.getElementById(id);
        if (!sel) return;
        const cv = sel.value;
        sel.innerHTML = id === 'auto-apply-select' ? '<option value="none">None</option>' : '<option value="">Select...</option>';
        profileList.forEach(p => {
            const opt = document.createElement('option');
            opt.value = p.name;
            opt.textContent = p.name + (p.active ? ' (Active)' : '');
            sel.appendChild(opt);
        });
        if (cv && sel.querySelector(`option[value="${cv}"]`)) sel.value = cv;
    });
}

async function saveProfile() {
    const name = document.getElementById('new-profile-name')?.value?.trim();
    if (!name) { setStatus('Enter a profile name', 'warning'); return; }
    if (!/^[a-zA-Z0-9_-]+$/.test(name)) { setStatus('Name: letters, numbers, dash, underscore only', 'error'); return; }
    setStatus(`Saving '${name}'...`, 'warning');
    const r = await profileShell(`save ${name}`);
    setStatus(r.trim(), r.includes('OK') ? 'success' : 'error');
    document.getElementById('new-profile-name').value = '';
    await loadProfiles();
}

async function loadProfile(name) {
    setStatus(`Loading '${name}'...`, 'warning');
    const r = await profileShell(`load ${name}`);
    setStatus(r.trim(), r.includes('OK') ? 'success' : 'error');
    await loadProfiles();
    await loadConfig();
}

async function deleteProfile(name) {
    if (!confirm(`Delete '${name}'?`)) return;
    const r = await profileShell(`delete ${name}`);
    setStatus(r.trim(), r.includes('OK') ? 'success' : 'error');
    await loadProfiles();
}

async function exportProfile() {
    setStatus('Exporting all profiles...', 'warning');
    for (const p of profileList) await profileShell(`export ${p.name}`);
    setStatus('Exported to /sdcard/OpenGLProfiles/', 'success');
}

async function exportSingleProfile(name) {
    setStatus(`Exporting '${name}'...`, 'warning');
    const r = await profileShell(`export ${name}`);
    setStatus(r.trim(), r.includes('OK') ? 'success' : 'error');
}

async function importProfile() {
    setStatus('Importing...', 'warning');
    const result = await shell('ls /sdcard/OpenGLProfiles/*.tar.gz 2>/dev/null');
    const files = result.trim().split('\n').filter(f => f);
    if (files.length === 0) { setStatus('No .tar.gz files found', 'error'); return; }
    for (const f of files) await profileShell(`import ${f}`);
    setStatus('Imported!', 'success');
    await loadProfiles();
}

async function renameProfile() {
    const src = document.getElementById('rename-source')?.value;
    const newName = document.getElementById('rename-new-name')?.value?.trim();
    if (!src || !newName) { setStatus('Select source + enter name', 'warning'); return; }
    if (!/^[a-zA-Z0-9_-]+$/.test(newName)) { setStatus('Invalid name', 'error'); return; }
    const r = await profileShell(`rename ${src} ${newName}`);
    setStatus(r.trim(), r.includes('OK') ? 'success' : 'error');
    document.getElementById('rename-new-name').value = '';
    await loadProfiles();
}

async function duplicateProfile() {
    const src = document.getElementById('rename-source')?.value;
    const newName = document.getElementById('rename-new-name')?.value?.trim();
    if (!src || !newName) { setStatus('Select source + enter name', 'warning'); return; }
    if (!/^[a-zA-Z0-9_-]+$/.test(newName)) { setStatus('Invalid name', 'error'); return; }
    const r = await profileShell(`duplicate ${src} ${newName}`);
    setStatus(r.trim(), r.includes('OK') ? 'success' : 'error');
    document.getElementById('rename-new-name').value = '';
    await loadProfiles();
}

async function setAutoApply() {
    const val = document.getElementById('auto-apply-select')?.value || 'none';
    const r = await profileShell(`set-active ${val}`);
    setStatus(r.trim(), r.includes('OK') ? 'success' : 'error');
}

// ============================================================
// REBOOT
// ============================================================

function rebootDevice() {
    if (confirm('Reboot device now?')) shell('svc power reboot');
}

// ============================================================
// GAME MODE
// ============================================================

const GAME_PRESETS = [
    // MOBA
    { name: 'Mobile Legends: Bang Bang', pkg: 'com.mobile.legends', genre: 'moba' },
    { name: 'League of Legends: Wild Rift', pkg: 'com.tencent.lolm', genre: 'moba' },
    { name: 'Honor of Kings', pkg: 'com.tencent.tmgp.sgame', genre: 'moba' },
    { name: 'Onmyoji Arena', pkg: 'com.netease.ma', genre: 'moba' },
    // Battle Royale
    { name: 'PUBG Mobile', pkg: 'com.tencent.ig', genre: 'battle_royale' },
    { name: 'PUBG Mobile (KR)', pkg: 'com.pubg.krmobile', genre: 'battle_royale' },
    { name: 'PUBG Mobile (India)', pkg: 'com.pubg.imobile', genre: 'battle_royale' },
    { name: 'Free Fire', pkg: 'com.dts.freefireth', genre: 'battle_royale' },
    { name: 'Call of Duty Mobile', pkg: 'com.garena.game.codm', genre: 'battle_royale' },
    { name: 'COD Mobile (Activision)', pkg: 'com.activision.callofduty.shooter', genre: 'battle_royale' },
    { name: 'Fortnite', pkg: 'com.epicgames.fortnite', genre: 'battle_royale' },
    { name: 'Rules of Survival', pkg: 'com.netease.g93na', genre: 'battle_royale' },
    // Open World
    { name: 'Genshin Impact', pkg: 'com.miHoYo.GenshinImpact', genre: 'open_world' },
    { name: 'Honkai: Star Rail', pkg: 'com.miHoYo.hkrpg', genre: 'open_world' },
    { name: 'Zenless Zone Zero', pkg: 'com.HoYoverse.Nap', genre: 'open_world' },
    { name: 'Wuthering Waves', pkg: 'com.kurogame.gplay.punishing', genre: 'open_world' },
    // Racing
    { name: 'Asphalt 9', pkg: 'com.gameloft.android.ANMP.GloftA9HM', genre: 'racing' },
    // Casual
    { name: 'Roblox', pkg: 'com.roblox.client', genre: 'casual' },
    { name: 'Minecraft', pkg: 'com.mojang.minecraftpe', genre: 'casual' },
    { name: 'Clash of Clans', pkg: 'com.supercell.clashofclans', genre: 'casual' },
    { name: 'Clash Royale', pkg: 'com.supercell.clashroyale', genre: 'casual' },
    { name: 'Candy Crush Saga', pkg: 'com.king.candycrushsaga', genre: 'casual' },
    { name: 'Pokemon GO', pkg: 'com.nianticlabs.pokemongo', genre: 'casual' },
    { name: 'FIFA Mobile', pkg: 'com.ea.gp.fifamobile', genre: 'casual' },
    { name: '8 Ball Pool', pkg: 'com.miniclip.eightballpool', genre: 'casual' },
];

const GENRE_DISPLAY = {
    moba: 'MOBA',
    battle_royale: 'Battle Royale',
    open_world: 'Open World',
    fps: 'FPS',
    racing: 'Racing',
    casual: 'Casual',
};

const GENRE_SETTINGS = {
    moba:            { cpu: 'Performance', gpu: 'Performance', ram: 'Aggressive', net: 'Low Latency', thermal: 'Perf', anim: 'OFF', sched: 'Responsive', io: 'Fast' },
    battle_royale:   { cpu: 'Max', gpu: 'Max', ram: 'Aggressive', net: 'Low Latency', thermal: 'Perf', anim: 'OFF', sched: 'Responsive', io: 'Fast' },
    open_world:      { cpu: 'Max', gpu: 'Max', ram: 'Maximum', net: 'Balanced', thermal: 'Aggressive', anim: 'OFF', sched: 'Responsive', io: 'Max' },
    fps:             { cpu: 'Max', gpu: 'Max', ram: 'Aggressive', net: 'Ultra Low', thermal: 'Perf', anim: 'OFF', sched: 'Responsive', io: 'Fast' },
    racing:          { cpu: 'Max', gpu: 'Max', ram: 'Aggressive', net: 'Low Latency', thermal: 'Perf', anim: 'OFF', sched: 'Responsive', io: 'Fast' },
    casual:          { cpu: 'Balanced', gpu: 'Balanced', ram: 'Moderate', net: 'Balanced', thermal: 'Balanced', anim: 'Normal', sched: 'Balanced', io: 'Balanced' },
};

// ---- Custom Games ----

async function addCustomGame() {
    const pkg = document.getElementById('custom-game-pkg')?.value?.trim();
    const name = document.getElementById('custom-game-name')?.value?.trim();
    const genre = document.getElementById('custom-game-genre')?.value || 'battle_royale';

    if (!pkg) { setStatus('Enter a package name', 'warning'); return; }

    setStatus(`Adding ${name || pkg}...`, 'warning');
    const r = await shell(`${MODDIR}/scripts/apply_gamemode.sh add ${pkg} '${(name || pkg).replace(/'/g, "\\'" )}' ${genre} 2>/dev/null`);
    setStatus(r.trim(), r.includes('OK') ? 'success' : 'error');

    document.getElementById('custom-game-pkg').value = '';
    document.getElementById('custom-game-name').value = '';
    loadCustomGames();
}

async function loadCustomGames() {
    const raw = await shell(`${MODDIR}/scripts/apply_gamemode.sh custom-list 2>/dev/null`);
    const container = document.getElementById('custom-games-list');
    if (!container) return;

    const lines = raw.split('\n').filter(l => l.match(/^  \S/));
    if (lines.length === 0) {
        container.innerHTML = '<div class="profile-empty">No custom games added yet</div>';
        return;
    }

    container.innerHTML = lines.map(line => {
        const match = line.trim().match(/^(.+)\s+\((.+)\)\s+—\s+(\S+)$/);
        if (!match) return '';
        const [, name, pkg, genre] = match;
        return `
            <div class="game-item">
                <div class="game-item-info">
                    <span class="game-item-name">${escapeHtml(name)}</span>
                    <span class="game-item-pkg">${escapeHtml(pkg)}</span>
                </div>
                <div style="display:flex;align-items:center;gap:6px;">
                    <span class="game-item-genre genre-${genre}">${GENRE_DISPLAY[genre] || genre}</span>
                    <button class="btn btn-sm btn-purple" onclick="applyGamePreset('${escapeAttr(pkg)}','${escapeAttr(name)}','${genre}')">Use</button>
                    <button class="btn btn-sm btn-danger" onclick="removeCustomGame('${escapeAttr(pkg)}')">X</button>
                </div>
            </div>`;
    }).filter(Boolean).join('');
}

async function removeCustomGame(pkg) {
    if (!confirm(`Remove ${pkg}?`)) return;
    setStatus(`Removing ${pkg}...`, 'warning');
    await shell(`${MODDIR}/scripts/apply_gamemode.sh remove ${pkg} 2>/dev/null`);
    setStatus('Removed', 'success');
    loadCustomGames();
}

// ---- App Scanner ----

let scannedApps = [];

async function scanApps(mode) {
    const loading = document.getElementById('scan-loading');
    const results = document.getElementById('scan-results');
    const selectAll = document.getElementById('scan-select-all');
    loading.style.display = 'flex';
    results.innerHTML = '';
    selectAll.style.display = 'none';
    setStatus('Scanning installed apps...', 'warning');

    const filter = document.getElementById('scan-filter')?.value?.trim() || '';
    let cmd = `${MODDIR}/scripts/apply_gamemode.sh scan-json ${filter} 2>/dev/null`;

    const raw = await shell(cmd);
    loading.style.display = 'none';

    try {
        const jsonStart = raw.indexOf('[');
        const jsonEnd = raw.lastIndexOf(']');
        if (jsonStart === -1) throw new Error('No JSON');
        scannedApps = JSON.parse(raw.substring(jsonStart, jsonEnd + 1));

        // Filter games only if mode
        if (mode === 'game') {
            scannedApps = scannedApps.filter(a => a.isGame);
        }

        if (scannedApps.length === 0) {
            results.innerHTML = '<div class="profile-empty">No apps found</div>';
            return;
        }

        selectAll.style.display = 'flex';
        document.getElementById('scan-check-all').checked = false;

        results.innerHTML = scannedApps.map((app, i) => {
            const genreClass = app.genre !== 'none' ? `genre-${app.genre}` : '';
            const gameClass = app.isGame ? 'is-game' : '';
            return `
                <div class="scan-item ${gameClass}">
                    <input type="checkbox" class="scan-check" data-index="${i}" ${app.isGame ? 'checked' : ''}>
                    <div class="scan-item-info">
                        <div class="scan-item-label">${escapeHtml(app.label)}</div>
                        <div class="scan-item-pkg">${escapeHtml(app.pkg)}</div>
                    </div>
                    ${app.isGame ? `<span class="scan-item-genre ${genreClass}">${GENRE_DISPLAY[app.genre] || app.genre}</span>` : ''}
                </div>`;
        }).join('');

        setStatus(`Found ${scannedApps.length} apps (${scannedApps.filter(a=>a.isGame).length} games)`, 'success');
    } catch (e) {
        results.innerHTML = `<div class="profile-empty">Error: ${escapeHtml(e.message)}</div>`;
        setStatus('Scan error', 'error');
    }
}

function toggleScanAll() {
    const checked = document.getElementById('scan-check-all')?.checked;
    document.querySelectorAll('.scan-check').forEach(cb => { cb.checked = checked; });
}

async function addScannedGames() {
    const checked = document.querySelectorAll('.scan-check:checked');
    if (checked.length === 0) {
        setStatus('No apps selected', 'warning');
        return;
    }

    setStatus(`Adding ${checked.length} games...`, 'warning');
    let added = 0;

    for (const cb of checked) {
        const idx = parseInt(cb.dataset.index);
        const app = scannedApps[idx];
        if (!app) continue;

        const genre = app.isGame && app.genre !== 'none' ? app.genre : 'battle_royale';
        await shell(`${MODDIR}/scripts/apply_gamemode.sh add ${app.pkg} '${app.label.replace(/'/g, "\\'").replace(/"/g, '\\"')}' ${genre} 2>/dev/null`);
        added++;
    }

    setStatus(`Added ${added} games!`, 'success');
    loadCustomGames();
}

function renderGameList() {
    const container = document.getElementById('game-list');
    if (!container) return;

    let html = '';
    const grouped = {};
    GAME_PRESETS.forEach(g => {
        if (!grouped[g.genre]) grouped[g.genre] = [];
        grouped[g.genre].push(g);
    });

    for (const [genre, games] of Object.entries(grouped)) {
        games.forEach(g => {
            html += `
                <div class="game-item">
                    <div class="game-item-info">
                        <span class="game-item-name">${escapeHtml(g.name)}</span>
                        <span class="game-item-pkg">${escapeHtml(g.pkg)}</span>
                    </div>
                    <div style="display:flex;align-items:center;gap:6px;">
                        <span class="game-item-genre genre-${genre}">${GENRE_DISPLAY[genre] || genre}</span>
                        <button class="btn btn-sm btn-purple" onclick="applyGamePreset('${escapeAttr(g.pkg)}','${escapeAttr(g.name)}','${genre}')">Activate</button>
                    </div>
                </div>`;
        });
    }
    container.innerHTML = html || '<div class="profile-empty">No games found</div>';
}

async function gameDetect() {
    setStatus('Detecting running game...', 'warning');
    const pkg = (await shell(`${MODDIR}/scripts/apply_gamemode.sh detect 2>/dev/null`)).trim();
    if (!pkg) {
        setStatus('No game detected. Start a game first.', 'error');
        return;
    }
    const genre = GAME_PRESETS.find(g => g.pkg === pkg)?.genre || 'battle_royale';
    const name = GAME_PRESETS.find(g => g.pkg === pkg)?.name || pkg;
    applyGamePreset(pkg, name, genre);
}

async function applyGamePreset(pkg, name, genre) {
    setStatus(`Activating Game Mode for ${name}...`, 'warning');
    await shell(`${MODDIR}/scripts/apply_gamemode.sh apply ${pkg} 2>/dev/null`);

    // Update settings preview
    const s = GENRE_SETTINGS[genre] || GENRE_SETTINGS.battle_royale;
    document.getElementById('gs-cpu').textContent = s.cpu;
    document.getElementById('gs-gpu').textContent = s.gpu;
    document.getElementById('gs-ram').textContent = s.ram;
    document.getElementById('gs-net').textContent = s.net;
    document.getElementById('gs-thermal').textContent = s.thermal;
    document.getElementById('gs-anim').textContent = s.anim;
    document.getElementById('gs-sched').textContent = s.sched;
    document.getElementById('gs-io').textContent = s.io;

    // Show status
    const statusEl = document.getElementById('game-mode-status');
    const statusText = document.getElementById('game-mode-status-text');
    statusEl.style.display = 'flex';
    statusText.textContent = `Game Mode: ACTIVE — ${name} (${GENRE_DISPLAY[genre]})`;
    statusEl.style.background = 'var(--teal)';

    setStatus(`Game Mode activated for ${name}!`, 'success');
}

async function daemonToggle(action) {
    const statusEl = document.getElementById('daemon-status');
    if (action === 'start') {
        setStatus('Starting daemon...', 'warning');
        const r = await shell(`${MODDIR}/scripts/gamemode_daemon.sh start 2>/dev/null`);
        statusEl.textContent = r.trim();
        setStatus('Daemon started!', 'success');
    } else if (action === 'stop') {
        setStatus('Stopping daemon...', 'warning');
        const r = await shell(`${MODDIR}/scripts/gamemode_daemon.sh stop 2>/dev/null`);
        statusEl.textContent = r.trim();
        setStatus('Daemon stopped!', 'success');
    } else {
        const r = await shell(`${MODDIR}/scripts/gamemode_daemon.sh status 2>/dev/null`);
        statusEl.textContent = r.trim();
    }
}

function applyGameGenre(genre) {
    const settings = GENRE_SETTINGS[genre];
    if (!settings) return;

    setStatus(`Applying ${GENRE_DISPLAY[genre]} preset...`, 'warning');
    shell(`${MODDIR}/scripts/apply_gamemode.sh apply com.custom.${genre} 2>/dev/null`);

    document.getElementById('gs-cpu').textContent = settings.cpu;
    document.getElementById('gs-gpu').textContent = settings.gpu;
    document.getElementById('gs-ram').textContent = settings.ram;
    document.getElementById('gs-net').textContent = settings.net;
    document.getElementById('gs-thermal').textContent = settings.thermal;
    document.getElementById('gs-anim').textContent = settings.anim;
    document.getElementById('gs-sched').textContent = settings.sched;
    document.getElementById('gs-io').textContent = settings.io;

    const statusEl = document.getElementById('game-mode-status');
    const statusText = document.getElementById('game-mode-status-text');
    statusEl.style.display = 'flex';
    statusText.textContent = `Game Mode: ACTIVE — ${GENRE_DISPLAY[genre]} Genre`;
    statusEl.style.background = 'var(--teal)';

    setStatus(`${GENRE_DISPLAY[genre]} preset applied!`, 'success');
}

async function gameOff() {
    setStatus('Disabling Game Mode...', 'warning');
    await shell(`${MODDIR}/scripts/apply_gamemode.sh off 2>/dev/null`);

    document.getElementById('gs-cpu').textContent = '-';
    document.getElementById('gs-gpu').textContent = '-';
    document.getElementById('gs-ram').textContent = '-';
    document.getElementById('gs-net').textContent = '-';
    document.getElementById('gs-thermal').textContent = '-';
    document.getElementById('gs-anim').textContent = '-';
    document.getElementById('gs-sched').textContent = '-';
    document.getElementById('gs-io').textContent = '-';

    const statusEl = document.getElementById('game-mode-status');
    statusEl.style.display = 'flex';
    statusEl.style.background = 'var(--yellow)';
    document.getElementById('game-mode-status-text').textContent = 'Game Mode: OFF — All settings reverted';

    setStatus('Game Mode disabled, defaults restored', 'success');
}

// ============================================================
// DASHBOARD
// ============================================================

function formatBytes(bytes) {
    if (!bytes || bytes === 0) return '0';
    if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + ' GB';
    if (bytes >= 1048576) return (bytes / 1048576).toFixed(0) + ' MB';
    if (bytes >= 1024) return (bytes / 1024).toFixed(0) + ' KB';
    return bytes + ' B';
}

function formatFreq(khz) {
    if (!khz || khz === 0) return '-';
    return (khz / 1000).toFixed(0) + ' MHz';
}

function formatUptime(seconds) {
    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    if (d > 0) return `${d}d ${h}h ${m}m`;
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
}

function progressColor(pct) {
    if (pct >= 90) return 'red';
    if (pct >= 70) return 'orange';
    if (pct >= 40) return 'yellow';
    return 'green';
}

function tempColor(millideg) {
    const c = millideg / 1000;
    if (c >= 85) return 'red';
    if (c >= 70) return 'orange';
    if (c >= 50) return 'yellow';
    return 'green';
}

let dashRefreshTimer = null;
let dashIsRefreshing = false;

function showDashRefreshStart() {
    dashIsRefreshing = true;
    // Activate refresh bar
    const bar = document.getElementById('dash-refresh-bar');
    const progress = document.getElementById('dash-refresh-progress');
    if (bar) {
        bar.classList.add('active');
        progress.classList.remove('done');
        progress.style.width = '40%';
    }
    // Show spinners on cards
    document.querySelectorAll('.dash-stat-spinner').forEach(s => s.classList.add('active'));
    // Pause live badge animation briefly
    const badge = document.getElementById('live-badge');
    if (badge) { badge.textContent = 'UPDATING'; badge.style.color = 'var(--orange)'; }
}

function showDashRefreshDone() {
    dashIsRefreshing = false;
    const bar = document.getElementById('dash-refresh-bar');
    const progress = document.getElementById('dash-refresh-progress');
    if (progress) {
        progress.style.width = '100%';
        progress.classList.add('done');
    }
    setTimeout(() => {
        if (bar) bar.classList.remove('active');
        if (progress) { progress.classList.remove('done'); progress.style.width = '0%'; }
    }, 800);
    // Hide spinners
    document.querySelectorAll('.dash-stat-spinner').forEach(s => s.classList.remove('active'));
    // Flash cards
    document.querySelectorAll('.dash-stat-card').forEach(c => {
        c.classList.remove('flash');
        void c.offsetWidth; // reflow
        c.classList.add('flash');
    });
    // Restore live badge
    const badge = document.getElementById('live-badge');
    if (badge) { badge.textContent = 'LIVE'; badge.style.color = ''; }
}

async function loadDashboard() {
    const loading = document.getElementById('dash-loading');
    const content = document.getElementById('dash-content');
    const isInitial = content.style.display === 'none';
    if (isInitial) {
        loading.style.display = 'flex';
        content.style.display = 'none';
    } else {
        showDashRefreshStart();
    }

    const raw = await shell(`${MODDIR}/scripts/dashboard.sh 2>/dev/null`);
    if (isInitial) loading.style.display = 'none';

    try {
        if (!raw || !raw.trim()) throw new Error('Empty response from dashboard.sh');
        const jsonStart = raw.indexOf('{');
        const jsonEnd = raw.lastIndexOf('}');
        if (jsonStart === -1 || jsonEnd === -1) throw new Error('No JSON in output: ' + raw.substring(0, 200));
        const jsonStr = raw.substring(jsonStart, jsonEnd + 1);
        // Sanitize: remove trailing commas before } or ] which are invalid JSON
        const sanitized = jsonStr.replace(/,\s*([}\]])/g, '$1');
        const d = JSON.parse(sanitized);

        // Device Card
        const dv = d.device || {};
        document.getElementById('dash-device').innerHTML = `
            <div class="dash-device-name">${escapeHtml(dv.brand || '')} ${escapeHtml(dv.model || '-')}</div>
            <div class="dash-device-meta">
                <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="5" y="2" width="14" height="20" rx="2"/></svg> Android ${escapeHtml(dv.android || '-')}</span>
                <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="4" y="4" width="16" height="16" rx="2"/></svg> ${escapeHtml(dv.soc || '-')}</span>
                <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg> Up ${formatUptime(dv.uptime || 0)}</span>
                <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="3"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42"/></svg> ${escapeHtml(dv.kernel || '-')}</span>
            </div>`;

        // Stats Cards
        const cpu = d.cpu || {};
        const gpu = d.gpu || {};
        const ram = d.ram || {};
        const storage = d.storage || {};
        const battery = d.battery || {};
        const thermal = d.thermal || {};
        const net = d.network || {};

        let statsHtml = '';

        // CPU
        statsHtml += `
            <div class="dash-stat-card">
                <div class="dash-stat-spinner"></div>
                <div class="dash-stat-header">
                    <span class="dash-stat-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="4" y="4" width="16" height="16" rx="2"/></svg> CPU</span>
                </div>
                <div class="dash-stat-value" style="color:var(--teal-dark)">${cpu.usage || 0}%</div>
                <div class="dash-stat-sub">${cpu.online || 0}/${cpu.cores || 0} cores &middot; ${formatFreq(cpu.cur_freq)}</div>
                <div class="dash-stat-sub">${escapeHtml(cpu.governor || '-')} &middot; Load: ${escapeHtml(cpu.load || '-')}</div>
                <div class="dash-progress"><div class="dash-progress-fill ${progressColor(cpu.usage || 0)}" style="width:${cpu.usage || 0}%"></div></div>
            </div>`;

        // GPU
        statsHtml += `
            <div class="dash-stat-card">
                <div class="dash-stat-spinner"></div>
                <div class="dash-stat-header">
                    <span class="dash-stat-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="2" y="6" width="20" height="12" rx="2"/></svg> GPU</span>
                </div>
                <div class="dash-stat-value" style="color:var(--blue-dark)">${gpu.busy || 0}%</div>
                <div class="dash-stat-sub">${escapeHtml(gpu.vendor || '-')} &middot; ${formatFreq(gpu.clock)}</div>
                <div class="dash-stat-sub">${escapeHtml(gpu.governor || '-')}</div>
                <div class="dash-progress"><div class="dash-progress-fill ${progressColor(gpu.busy || 0)}" style="width:${gpu.busy || 0}%"></div></div>
            </div>`;

        // RAM
        const ramPct = ram.usage_pct || 0;
        statsHtml += `
            <div class="dash-stat-card">
                <div class="dash-stat-spinner"></div>
                <div class="dash-stat-header">
                    <span class="dash-stat-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="2" y="6" width="20" height="12" rx="2"/></svg> RAM</span>
                </div>
                <div class="dash-stat-value" style="color:var(--orange-dark)">${ramPct}%</div>
                <div class="dash-stat-sub">${formatBytes((ram.used || 0) * 1024)} / ${formatBytes((ram.total || 0) * 1024)}</div>
                <div class="dash-stat-sub">${formatBytes((ram.available || 0) * 1024)} free</div>
                <div class="dash-progress"><div class="dash-progress-fill ${progressColor(ramPct)}" style="width:${ramPct}%"></div></div>
            </div>`;

        // Storage
        const storPct = storage.data_pct || 0;
        statsHtml += `
            <div class="dash-stat-card">
                <div class="dash-stat-spinner"></div>
                <div class="dash-stat-header">
                    <span class="dash-stat-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/></svg> Storage</span>
                </div>
                <div class="dash-stat-value" style="color:var(--purple-dark)">${storPct}%</div>
                <div class="dash-stat-sub">${formatBytes((storage.data_used || 0) * 1024)} / ${formatBytes((storage.data_total || 0) * 1024)}</div>
                <div class="dash-stat-sub">${formatBytes((storage.data_avail || 0) * 1024)} free</div>
                <div class="dash-progress"><div class="dash-progress-fill ${progressColor(storPct)}" style="width:${storPct}%"></div></div>
            </div>`;

        // Battery
        const batLvl = battery.level ?? -1;
        const batColor = batLvl >= 50 ? 'green' : batLvl >= 20 ? 'yellow' : 'red';
        statsHtml += `
            <div class="dash-stat-card">
                <div class="dash-stat-spinner"></div>
                <div class="dash-stat-header">
                    <span class="dash-stat-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="1" y="6" width="18" height="12" rx="2"/><line x1="23" y1="10" x2="23" y2="14"/></svg> Battery</span>
                </div>
                <div class="dash-stat-value" style="color:var(--teal-dark)">${batLvl >= 0 ? batLvl + '%' : '-'}</div>
                <div class="dash-stat-sub">${escapeHtml(battery.status || '-')} &middot; ${escapeHtml(battery.health || '-')}</div>
                <div class="dash-stat-sub">${escapeHtml(battery.technology || '-')}</div>
                <div class="dash-progress"><div class="dash-progress-fill ${batColor}" style="width:${batLvl >= 0 ? batLvl : 0}%"></div></div>
            </div>`;

        // Thermal
        const tColor = tempColor(thermal.max_temp || 0);
        const tempC = thermal.max_temp ? (thermal.max_temp / 1000).toFixed(1) : '-';
        statsHtml += `
            <div class="dash-stat-card">
                <div class="dash-stat-spinner"></div>
                <div class="dash-stat-header">
                    <span class="dash-stat-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M14 14.76V3.5a2.5 2.5 0 0 0-5 0v11.26a4.5 4.5 0 1 0 5 0z"/></svg> Thermal</span>
                </div>
                <div class="dash-stat-value" style="color:var(--${tColor === 'red' ? 'red-dark' : tColor === 'orange' ? 'orange-dark' : 'teal-dark'})">${tempC}C</div>
                <div class="dash-stat-sub">${thermal.zones || 0} zones &middot; ${escapeHtml(thermal.hottest || '-')}</div>
            </div>`;

        // Network
        statsHtml += `
            <div class="dash-stat-card">
                <div class="dash-stat-spinner"></div>
                <div class="dash-stat-header">
                    <span class="dash-stat-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M5 12.55a11 11 0 0 1 14.08 0"/></svg> Network</span>
                </div>
                <div class="dash-stat-value" style="color:var(--blue-dark)">${escapeHtml(net.wifi || '-')}</div>
                <div class="dash-stat-sub">${escapeHtml(net.ssid || '-')}</div>
                <div class="dash-stat-sub">${escapeHtml(net.ip || '-')} &middot; ${escapeHtml(net.tcp_congestion || '-')}</div>
                <div class="dash-stat-sub">RX: ${formatBytes(net.rx || 0)} TX: ${formatBytes(net.tx || 0)}</div>
            </div>`;

        document.getElementById('dash-stats').innerHTML = statsHtml;

        // Last updated timestamp
        const now = new Date();
        const timeStr = now.toLocaleTimeString([], {hour:'2-digit', minute:'2-digit', second:'2-digit'});

        // Module Status
        const mod = d.module || {};
        document.getElementById('dash-module').innerHTML = `
            <div class="dash-module-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg> Module Status</div>
            <div class="dash-module-row"><span class="k">HWUI Renderer</span><span class="v active">${escapeHtml(mod.hwui || '-')}</span></div>
            <div class="dash-module-row"><span class="k">RenderEngine</span><span class="v active">${escapeHtml(mod.renderengine || '-')}</span></div>
            <div class="dash-module-row"><span class="k">Animation Scale</span><span class="v">${escapeHtml(mod.animation || '-')}</span></div>
            <div class="dash-module-row"><span class="k">Game Mode</span><span class="v ${mod.gamemode === 'ACTIVE' ? 'active' : 'off'}">${escapeHtml(mod.gamemode || 'OFF')}</span></div>
            ${mod.game_pkg ? `<div class="dash-module-row"><span class="k">Active Game</span><span class="v active">${escapeHtml(mod.game_pkg)}</span></div>` : ''}
            <div class="dash-module-row"><span class="k">Active Profile</span><span class="v">${escapeHtml(mod.active_profile || 'None')}</span></div>
            <div class="dash-module-row" id="dash-server-row"><span class="k">WebUI Server</span><span class="v" id="dash-server-status">checking...</span></div>
            <div class="dash-module-row"><span class="k">Last Updated</span><span class="v" style="color:var(--teal)"> ${timeStr}</span></div>

            <div class="dash-quick-actions">
                <button class="dash-action-btn" onclick="applyAll()">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
                    Apply All
                </button>
                <button class="dash-action-btn" onclick="runBenchmark('all')">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>
                    Benchmark
                </button>
                <button class="dash-action-btn" onclick="applyAutoDetect()">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
                    Auto Detect
                </button>
                <button class="dash-action-btn" onclick="runDetect()">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
                    Scan HW
                </button>
                <button class="dash-action-btn" onclick="saveConfig()">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/></svg>
                    Save Config
                </button>
                <button class="dash-action-btn" onclick="rebootDevice()">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
                    Reboot
                </button>
            </div>`;

        content.style.display = 'block';
        if (!isInitial) showDashRefreshDone();
        setStatus('Dashboard loaded!', 'success');
    } catch (e) {
        if (isInitial) {
            loading.innerHTML = `<div class="profile-empty">Error: ${escapeHtml(e.message)}</div>`;
            loading.style.display = 'flex';
        } else {
            showDashRefreshDone();
        }
        console.log('[Dashboard Raw]', raw);
    }
}

// ============================================================
// WEBUI SERVER STATUS
// ============================================================

async function checkServerStatus() {
    const el = document.getElementById('dash-server-status');
    if (!el) return;

    // If we're in KernelSU, server status isn't relevant
    if (typeof ksu !== 'undefined' && ksu.exec) {
        el.textContent = 'KernelSU native';
        el.classList.add('active');
        return;
    }

    // Check if HTTP server is running
    try {
        const resp = await fetch(`${API_URL}/api/exec`, {
            method: 'POST',
            body: 'echo ok',
            signal: AbortSignal.timeout(2000)
        });
        const text = await resp.text();
        if (text.trim() === 'ok') {
            el.innerHTML = `Running <span style="font-size:10px;color:var(--text-muted)">${API_URL}</span>`;
            el.classList.add('active');
        } else {
            el.textContent = 'Error';
        }
    } catch (e) {
        el.textContent = 'Offline — run: webui_server.sh start';
        el.classList.add('off');
    }

    // Also update settings sheet server status if visible
    const settingsEl = document.getElementById('settings-server-status');
    if (settingsEl) {
        settingsEl.textContent = el.textContent;
        settingsEl.className = el.className;
    }
}

async function toggleWebUIServer() {
    setStatus('Toggling WebUI server...', 'warning');
    try {
        // Try KernelSU first
        if (typeof ksu !== 'undefined' && ksu.exec) {
            const result = await shell('MODDIR=$(ls /data/adb/modules/opengl_renderer_ultimate 2>/dev/null || echo /data/adb/modules/opengl_renderer_ultimate); "$MODDIR/scripts/webui_server.sh" toggle 2>&1');
            setStatus(result.trim() || 'Server toggled', 'success');
            checkServerStatus();
            return;
        }

        // Try HTTP API
        const resp = await fetch(`${API_URL}/api/exec`, {
            method: 'POST',
            body: 'MODDIR=/data/adb/modules/opengl_renderer_ultimate; "$MODDIR/scripts/webui_server.sh" toggle 2>&1',
        });
        const result = await resp.text();
        setStatus(result.trim() || 'Server toggled', 'success');
        checkServerStatus();
    } catch (e) {
        setStatus('Cannot reach server. Run: sh webui_server.sh toggle', 'error');
    }
}

// ============================================================
// INIT
// ============================================================

document.addEventListener('DOMContentLoaded', () => {
    loadDashboard();
    loadDeviceInfo();
    loadConfig();
    loadProfiles();
    renderGameList();
    loadCustomGames();
    checkServerStatus();
    setStatus('Ready \u2014 OpenGL Renderer Ultimate v3.2.11');

    // Auto-refresh dashboard every 10 seconds (realtime)
    const refreshInterval = setInterval(() => {
        const dashTab = document.getElementById('tab-home');
        const badge = document.getElementById('live-badge');
        if (dashTab && dashTab.classList.contains('active')) {
            if (badge) { badge.classList.remove('paused'); badge.textContent = 'LIVE'; badge.style.color = ''; }
            loadDashboard();
        } else {
            if (badge) { badge.classList.add('paused'); badge.textContent = 'PAUSED'; }
        }
    }, 10000);

    // Update live badge on tab switch
    document.querySelectorAll('.bottom-nav-item[data-tab]').forEach(btn => {
        btn.addEventListener('click', () => {
            const badge = document.getElementById('live-badge');
            if (!badge) return;
            setTimeout(() => {
                const dashTab = document.getElementById('tab-home');
                if (dashTab && dashTab.classList.contains('active')) {
                    badge.classList.remove('paused');
                    badge.textContent = 'LIVE';
                    badge.style.color = '';
                } else {
                    badge.classList.add('paused');
                    badge.textContent = 'PAUSED';
                }
            }, 250);
        });
    });

    // Auto-refresh device info when CPU/GPU/RAM/Thermal tabs are active
    setInterval(() => {
        const cpuTab = document.getElementById('tab-cpu');
        const gpuTab = document.getElementById('tab-gpu');
        const ramTab = document.getElementById('tab-ram');
        const thermalTab = document.getElementById('tab-thermal');
        const active = document.querySelector('.tab-content.active');
        if (active && (active === cpuTab || active === gpuTab || active === ramTab || active === thermalTab)) {
            loadDeviceInfo();
        }
    }, 5000);
});
