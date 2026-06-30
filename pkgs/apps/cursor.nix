{ pkgs }:

# Declarative Cursor AI Code Editor derivation.
# We wrap the officially maintained and pinned code-cursor package in nixpkgs,
# which uses appimageTools.wrapType2 under the hood with verified SRI hashes.
# This ensures 100% reproducible rebuilds without breaking when unversioned upstream URLs update.
pkgs.code-cursor
