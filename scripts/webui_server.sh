#!/system/bin/sh
# ============================================================
# WebUI Server — Universal HTTP server for all root managers
# ============================================================
# Usage:
#   webui_server.sh start   — Start the server
#   webui_server.sh stop    — Stop the server
#   webui_server.sh status  — Check if running
#   webui_server.sh url     — Print the access URL
# ============================================================

MODDIR="${0%/*}/.."
WEBROOT="$MODDIR/webroot"
PIDFILE="/data/local/opengl_renderer/webui_server.pid"
PORT=8080
LOG="/data/local/opengl_renderer/logs/webui_server.log"

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG" 2>/dev/null
}

start_server() {
    # Check if already running
    if [ -f "$PIDFILE" ]; then
        local old_pid=$(cat "$PIDFILE" 2>/dev/null)
        if kill -0 "$old_pid" 2>/dev/null; then
            echo "Server already running (PID $old_pid)"
            return 0
        fi
        rm -f "$PIDFILE"
    fi

    # Ensure log directory exists
    mkdir -p /data/local/opengl_renderer/logs 2>/dev/null

    log "Starting WebUI server on port $PORT"

    # Create CGI directory and exec script
    local cgi_dir="$WEBROOT/cgi-bin"
    mkdir -p "$cgi_dir"
    chmod 0755 "$cgi_dir"

    # Write the API exec handler (served at /api/exec)
    cat > "$cgi_dir/exec.sh" << 'CGI_EOF'
#!/system/bin/sh
# API endpoint — execute shell commands as root

# Read POST body (the command)
if [ "$REQUEST_METHOD" = "POST" ]; then
    BODY=$(dd bs=1 count=4096 2>/dev/null)
elif [ -n "$QUERY_STRING" ]; then
    BODY="$QUERY_STRING"
else
    BODY=""
fi

# URL-decode
BODY=$(echo "$BODY" | sed 's/+/ /g; s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g' | xargs -0 echo -e 2>/dev/null || echo "$BODY")

# Execute and return stdout
if [ -n "$BODY" ]; then
    RESULT=$(eval "$BODY" 2>&1)
    printf "Content-type: text/plain\r\nAccess-Control-Allow-Origin: *\r\n\r\n%s" "$RESULT"
else
    printf "Content-type: text/plain\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
fi
CGI_EOF
    chmod 0755 "$cgi_dir/exec.sh"

    # Ensure webroot is readable
    chmod -R 0755 "$WEBROOT" 2>/dev/null

    # Try busybox httpd first (most common on rooted devices)
    if command -v busybox >/dev/null 2>&1; then
        log "Using busybox httpd"
        # NOTE: busybox httpd -c is for auth config (URL:REALM:USER_FILE:METHOD)
        # Do NOT pass -c — we serve files directly from -h webroot
        busybox httpd -p "$PORT" -h "$WEBROOT" -f 2>> "$LOG" &
        local pid=$!
        sleep 1
        # Verify httpd actually started
        if kill -0 "$pid" 2>/dev/null; then
            echo "$pid" > "$PIDFILE"
            log "Server started (busybox httpd, PID $pid)"
            echo "WebUI server started on http://127.0.0.1:$PORT"
            return 0
        else
            log "ERROR: busybox httpd exited immediately, trying without -f"
            busybox httpd -p "$PORT" -h "$WEBROOT" 2>> "$LOG" &
            pid=$!
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                echo "$pid" > "$PIDFILE"
                log "Server started (busybox httpd no-f, PID $pid)"
                echo "WebUI server started on http://127.0.0.1:$PORT"
                return 0
            fi
            log "ERROR: busybox httpd failed to start"
        fi
    fi

    # Fallback: use a simple shell-based HTTP server with socat
    if command -v socat >/dev/null 2>&1; then
        log "Using socat-based server"
        _start_socat_server
        return $?
    fi

    # Fallback: use nc (netcat)
    if command -v nc >/dev/null 2>&1; then
        log "Using nc-based server"
        _start_nc_server
        return $?
    fi

    log "ERROR: No HTTP server available (no busybox/socat/nc)"
    echo "Error: No HTTP server available. Install BusyBox or use KernelSU Manager."
    return 1
}

_start_socat_server() {
    # Simple socat-based HTTP server
    cat > /data/local/opengl_renderer/webui_handler.sh << 'HANDLER_EOF'
#!/system/bin/sh
MODDIR="__MODDIR__"
WEBROOT="$MODDIR/webroot"
PORT=8080

while true; do
    # Read the HTTP request
    REQUEST=""
    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '\r')
        [ -z "$line" ] && break
        REQUEST="$REQUEST$line"$'\n'
    done

    # Extract path from GET/POST
    METHOD=$(echo "$REQUEST" | head -1 | awk '{print $1}')
    PATH_REQ=$(echo "$REQUEST" | head -1 | awk '{print $2}' | cut -d? -f1)

    # Handle API endpoint
    if echo "$PATH_REQ" | grep -q "^/api/exec"; then
        # Read body for POST
        BODY=""
        if [ "$METHOD" = "POST" ]; then
            CONTENT_LENGTH=$(echo "$REQUEST" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
            if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
                BODY=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)
            fi
        fi

        # Execute command
        RESULT=""
        if [ -n "$BODY" ]; then
            RESULT=$($BODY 2>&1)
        fi

        printf "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nAccess-Control-Allow-Origin: *\r\n\r\n%s" "$RESULT"
        continue
    fi

    # Serve static files
    FILE="$WEBROOT$PATH_REQ"
    [ "$PATH_REQ" = "/" ] && FILE="$WEBROOT/index.html"

    if [ -f "$FILE" ]; then
        # Determine content type
        CT="text/plain"
        case "$FILE" in
            *.html) CT="text/html" ;;
            *.css) CT="text/css" ;;
            *.js) CT="application/javascript" ;;
            *.json) CT="application/json" ;;
            *.png) CT="image/png" ;;
            *.jpg) CT="image/jpeg" ;;
            *.svg) CT="image/svg+xml" ;;
        esac

        SIZE=$(wc -c < "$FILE" 2>/dev/null)
        printf "HTTP/1.0 200 OK\r\nContent-Type: %s\r\nContent-Length: %s\r\n\r\n" "$CT" "$SIZE"
        cat "$FILE"
    else
        printf "HTTP/1.0 404 Not Found\r\nContent-Type: text/plain\r\n\r\n404 Not Found"
    fi
