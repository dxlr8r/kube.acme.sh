# SPDX-FileCopyrightText: 2023 Simen Strange <https://github.com/dxlr8r/kube.acme.sh>
# SPDX-License-Identifier: MIT

{ 
  obj: import 'vendor/lib/dxsonnet/obj.libsonnet',
  test: import 'vendor/lib/dxsonnet/test.libsonnet'
} +
{
  rand(data, modulo) :: 
    std.mod(
      std.foldl(
        function(i,x) i+x, [std.codepoint(c) for c in 
          std.stringChars(std.manifestJsonMinified(data))
      ], 0),
    modulo)
}
