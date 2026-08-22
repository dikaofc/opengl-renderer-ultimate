package com.openglrenderer.tile;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.StrictMode;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Switch;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SettingsActivity extends Activity {

    private static final String CONF_DIR = "/data/local/opengl_renderer";
    private static final String CONF_FILE = CONF_DIR + "/config.conf";
    private static final String MODDIR = "/data/adb/modules/opengl_renderer_ultimate";

    private final ExecutorService exec = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    // CPU
    private Spinner spinnerCpuGov;
    private Switch switchGovLock;
    private EditText editCpuMax, editCpuMin, editInputBoost, editBoostMs;

    // GPU
    private Spinner spinnerGpuGov;
    private Switch switchGpuOc, switchForceClk, switchForceBus;
    private EditText editGpuMax, editIdleTimer;

    // RAM
    private EditText editSwappiness, editDirtyRatio, editDirtyBg, editVfsCache, editMinFree;
    private Spinner spinnerIoSched;
    private EditText editReadahead, editZram;

    // Network
    private Spinner spinnerTcp, spinnerQdisc, spinnerFastopen;
    private Switch switchMtu;
    private EditText editSomaxconn;

    // Thermal
    private Spinner spinnerThermal;
    private EditText editCpuThrottle, editGpuThrottle, editPolling;

    // OpenGL
    private Spinner spinnerRenderer, spinnerRe;
    private EditText editHwuiCpu, editTexCache, editLayerCache;
    private Switch switchFramePacing, switchMultiThread;

    // Animation
    private Spinner spinnerWinAnim, spinnerTransAnim, spinnerAnimDur;

    // Kernel
    private Switch switchAutogroup, switchChildRuns, switchFsync, switchBpf, switchSysrq;

    private TextView tvStatus;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_settings);

        StrictMode.ThreadPolicy.Builder builder = new StrictMode.ThreadPolicy.Builder();
        StrictMode.setThreadPolicy(builder.permitAll().build());

        bindViews();
        setupButtons();
        loadConfig();
    }

    private void bindViews() {
        // CPU
        spinnerCpuGov = findViewById(R.id.spinner_cpu_gov);
        switchGovLock = findViewById(R.id.switch_gov_lock);
        editCpuMax = findViewById(R.id.edit_cpu_max);
        editCpuMin = findViewById(R.id.edit_cpu_min);
        editInputBoost = findViewById(R.id.edit_input_boost);
        editBoostMs = findViewById(R.id.edit_boost_ms);

        // GPU
        spinnerGpuGov = findViewById(R.id.spinner_gpu_gov);
        switchGpuOc = findViewById(R.id.switch_gpu_oc);
        switchForceClk = findViewById(R.id.switch_force_clk);
        switchForceBus = findViewById(R.id.switch_force_bus);
        editGpuMax = findViewById(R.id.edit_gpu_max);
        editIdleTimer = findViewById(R.id.edit_idle_timer);

        // RAM
        editSwappiness = findViewById(R.id.edit_swappiness);
        editDirtyRatio = findViewById(R.id.edit_dirty_ratio);
        editDirtyBg = findViewById(R.id.edit_dirty_bg);
        editVfsCache = findViewById(R.id.edit_vfs_cache);
        editMinFree = findViewById(R.id.edit_min_free);
        spinnerIoSched = findViewById(R.id.spinner_io_sched);
        editReadahead = findViewById(R.id.edit_readahead);
        editZram = findViewById(R.id.edit_zram);

        // Network
        spinnerTcp = findViewById(R.id.spinner_tcp);
        spinnerQdisc = findViewById(R.id.spinner_qdisc);
        spinnerFastopen = findViewById(R.id.spinner_fastopen);
        switchMtu = findViewById(R.id.switch_mtu);
        editSomaxconn = findViewById(R.id.edit_somaxconn);

        // Thermal
        spinnerThermal = findViewById(R.id.spinner_thermal);
        editCpuThrottle = findViewById(R.id.edit_cpu_throttle);
        editGpuThrottle = findViewById(R.id.edit_gpu_throttle);
        editPolling = findViewById(R.id.edit_polling);

        // OpenGL
        spinnerRenderer = findViewById(R.id.spinner_renderer);
        spinnerRe = findViewById(R.id.spinner_re);
        editHwuiCpu = findViewById(R.id.edit_hwui_cpu);
        editTexCache = findViewById(R.id.edit_tex_cache);
        editLayerCache = findViewById(R.id.edit_layer_cache);
        switchFramePacing = findViewById(R.id.switch_frame_pacing);
        switchMultiThread = findViewById(R.id.switch_multi_thread);

        // Animation
        spinnerWinAnim = findViewById(R.id.spinner_win_anim);
        spinnerTransAnim = findViewById(R.id.spinner_trans_anim);
        spinnerAnimDur = findViewById(R.id.spinner_anim_dur);

        // Kernel
        switchAutogroup = findViewById(R.id.switch_autogroup);
        switchChildRuns = findViewById(R.id.switch_child_runs);
        switchFsync = findViewById(R.id.switch_fsync);
        switchBpf = findViewById(R.id.switch_bpf);
        switchSysrq = findViewById(R.id.switch_sysrq);

        tvStatus = findViewById(R.id.tv_status);
    }

    private void setupButtons() {
        Button btnApply = findViewById(R.id.btn_apply);
        Button btnSave = findViewById(R.id.btn_save);
        Button btnReset = findViewById(R.id.btn_reset);
        Button btnReboot = findViewById(R.id.btn_reboot);

        btnApply.setOnClickListener(v -> applySettings());
        btnSave.setOnClickListener(v -> saveConfig());
        btnReset.setOnClickListener(v -> resetDefaults());
        btnReboot.setOnClickListener(v -> rebootDevice());
    }

    // ============================================================
    // CONFIG READ / WRITE
    // ============================================================

    private void loadConfig() {
        setStatus("Loading config...");
        exec.execute(() -> {
            try {
                String raw = execRoot("cat " + CONF_FILE + " 2>/dev/null");
                if (raw == null || raw.trim().isEmpty()) {
                    mainHandler.post(() -> setStatus("No config found, using defaults"));
                    return;
                }

                mainHandler.post(() -> {
                    for (String line : raw.split("\n")) {
                        if (line.startsWith("#") || !line.contains("=")) continue;
                        String[] parts = line.split("=", 2);
                        if (parts.length < 2) continue;
                        String key = parts[0].trim();
                        String val = parts[1].trim();
                        applyConfigValue(key, val);
                    }
                    setStatus("Config loaded!");
                });
            } catch (Exception e) {
                mainHandler.post(() -> setStatus("Load error: " + e.getMessage()));
            }
        });
    }

    private void applyConfigValue(String key, String val) {
        switch (key) {
            // CPU
            case "cpu_governor": setSpinner(spinnerCpuGov, val); break;
            case "governor_lock": switchGovLock.setChecked("1".equals(val) || "true".equals(val)); break;
            case "cpu_max_freq": editCpuMax.setText(val); break;
            case "cpu_min_freq": editCpuMin.setText(val); break;
            case "input_boost_freq": editInputBoost.setText(val); break;
            case "input_boost_ms": editBoostMs.setText(val); break;

            // GPU
            case "gpu_governor": setSpinner(spinnerGpuGov, val); break;
            case "gpu_overclock_enabled": switchGpuOc.setChecked("1".equals(val) || "true".equals(val)); break;
            case "gpu_freq_max": editGpuMax.setText(val); break;
            case "adreno_force_clk": switchForceClk.setChecked("1".equals(val) || "true".equals(val)); break;
            case "adreno_force_bus": switchForceBus.setChecked("1".equals(val) || "true".equals(val)); break;
            case "adreno_idle_timer": editIdleTimer.setText(val); break;

            // RAM
            case "swappiness": editSwappiness.setText(val); break;
            case "dirty_ratio": editDirtyRatio.setText(val); break;
            case "dirty_background_ratio": editDirtyBg.setText(val); break;
            case "vfs_cache_pressure": editVfsCache.setText(val); break;
            case "min_free_kbytes": editMinFree.setText(val); break;
            case "io_scheduler": setSpinner(spinnerIoSched, val); break;
            case "readahead": editReadahead.setText(val); break;
            case "zram_size": editZram.setText(val); break;

            // Network
            case "tcp_congestion": setSpinner(spinnerTcp, val); break;
            case "default_qdisc": setSpinner(spinnerQdisc, val); break;
            case "tcp_fastopen": setSpinnerByPrefix(spinnerFastopen, val); break;
            case "tcp_mtu_probe": switchMtu.setChecked("1".equals(val) || "true".equals(val)); break;
            case "somaxconn": editSomaxconn.setText(val); break;

            // Thermal
            case "thermal_mode": setSpinner(spinnerThermal, val); break;
            case "cpu_throttle_temp": editCpuThrottle.setText(val); break;
            case "gpu_throttle_temp": editGpuThrottle.setText(val); break;
            case "thermal_polling": editPolling.setText(val); break;

            // OpenGL
            case "opengl_renderer": setSpinner(spinnerRenderer, val); break;
            case "renderengine_backend": setSpinner(spinnerRe, val); break;
            case "hwui_cpu_time": editHwuiCpu.setText(val); break;
            case "hwui_texture_cache": editTexCache.setText(val); break;
            case "hwui_layer_cache": editLayerCache.setText(val); break;
            case "hwui_frame_pacing": switchFramePacing.setChecked("1".equals(val) || "true".equals(val)); break;
            case "hwui_multi_thread": switchMultiThread.setChecked("1".equals(val) || "true".equals(val)); break;

            // Animation
            case "window_animation_scale": setSpinner(spinnerWinAnim, val); break;
            case "transition_animation_scale": setSpinner(spinnerTransAnim, val); break;
            case "animator_duration_scale": setSpinner(spinnerAnimDur, val); break;

            // Kernel
            case "sched_autogroup": switchAutogroup.setChecked("1".equals(val) || "true".equals(val)); break;
            case "sched_child_runs_first": switchChildRuns.setChecked("1".equals(val) || "true".equals(val)); break;
            case "fsync": switchFsync.setChecked("1".equals(val) || "true".equals(val)); break;
            case "bpf_jit": switchBpf.setChecked("1".equals(val) || "true".equals(val)); break;
            case "sysrq": switchSysrq.setChecked("1".equals(val) || "true".equals(val)); break;
        }
    }

    private void saveConfig() {
        setStatus("Saving config...");
        exec.execute(() -> {
            try {
                StringBuilder conf = new StringBuilder("# OpenGL Renderer Ultimate\n");
                conf.append("cpu_governor=").append(getSpinnerVal(spinnerCpuGov)).append("\n");
                conf.append("governor_lock=").append(switchGovLock.isChecked() ? "1" : "0").append("\n");
                conf.append("cpu_max_freq=").append(getText(editCpuMax)).append("\n");
                conf.append("cpu_min_freq=").append(getText(editCpuMin)).append("\n");
                conf.append("input_boost_freq=").append(getText(editInputBoost)).append("\n");
                conf.append("input_boost_ms=").append(getText(editBoostMs)).append("\n");
                conf.append("gpu_governor=").append(getSpinnerVal(spinnerGpuGov)).append("\n");
                conf.append("gpu_overclock_enabled=").append(switchGpuOc.isChecked() ? "1" : "0").append("\n");
                conf.append("gpu_freq_max=").append(getText(editGpuMax)).append("\n");
                conf.append("adreno_force_clk=").append(switchForceClk.isChecked() ? "1" : "0").append("\n");
                conf.append("adreno_force_bus=").append(switchForceBus.isChecked() ? "1" : "0").append("\n");
                conf.append("adreno_idle_timer=").append(getText(editIdleTimer)).append("\n");
                conf.append("swappiness=").append(getText(editSwappiness)).append("\n");
                conf.append("dirty_ratio=").append(getText(editDirtyRatio)).append("\n");
                conf.append("dirty_background_ratio=").append(getText(editDirtyBg)).append("\n");
                conf.append("vfs_cache_pressure=").append(getText(editVfsCache)).append("\n");
                conf.append("min_free_kbytes=").append(getText(editMinFree)).append("\n");
                conf.append("io_scheduler=").append(getSpinnerVal(spinnerIoSched)).append("\n");
                conf.append("readahead=").append(getText(editReadahead)).append("\n");
                conf.append("zram_size=").append(getText(editZram)).append("\n");
                conf.append("tcp_congestion=").append(getSpinnerVal(spinnerTcp)).append("\n");
                conf.append("default_qdisc=").append(getSpinnerVal(spinnerQdisc)).append("\n");
                conf.append("tcp_fastopen=").append(getSpinnerFirstNum(spinnerFastopen)).append("\n");
                conf.append("tcp_mtu_probe=").append(switchMtu.isChecked() ? "1" : "0").append("\n");
                conf.append("somaxconn=").append(getText(editSomaxconn)).append("\n");
                conf.append("thermal_mode=").append(getSpinnerVal(spinnerThermal)).append("\n");
                conf.append("cpu_throttle_temp=").append(getText(editCpuThrottle)).append("\n");
                conf.append("gpu_throttle_temp=").append(getText(editGpuThrottle)).append("\n");
                conf.append("thermal_polling=").append(getText(editPolling)).append("\n");
                conf.append("opengl_renderer=").append(getSpinnerVal(spinnerRenderer)).append("\n");
                conf.append("renderengine_backend=").append(getSpinnerVal(spinnerRe)).append("\n");
                conf.append("hwui_cpu_time=").append(getText(editHwuiCpu)).append("\n");
                conf.append("hwui_texture_cache=").append(getText(editTexCache)).append("\n");
                conf.append("hwui_layer_cache=").append(getText(editLayerCache)).append("\n");
                conf.append("hwui_frame_pacing=").append(switchFramePacing.isChecked() ? "1" : "0").append("\n");
                conf.append("hwui_multi_thread=").append(switchMultiThread.isChecked() ? "1" : "0").append("\n");
                conf.append("window_animation_scale=").append(getSpinnerVal(spinnerWinAnim)).append("\n");
                conf.append("transition_animation_scale=").append(getSpinnerVal(spinnerTransAnim)).append("\n");
                conf.append("animator_duration_scale=").append(getSpinnerVal(spinnerAnimDur)).append("\n");
                conf.append("sched_autogroup=").append(switchAutogroup.isChecked() ? "1" : "0").append("\n");
                conf.append("sched_child_runs_first=").append(switchChildRuns.isChecked() ? "1" : "0").append("\n");
                conf.append("fsync=").append(switchFsync.isChecked() ? "1" : "0").append("\n");
                conf.append("bpf_jit=").append(switchBpf.isChecked() ? "1" : "0").append("\n");
                conf.append("sysrq=").append(switchSysrq.isChecked() ? "1" : "0").append("\n");

                // Write with shell
                String escaped = conf.toString().replace("'", "'\\''");
                execRoot("echo '" + escaped + "' > " + CONF_FILE);
                execRoot("chmod 644 " + CONF_FILE);
                mainHandler.post(() -> setStatus("Config saved!"));
            } catch (Exception e) {
                mainHandler.post(() -> setStatus("Save error: " + e.getMessage()));
            }
        });
    }

    // ============================================================
    // APPLY SETTINGS (live apply via sysfs/setprop)
    // ============================================================

    private void applySettings() {
        setStatus("Applying settings...");
        exec.execute(() -> {
            try {
                StringBuilder cmds = new StringBuilder();

                // OpenGL + Animation (setprop)
                cmds.append("setprop debug.hwui.renderer ").append(getSpinnerVal(spinnerRenderer)).append(" && ");
                cmds.append("setprop debug.renderengine.backend ").append(getSpinnerVal(spinnerRe)).append(" && ");
                cmds.append("setprop debug.hwui.target_cpu_time_percent ").append(getText(editHwuiCpu)).append(" && ");
                cmds.append("setprop debug.hwui.texture_cache_size ").append(getText(editTexCache)).append(" && ");
                cmds.append("setprop debug.hwui.layer_cache_size ").append(getText(editLayerCache)).append(" && ");
                cmds.append("setprop debug.hwui.frame_pacing ").append(boolToStr(switchFramePacing.isChecked())).append(" && ");
                cmds.append("setprop debug.hwui.use_multi_threaded_pipeline ").append(boolToStr(switchMultiThread.isChecked())).append(" && ");
                cmds.append("setprop persist.debug.hwui.renderer ").append(getSpinnerVal(spinnerRenderer)).append(" && ");
                cmds.append("setprop persist.debug.renderengine.backend ").append(getSpinnerVal(spinnerRe)).append(" && ");
                cmds.append("setprop window_animation_scale ").append(getSpinnerVal(spinnerWinAnim)).append(" && ");
                cmds.append("setprop transition_animation_scale ").append(getSpinnerVal(spinnerTransAnim)).append(" && ");
                cmds.append("setprop animator_duration_scale ").append(getSpinnerVal(spinnerAnimDur)).append(" && ");
                cmds.append("setprop persist.window_animation_scale ").append(getSpinnerVal(spinnerWinAnim)).append(" && ");
                cmds.append("setprop persist.transition_animation_scale ").append(getSpinnerVal(spinnerTransAnim)).append(" && ");
                cmds.append("setprop persist.animator_duration_scale ").append(getSpinnerVal(spinnerAnimDur)).append(" && ");

                // CPU governor
                if (switchGovLock.isChecked()) {
                    String gov = getSpinnerVal(spinnerCpuGov);
                    cmds.append("for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -w \"$i\" ] && echo ").append(gov).append(" > \"$i\" 2>/dev/null; done && ");
                }

                // CPU max freq
                String cpuMax = getText(editCpuMax);
                if (!cpuMax.isEmpty()) {
                    cmds.append("for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do [ -w \"$i\" ] && echo ").append(cpuMax).append(" > \"$i\" 2>/dev/null; done && ");
                }

                // GPU
                cmds.append("KGSL=/sys/class/kgsl/kgsl-3d0 && ");
                cmds.append("[ -w \"$KGSL/devfreq/governor\" ] && echo ").append(switchGpuOc.isChecked() ? "performance" : getSpinnerVal(spinnerGpuGov)).append(" > \"$KGSL/devfreq/governor\" 2>/dev/null && ");
                String gpuMax = getText(editGpuMax);
                if (!gpuMax.isEmpty()) {
                    cmds.append("[ -w \"$KGSL/max_gpuclk\" ] && echo ").append(gpuMax).append(" > \"$KGSL/max_gpuclk\" 2>/dev/null && ");
                }
                if (switchForceClk.isChecked()) cmds.append("[ -w \"$KGSL/force_clk_on\" ] && echo 1 > \"$KGSL/force_clk_on\" && ");
                if (switchForceBus.isChecked()) cmds.append("[ -w \"$KGSL/force_bus_on\" ] && echo 1 > \"$KGSL/force_bus_on\" && ");

                // RAM
                cmds.append("echo ").append(getText(editSwappiness)).append(" > /proc/sys/vm/swappiness && ");
                cmds.append("echo ").append(getText(editDirtyRatio)).append(" > /proc/sys/vm/dirty_ratio && ");
                cmds.append("echo ").append(getText(editDirtyBg)).append(" > /proc/sys/vm/dirty_background_ratio && ");
                cmds.append("echo ").append(getText(editVfsCache)).append(" > /proc/sys/vm/vfs_cache_pressure && ");
                cmds.append("echo ").append(getText(editMinFree)).append(" > /proc/sys/vm/min_free_kbytes && ");

                // I/O
                cmds.append("for q in /sys/block/*/queue/scheduler; do [ -w \"$q\" ] && echo ").append(getSpinnerVal(spinnerIoSched)).append(" > \"$q\" 2>/dev/null; done && ");

                // Network
                cmds.append("echo ").append(getSpinnerVal(spinnerTcp)).append(" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null && ");
                cmds.append("echo ").append(getSpinnerVal(spinnerQdisc)).append(" > /proc/sys/net/core/default_qdisc 2>/dev/null");

                // Kernel sysfs
                cmds.append(" && echo ").append(boolToNum(switchAutogroup.isChecked())).append(" > /proc/sys/kernel/sched_autogroup_enabled 2>/dev/null");
                cmds.append(" && echo ").append(boolToNum(switchChildRuns.isChecked())).append(" > /proc/sys/kernel/sched_child_runs_first 2>/dev/null");

                execRoot(cmds.toString());
                mainHandler.post(() -> setStatus("Settings applied! Reboot recommended."));
            } catch (Exception e) {
                mainHandler.post(() -> setStatus("Apply error: " + e.getMessage()));
            }
        });
    }

    // ============================================================
    // UTILITIES
    // ============================================================

    private void resetDefaults() {
        editCpuMax.setText("");
        editCpuMin.setText("");
        editInputBoost.setText("0");
        editBoostMs.setText("50");
        editGpuMax.setText("");
        editIdleTimer.setText("50");
        editSwappiness.setText("100");
        editDirtyRatio.setText("40");
        editDirtyBg.setText("10");
        editVfsCache.setText("50");
        editMinFree.setText("12288");
        editReadahead.setText("2048");
        editZram.setText("");
        editSomaxconn.setText("4096");
        editCpuThrottle.setText("95000");
        editGpuThrottle.setText("95000");
        editPolling.setText("2000");
        editHwuiCpu.setText("25");
        editTexCache.setText("96");
        editLayerCache.setText("48");

        setSpinner(spinnerCpuGov, "performance");
        setSpinner(spinnerGpuGov, "performance");
        setSpinner(spinnerIoSched, "bfq");
        setSpinner(spinnerTcp, "bbr");
        setSpinner(spinnerQdisc, "fq");
        setSpinner(spinnerThermal, "performance");
        setSpinner(spinnerRenderer, "skiagl");
        setSpinner(spinnerRe, "skiagl");
        setSpinner(spinnerWinAnim, "0.5");
        setSpinner(spinnerTransAnim, "0.5");
        setSpinner(spinnerAnimDur, "0.5");

        switchGovLock.setChecked(true);
        switchGpuOc.setChecked(true);
        switchForceClk.setChecked(true);
        switchForceBus.setChecked(true);
        switchMtu.setChecked(true);
        switchFramePacing.setChecked(true);
        switchMultiThread.setChecked(true);
        switchChildRuns.setChecked(true);
        switchFsync.setChecked(true);
        switchBpf.setChecked(true);
        switchAutogroup.setChecked(false);
        switchSysrq.setChecked(false);

        setStatus("Defaults restored");
    }

    private void rebootDevice() {
        exec.execute(() -> {
            execRoot("svc power reboot");
            mainHandler.post(() -> Toast.makeText(this, "Rebooting...", Toast.LENGTH_SHORT).show());
        });
    }

    private void setStatus(String msg) {
        tvStatus.setText(msg);
    }

    private String execRoot(String command) throws Exception {
        Process process = Runtime.getRuntime().exec(new String[]{"su", "-c", command});
        BufferedReader stdout = new BufferedReader(new InputStreamReader(process.getInputStream()));
        BufferedReader stderr = new BufferedReader(new InputStreamReader(process.getErrorStream()));
        StringBuilder output = new StringBuilder();
        String line;
        while ((line = stdout.readLine()) != null) output.append(line).append("\n");
        while ((line = stderr.readLine()) != null) output.append(line).append("\n");
        process.waitFor();
        return output.toString().trim();
    }

    private void setSpinner(Spinner spinner, String value) {
        for (int i = 0; i < spinner.getCount(); i++) {
            if (spinner.getItemAtPosition(i).toString().equals(value)) {
                spinner.setSelection(i);
                return;
            }
        }
    }

    private void setSpinnerByPrefix(Spinner spinner, String prefix) {
        for (int i = 0; i < spinner.getCount(); i++) {
            if (spinner.getItemAtPosition(i).toString().startsWith(prefix + " ")) {
                spinner.setSelection(i);
                return;
            }
        }
    }

    private String getSpinnerVal(Spinner spinner) {
        return spinner.getSelectedItem() != null ? spinner.getSelectedItem().toString() : "";
    }

    private String getSpinnerFirstNum(Spinner spinner) {
        String val = getSpinnerVal(spinner);
        String[] parts = val.split(" ");
        return parts.length > 0 ? parts[0] : "0";
    }

    private String getText(EditText edit) {
        return edit.getText() != null ? edit.getText().toString().trim() : "";
    }

    private String boolToStr(boolean b) { return b ? "1" : "0"; }
    private int boolToNum(boolean b) { return b ? 1 : 0; }
}
