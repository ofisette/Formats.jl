# Formats

Julia package to read, write and detect formatted data, based on MIME types.

The `Formats` module provides functions to `guess` and to `specify` the format
(e.g. `image/png`) and, optionally, the coding (e.g. `application/gzip`)
associated with a filename or an IO stream. The `Formatted` objects created by
these functions can be passed to the standard IO functions `open`, `close`,
`read` and `write`. Three convenience functions are also provided for
interactive use; `openf`, `readf` and `writef` behave like their counterparts
from the `Base` module, but also detect formatted data automatically. Package
developers can integrate their IO routines with `Formats` by specializing
functions and registering the formats or codings they support. If multiple
loaded packages support the same formats, a “favorite” system allows choosing a
reader/writer. `Formats` also reports ambiguities, such as multiple formats
using the same filename extension.

## License

You can use Formats under the terms of the MIT “Expat” License; see
`LICENSE.md`.

## Installation

Formats is not a registered package. You can add it to your Julia environment by
giving the URL to its repository:

```julia
Pkg.add("https:://github.com/ofisette/Formats.jl")
```

## Documentation

This documentation gives an overview of the types and functions that form
Formats’s public interface. For details, refer to the documentation of
individual functions and types, available in the REPL. The *basic usage* section of the documentation is also accessible from the REPL:

```julia
?Formats
```

Formats provides a basic framework to manage formatted data. However, Formats
itself does not define any specific format or function to read or write objects
in specific formats. All examples below rely on FormatCodec for gzip
transcoding, and on Dorothy for reading/writing PDB and GRO molecular
structures.

### Basic usage

```julia
using Formats       # Framework for data formats and codings (this package)
using FormatCodecs  # Codecs for common codings (separate package)
```

To guess the format of a file from its filename:

```julia
f = guess("insulin.pdb")
```

The coding (such as data compression) is also automatically detected:

```julia
f = guess("myoglobin.gro.gz")
```

To guess a format based on a stream’s content:

```julia
f = guess(open("insulin.pdb"))
```

To specify a known file format and, optionally, a coding:

```julia
f1 = specify("insulin.dat", "structure/x-pdb")
f2 = specify("myoglobin.dat", "structure/x-gro", "application/gzip")
```

To check if a format was specified or guessed:

```julia
f = guess("kitten.png")
isspecified(f)  # -> False
isguessed(f)    # -> True
isunknown(f)    # -> False
isambiguous(f)  # -> False
```

To get the detected or specified format/coding:

```julia
h = guess("myoglobin.gro.gz")
getformat(h)  # -> "structure/x-gro"
getcoding(h)  # -> "application/gzip"
```

Functions `guess` and `specify` return a `Formatted` object which can be passed
to `read` and `write`:

```julia
mol = read(specify("insulin.pdb", "structure/x-pdb"))
write(guess("insulin.gro.gz"), mol)
```

Function `read!` targets a pre-allocated output object:

```julia
read!(guess("insulin.gro.gz"), mol))
```

`Formatted` objects created from a filename can be `open`ed, returning a new
`Formatted` object wrapping the underlying IO stream, and those wrapping IO
streams can be `close`d:

```julia
f1 = guess("insulin.pdb")
f2 = open(f1)
close(f2)
```

Functions `guess` and `specify` can be called with an existing `Formatted`
object. This will guess format and coding again, or override previous guesses
with the specified information:

```julia
f1 = guess("insulin.dat")
f2 = specify(f1, "structure/x-pdb")
f3 = guess(open(f2))
```

Convenience functions `openf`, `readf`, `readf!` and `writef` automatically
guess format and coding if passed a filename or IO stream, but preserve the
existing format/coding information if passed a `Formatted` object:

```julia
mol1 = readf("insulin.pdb")
writef("insulin.gro", mol1)
mol2 = read(openf("myoglobin.gro"))
writef(specify("myoglobin.dat", "structure/x-pdb"), mol2)
readf!("lysozyme.pdb", mol3)
```

### MIME types

