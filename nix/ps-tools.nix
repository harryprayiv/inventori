{ pkgs, lib ? pkgs.lib, name }:

let
  appConfig = import ./config.nix { inherit name; };
  servePort = toString appConfig.vite.port;

  # Copy static assets into dist/ so miniserve has everything in one place
  setup-dist = pkgs.writeShellApplication {
    name          = "setup-dist";
    runtimeInputs = [ ];
    text          = ''
      mkdir -p dist
      cp -f index.html    dist/index.html
      cp -f styles.css    dist/styles.css
      cp -f inventory.json dist/inventory.json
    '';
  };

  serve-cleanup = pkgs.writeShellApplication {
    name          = "serve-cleanup";
    runtimeInputs = [ pkgs.lsof ];
    text          = ''
      PORT="${servePort}"
      if lsof -i :"$PORT" > /dev/null 2>&1; then
        echo "Found processes on port $PORT"
        lsof -t -i :"$PORT" | while read -r pid; do
          if [ -n "$pid" ]; then
            echo "Killing process $pid"
            kill "$pid" 2>/dev/null || true
            RETRIES=0
            while kill -0 "$pid" 2>/dev/null; do
              RETRIES=$((RETRIES+1))
              if [ "$RETRIES" -eq 5 ]; then
                kill -9 "$pid" 2>/dev/null || true
                break
              fi
              sleep 1
            done
          fi
        done
      else
        echo "No processes found on port $PORT"
      fi
    '';
  };

  serve = pkgs.writeShellApplication {
    name          = "serve";
    runtimeInputs = [ pkgs.miniserve ];
    text          = ''
      echo "Serving dist/ on http://localhost:${servePort}"
      exec miniserve dist/ \
        --port ${servePort} \
        --index index.html \
        --spa
    '';
  };

  esbuild-watch = pkgs.writeShellApplication {
    name          = "esbuild-watch";
    runtimeInputs = [ pkgs.esbuild ];
    text          = ''
      mkdir -p dist
      exec esbuild output/Main/index.js \
        --bundle \
        --outfile=dist/main.js \
        --platform=browser \
        --format=esm \
        --sourcemap \
        --watch
    '';
  };

  spago-watch = pkgs.writeShellApplication {
    name          = "spago-watch";
    runtimeInputs = [ pkgs.entr pkgs.spago-unstable ];
    text          = ''find {src,test} | entr -s "spago $*" '';
  };

  concurrent = pkgs.writeShellApplication {
    name          = "concurrent";
    runtimeInputs = [ pkgs.concurrently ];
    text          = ''
      concurrently \
        --color "auto" \
        --prefix "[{command}]" \
        --handle-input \
        --restart-tries 10 \
        "$@"
    '';
  };

  bundle = pkgs.writeShellApplication {
    name          = "bundle";
    runtimeInputs = [
      pkgs.purs
      pkgs.purs-backend-es
      pkgs.esbuild
      pkgs.nodejs_20
      pkgs.spago-unstable
    ];
    text          = ''
      set -euo pipefail

      OUT_DIR="dist"
      MINIFY=true
      MODE=es

      for arg in "$@"; do
        case "$arg" in
          --no-minify) MINIFY=false ;;
          --mode=*)    MODE="''${arg#--mode=}" ;;
          --out=*)     OUT_DIR="''${arg#--out=}" ;;
          --help)
            echo "Usage: bundle [--mode es|simple] [--no-minify] [--out <dir>]"
            exit 0 ;;
        esac
      done

      mkdir -p "$OUT_DIR"
      cp -f index.html     "$OUT_DIR/index.html"
      cp -f styles.css     "$OUT_DIR/styles.css"
      cp -f inventory.json "$OUT_DIR/inventory.json"

      echo "--- Step 1: spago build (mode: $MODE)..."
      spago build
      echo "    Done."

      if [ "$MODE" = "es" ]; then
        echo "--- Step 2: purs-backend-es bundle-app (DCE)..."
        purs-backend-es bundle-app \
          --main Main \
          --to "$OUT_DIR/bundle-pre-minify.js" \
          --no-source-maps
        PRE_BYTES=$(wc -c < "$OUT_DIR/bundle-pre-minify.js")
        echo "    Pre-minify: $PRE_BYTES bytes"
        INPUT_JS="$OUT_DIR/bundle-pre-minify.js"
      else
        if [ ! -f "output/Main/index.js" ]; then
          echo "ERROR: output/Main/index.js not found after spago build"
          exit 1
        fi
        PRE_BYTES=$(wc -c < output/Main/index.js)
        echo "    Main/index.js: $PRE_BYTES bytes"
        INPUT_JS="output/Main/index.js"
      fi

      echo "--- Step 3: esbuild..."
      if [ "$MINIFY" = "true" ]; then
        esbuild "$INPUT_JS" \
          --bundle \
          --outfile="$OUT_DIR/main.js" \
          --format=iife \
          --platform=browser \
          --minify \
          --sourcemap=external
      else
        esbuild "$INPUT_JS" \
          --bundle \
          --outfile="$OUT_DIR/main.js" \
          --format=iife \
          --platform=browser \
          --sourcemap=external
      fi

      rm -f "$OUT_DIR/bundle-pre-minify.js"

      FINAL_BYTES=$(wc -c < "$OUT_DIR/main.js")
      REDUCTION=$(( (PRE_BYTES - FINAL_BYTES) * 100 / PRE_BYTES ))
      echo "    Final: $FINAL_BYTES bytes ($REDUCTION% reduction)"
      echo ""
      echo "Output: $OUT_DIR/main.js"
    '';
  };

  dev = pkgs.writeShellApplication {
    name          = "dev";
    runtimeInputs = [ setup-dist spago-watch esbuild-watch serve concurrent ];
    text          = ''
      setup-dist
      concurrent "spago-watch build" esbuild-watch serve
    '';
  };

in {
  inherit serve serve-cleanup setup-dist esbuild-watch spago-watch concurrent bundle dev;
}