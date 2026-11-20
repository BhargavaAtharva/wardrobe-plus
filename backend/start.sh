#!/bin/bash
# Starts the Wardrobe+ backend and prints the address to enter in the app
# (Profile → Server address). The .local name keeps working when the Wi-Fi
# IP changes; the IP is a fallback for networks that block .local names.
cd "$(dirname "$0")"

if [ ! -d venv ]; then
  echo "Creating virtual environment (first run only)..."
  python3 -m venv venv && venv/bin/pip install -r requirements.txt || exit 1
fi

HOST="$(scutil --get LocalHostName 2>/dev/null).local"
IP="$(ipconfig getifaddr en0 2>/dev/null)"
echo ""
echo "  In the app, set the server address to:"
echo "    http://$HOST:5000"
[ -n "$IP" ] && echo "  or, if that doesn't connect:  http://$IP:5000"
echo ""
exec venv/bin/python3 app.py