done
HANDLER_EOF
    chmod 0755 /data/local/opengl_renderer/webui_handler.sh
    sed -i "s|__MODDIR__|$MODDIR|g" /data/local/opengl_renderer/webui_handler.sh

    socat TCP-LISTEN:"$PORT",fork,reuseaddr EXEC:"/data/local/opengl_renderer/webui_handler.sh" 2>> "$LOG" &
    local pid=$!
    echo "$pid" > "$PIDFILE"
    log "Server started (socat, PID $pid)"
    echo "WebUI server started on http://127.0.0.1:$PORT"
    return 0
}

_start_nc_server() {
    # Minimal nc-based server (very basic, single-threaded)
    cat > /data/local/opengl_renderer/webui_nc.sh << 'NC_EOF'
#!/system/bin/sh
MODDIR="__MODDIR__"
WEBROOT="$MODDIR/webroot"
PORT=8080

while true; do
    # Accept one connection, serve one request
    {
        REQUEST=""
        while IFS= read -r line; do
            line=$(echo "$line" | tr -d '\r')
            [ -z "$line" ] && break
            REQUEST="$REQUEST$line"$'\n'
        done

        METHOD=$(echo "$REQUEST" | head -1 | awk '{print $1}')
        PATH_REQ=$(echo "$REQUEST" | head -1 | awk '{print $2}' | cut -d? -f1)

        if echo "$PATH_REQ" | grep -q "^/api/exec"; then
            BODY=""
            if [ "$METHOD" = "POST" ]; then
                CONTENT_LENGTH=$(echo "$REQUEST" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
                [ -n "$CONTENT_LENGTH" ] && BODY=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)
            fi
            RESULT=""
            [ -n "$BODY" ] && RESULT=$($BODY 2>&1)
            printf "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nAccess-Control-Allow-Origin: *\r\n\r\n%s" "$RESULT"
        else
            FILE="$WEBROOT$PATH_REQ"
            [ "$PATH_REQ" = "/" ] && FILE="$WEBROOT/index.html"
            if [ -f "$FILE" ]; then
                CT="text/plain"
                case "$FILE" in *.html) CT="text/html";; *.css) CT="text/css";; *.js) CT="application/javascript";; *.png) CT="image/png";; esac
                printf "HTTP/1.0 200 OK\r\nContent-Type: %s\r\n\r\n" "$CT"
                cat "$FILE"
            else
                printf "HTTP/1.0 404\r\n\r\n404"
            fi
        fi
    } | nc -l -p "$PORT" -q 1 2>/dev/null
done
NC_EOF
    chmod 0755 /data/local/opengl_renderer/webui_nc.sh
    sed -i "s|__MODDIR__|$MODDIR|g" /data/local/opengl_renderer/webui_nc.sh

    nohup sh /data/local/opengl_renderer/webui_nc.sh >> "$LOG" 2>&1 &
    local pid=$!
    echo "$pid" > "$PIDFILE"
    log "Server started (nc, PID $pid)"
    echo "WebUI server started on http://127.0.0.1:$PORT"
    return 0
}

stop_server() {
    if [ -f "$PIDFILE" ]; then
        local pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null
            # Also kill children
            kill $(pgrep -P "$pid" 2>/dev/null) 2>/dev/null
            log "Server stopped (PID $pid)"
        fi
        rm -f "$PIDFILE"
        echo "Server stopped"
    else
        echo "Server not running"
    fi
}

status_server() {
    if [ -f "$PIDFILE" ]; then
        local pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "Running (PID $pid) — http://127.0.0.1:$PORT"
            return 0
        fi
    fi
    echo "Not running"
    return 1
}

show_url() {
    local ip=$(ip route get 1.1.1.1 2>/dev/null | head -1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
    [ -z "$ip" ] && ip="127.0.0.1"
    echo "http://$ip:$PORT"
}

# ---- Check if running (returns 0 if running) ----
is_running() {
    if [ -f "$PIDFILE" ]; then
        local pid=$(cat "$PIDFILE" 2>/dev/null)
        [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return 0
    fi
    return 1
}

toggle_server() {
    if is_running; then
        stop_server
    else
        start_server
    fi
}

# ---- Main ----
case "${1:-}" in
    start)  start_server ;;
    stop)   stop_server ;;
    restart) stop_server; sleep 1; start_server ;;
    toggle) toggle_server ;;
    status) status_server ;;
    url)    show_url ;;
    is-running)
        is_running && echo "running" || echo "stopped"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|toggle|status|url|is-running}"
        exit 1
        ;;
esac
