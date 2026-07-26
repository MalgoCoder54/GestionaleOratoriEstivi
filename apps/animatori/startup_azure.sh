#!/bin/sh
set -eu

APP_ROOT="${APP_PATH:-$(pwd)}"
REQ_FILE="$APP_ROOT/requirements.txt"
LOCAL_PACKAGES="$APP_ROOT/.python_packages/lib/site-packages"
INSTALL_STAMP="$LOCAL_PACKAGES/.requirements-installed"

cd "$APP_ROOT"

if [ -d "$APP_ROOT/antenv" ]; then
    . "$APP_ROOT/antenv/bin/activate"
elif [ -d "$APP_ROOT/__oryx_packages__" ]; then
    export PYTHONPATH="$APP_ROOT/__oryx_packages__${PYTHONPATH:+:$PYTHONPATH}"
else
    mkdir -p "$LOCAL_PACKAGES"
    if [ ! -f "$INSTALL_STAMP" ] || [ "$REQ_FILE" -nt "$INSTALL_STAMP" ]; then
        python -m pip install --disable-pip-version-check --no-cache-dir --target "$LOCAL_PACKAGES" -r "$REQ_FILE"
        touch "$INSTALL_STAMP"
    fi
    export PYTHONPATH="$LOCAL_PACKAGES${PYTHONPATH:+:$PYTHONPATH}"
fi

exec gunicorn -c gunicorn_config.py run:app --access-logfile - --error-logfile -
