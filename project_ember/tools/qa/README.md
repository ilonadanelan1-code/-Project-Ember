# Project Ember QA Pipeline

## Automated GitHub checks

`.github/workflows/ember-qa.yml` pins the official Godot 4.7.2 stable Linux editor binary and verifies its SHA-256 before use. The workflow then:

1. Validates atlas dimensions, hashes, local `res://` references and project metadata.
2. Runs the Godot editor import pass, which imports textures and parses project resources.
3. Runs every `tests/*_smoke_test.gd` script in an isolated temporary user-data directory.
4. Starts the actual strategic map with GL Compatibility under Xvfb/Mesa and saves screenshots at zoom 0.075, 0.76, 0.90 and 1.25.
5. Uploads screenshots, per-zoom render metrics, smoke-test logs and import logs as one workflow artifact, even when a later step fails.

CI screenshots use Mesa software rendering. They validate visual composition and shader output, but their FPS is not an Android GPU benchmark.

## Local commands

```bash
python3 tools/qa/static_validate.py .
GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/qa/run_smoke_tests.sh .
```

For visual capture with a real display or Xvfb:

```bash
mkdir -p artifacts/qa/visual
xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
  Godot_v4.7.2 --path . --rendering-method gl_compatibility \
  --rendering-driver opengl3 --audio-driver Dummy \
  --script res://tools/qa/visual_capture.gd -- artifacts/qa/visual
```

## Android device validation

The CI pipeline deliberately does not pretend Mesa performance is Android performance. On the phone, open the same branch/build, take a map screenshot, and copy the existing in-game Performance Report at zoom 0.900 and 0.075. The assistant can compare those reports with the CI screenshots and logs.

## Activation in the connected repository

The latest v0.17.1 project archive must be published to a dedicated branch once. The companion `INSTALL_EMBER_QA_PIPELINE.sh` Termux bootstrap clones the connected repository, replaces only `project_ember/` on a new QA branch, installs the workflow at repository root, pushes the branch, and opens a PR. It does not modify `main` or PR #4.
