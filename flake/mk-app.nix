package: description: {
  type = "app";
  program = "${package}/bin/${package.meta.mainProgram}";
  meta = { inherit description; };
}