A MIME type (also media type or content type) is a two-part identifier for file
formats (see https://en.wikipedia.org/wiki/Media_type). Common examples are
“application/gzip”, “image/png” and “text/html”. The `Base` module of Julia
defines the `MIME` parametric type. For convenience, most functions in Formats
accept and return strings (e.g. `"image/png"`), which are converted to and from
`MIME` as necessary.

### Guessing and specifying formats and codings

Functions can be used to `guess` and `specify` the format/coding associated with
a filename or IO stream. These two functions return `Formatted` (abstract type)
objects which wrap the original resource and add format and coding information.
A third function, `formatted`, will `guess` the format and coding if called with
an filename or IO, but will return any `Formatted` object unchanged, preserving
existing format/coding information.

Functions `isspecified` and `isguessed` can be used on `Formatted` objects to
check if a format was specified or guessed. Function `isunknown` tests whether
the format of a resource was neither specified nor guessed successfully. If a
file extension or stream signature is associated with multiple possible formats,
ambiguities can arise; there will be multiple guesses as to the possible format
of a resource. This can be checked with `isambiguous`.

Functions `getformat` and `getcoding` can be used on `Formatted` objects, unless
their format is unknown, in which case an error is thrown.

### Reading and writing formatted data

`Formatted` objects can be passed to standard IO functions `read`, `read!` and
`write`. In addition, `Formatted` objects wrapping filenames can be `open`ed,
and those wrapping IO streams can be `close`d. No other IO functions are
supported on `Formatted` objects, but `resource` can be used to get the
underlying filename or IO stream of a `Formatted` object to query or manipulate
it directly.

Formats offers four convenience functions: `openf`, `readf`, `readf!` and
`writef` (where `f` stands for formatted). These operate just like their
counterparts `open`, `read`, `read!` and `write`, but will automatically guess
the file format when acting on a filename or IO stream. When acting on a
`Formatted` object, they will preserve the existing format/coding information.

### Adding formats and codings

To integrate your own packages with formats, your first need to add the
formats/codings you wish to support to the Formats registry. This is done via
the `addformat` and `addcoding` functions, which are not exported by default.
Multiple registrations of a format or coding will be ignored, so you do not need
to worry about other packages also registering the formats you support.

To take advantage of the `guess` function, you should use `addextention` and
`addsignature` (not exported by default) to register the filename extensions and
stream signatures associated with your formats. Multiple registrations of the
same extension or signature for the same format will be ignored. However,
associating the same extension or signature to multiple formats will result in a
warning since it introduces ambiguities when guessing formats.

### Implementing readers, writers and codecs

Once you have registered the necessary formats, extensions and signatures, you
need to create a type that identifies your reader/writer. This should be a
singleton specializing the `FormatHandler` abstract type (not exported by
default). This new type should then be registered using `addreader` and
`addwriter` (also not exported by default). Finally, you must specialize `read`,
`read!` and/or `write`; the specific signatures are documented.

Codings can be associated with their appropriate decoder/encoder using
`setencoder` and `setdecoder` (not exported by default). Note that there is no
`addencoder`/`adddecoder`; only a single decoder and encoder can be associated
with a given coding.

### Registration inside a module must happen at initialization time

Inside a module, functions that modify the global `registry` in `Formats` must
be called inside `__init__`, the optional special function that initializes the
module. This means that any call to `addformat`, `addcoding`, `addextention`,
`addsignature`, `addreader`, `addwriter`, `setencoder`, or `setdecoder` in your
packages must happen inside `__init__`. This is also true of `preferreader` and
`preferwriter`, but these functions should not be called outside the main
environment anyway since choosing readers/writers should be done by the users
rather than package developers.

Calling the above-mentionned functions in the global scope of a module rather
than inside `__init__` will give unexpected results: in the main environment,
the `Formats` `registry` will be empty. This is because these functions modify
the global variable `registry` in Format from a different module. This must
happen at run-time and not when pre-compiling the module.

### Selecting a specific reader/writer

When multiple readers or writers are available for a given format, a specific
reader or writer can be selected, either for a single format or on a global
basis. This is done via `preferreader` and `preferwriter` (not exported by
default).

## See also

* [FormatCodecs](https://github.com/ofisette/FormatCodecs.jl):
  Integrate common transcoders with Formats (recommended).

* [FormatStreams](https://github.com/ofisette/FormatStreams.jl):
  Read and write series of formatted objects in IO streams.

* [TranscodingStreams](https://github.com/bicycle1885/TranscodingStreams.jl):
  The basis for codings, encoders and decoders in Formats (dependency).

* [FileIO](https://github.com/JuliaIO/FileIO.jl):
  The inspiration for Formats; a different package that provides similar
  functionality, but with a more centralized approach.
