#!/bin/bash
IP=$(ipconfig getifaddr en0)
echo "Your server IP is: $IP"
echo "Update lib/services/config.dart with this IP"
echo ""
echo "Quick update command:"
echo "sed -i '' \"s/serverIP = '.*'/serverIP = '$IP'/\" ~/wardrobe-plus/app/wardrobe_plus/lib/services/config.dart"