#!/usr/bin/env bash
cd "$( dirname "${BASH_SOURCE[0]}" )"
deno run --allow-run --allow-net server.ts
