package com.openglrenderer.tile;

import android.graphics.drawable.Icon;
import android.os.Handler;
import android.os.Looper;
import android.os.StrictMode;
import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;
import android.util.Log;

import java.io.BufferedReader;
import java.io.InputStreamReader;

public class ServerTileService extends TileService {

    private static final String TAG = "ORETile";
    private static final String MOD_PATH = "/data/adb/modules/opengl_renderer_ultimate";
    private static final String SERVER_SCRIPT = MOD_PATH + "/scripts/webui_server.sh";

    @Override
    public void onStartListening() {
        super.onStartListening();
        updateTileState();
    }

    @Override
    public void onClick() {
        super.onClick();
        // Run toggle in background thread
        new Thread(() -> {
            try {
                // Enable strict mode for network on main thread workaround
                StrictMode.ThreadPolicy.Builder builder = new StrictMode.ThreadPolicy.Builder();
                StrictMode.setThreadPolicy(builder.permitAll().build());

                String result = execRoot("sh " + SERVER_SCRIPT + " toggle 2>&1");
                Log.d(TAG, "Toggle result: " + result);

                // Update tile after toggle
                new Handler(Looper.getMainLooper()).post(this::updateTileState);
            } catch (Exception e) {
                Log.e(TAG, "Toggle failed", e);
            }
        }).start();
    }

    private void updateTileState() {
        new Thread(() -> {
            try {
                String status = execRoot("sh " + SERVER_SCRIPT + " is-running 2>/dev/null");
                boolean running = "running".equals(status.trim());

                new Handler(Looper.getMainLooper()).post(() -> {
                    Tile tile = getQsTile();
                    if (tile == null) return;

                    tile.setLabel(running ? "WebUI ON" : "WebUI OFF");
                    tile.setState(running ? Tile.STATE_ACTIVE : Tile.STATE_INACTIVE);
                    tile.setContentDescription(running ? "WebUI server running" : "WebUI server stopped");
                    tile.updateTile();
                });
            } catch (Exception e) {
                Log.e(TAG, "Status check failed", e);
            }
        }).start();
    }

    private String execRoot(String command) throws Exception {
        Process process = Runtime.getRuntime().exec(new String[]{"su", "-c", command});
        BufferedReader stdout = new BufferedReader(new InputStreamReader(process.getInputStream()));
        BufferedReader stderr = new BufferedReader(new InputStreamReader(process.getErrorStream()));

        StringBuilder output = new StringBuilder();
        String line;
        while ((line = stdout.readLine()) != null) {
            output.append(line).append("\n");
        }
        while ((line = stderr.readLine()) != null) {
            output.append(line).append("\n");
        }

        process.waitFor();
        return output.toString().trim();
    }
}
