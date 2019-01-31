module Formats

using TranscodingStreams

export
		infer, specify, formatted, resource,
		isspecified, isinferred, isunknown, isambiguous, getformat, getcoding,
		openf, readf, readf!, writef

include("registry.jl")
include("inference.jl")
include("formatted.jl")
include("io.jl")

"""
Read, write and detect formatted data, based on MIME types

```julia
using Formats       # Framework for data formats and codings (this package)
using FormatCodecs  # Codecs for common codings (separate package)
```

To infer the format of a file from its filename:

```julia
f = infer("insulin.pdb")
```

The coding (such as data compression) is also automatically detected:

```julia
f = infer("myoglobin.gro.gz")
```

To infer a format based on a stream’s content:

```julia
f = infer(open("insulin.pdb"))
```

To specify a known file format and, optionally, a coding:

```julia
f1 = specify("insulin.dat", "structure/x-pdb")
f2 = specify("myoglobin.dat", "structure/x-gro", "application/gzip")
```

To check if a format was specified or inferred:

```julia
f = infer("kitten.png")
isspecified(f)  # -> False
isinferred(f)    # -> True
isunknown(f)    # -> False
isambiguous(f)  # -> False
```

To get the detected or specified format/coding:

```julia
h = infer("myoglobin.gro.gz")
getformat(h)  # -> "structure/x-gro"
getcoding(h)  # -> "application/gzip"
```

Functions `infer` and `specify` return a `Formatted` object which can be passed
to `read` and `write`:

```julia
mol = read(specify("insulin.pdb", "structure/x-pdb"))
write(infer("insulin.gro.gz"), mol)
```

Function `read!` targets a pre-allocated output object:

```julia
read!(infer("insulin.gro.gz"), mol))
```

`Formatted` objects created from a filename can be `open`ed, returning a new
`Formatted` object wrapping the underlying IO stream, and those wrapping IO
streams can be `close`d:

```julia
f1 = infer("insulin.pdb")
f2 = open(f1)
close(f2)
```

Functions `infer` and `specify` can be called with an existing `Formatted`
object. This will infer format and coding again, or override previous guesses
with the specified information:

```julia
f1 = infer("insulin.dat")
f2 = specify(f1, "structure/x-pdb")
f3 = infer(open(f2))
```

Convenience functions `openf`, `readf`, `readf!` and `writef` automatically
infer format and coding if passed a filename or IO stream, but preserve the
existing format/coding information if passed a `Formatted` object:

```julia
mol1 = readf("insulin.pdb")
writef("insulin.gro", mol1)
mol2 = read(openf("myoglobin.gro"))
writef(specify("myoglobin.dat", "structure/x-pdb"), mol2)
readf!("lysozyme.pdb", mol3)
```

Complete documentation is provided in `README.md`.
"""
Formats

end # module
