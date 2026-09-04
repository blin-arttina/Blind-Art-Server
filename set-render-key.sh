#!/usr/bin/env bash
# set-render-key.sh
# Prompts for your Render API key and saves it to ~/.bashrc so it
# persists across Termux sessions. Paste the key at the prompt below —
# no need to edit any existing text.

echo "Paste your Render API key below, then press Enter:"
read -r RENDER_KEY

if [ -z "$RENDER_KEY" ]; then
  echo "No key entered — nothing was saved."
  exit 1
fi

echo "export RENDER_API_KEY=\"$RENDER_KEY\"" >> ~/.bashrc
source ~/.bashrc

echo "Saved. RENDER_API_KEY is now set for this and future sessions."
