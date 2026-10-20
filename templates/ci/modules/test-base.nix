# DO NOT EDIT. Harness: den's public test surface only (flakeModules.denTest + flakeOutputs).
{ inputs, ... }:
{
  imports = [
    inputs.den.flakeModules.denTest
    inputs.den.flakeOutputs.flake
    inputs.den.flakeOutputs.tests
  ];
}
