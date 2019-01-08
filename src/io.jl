"""
	open(f::FormattedFilename, args...; kwargs...) -> ::FormattedIO
	open(fn::Function, f::FormattedFilename, args...; kwargs...)

Similar to `open(filename::AbstractString, ...)`, but operates on the filename
wrapped by `f`.

Format/coding information associated with `f` is preserved in the returned
`FormattedIO`. To specify format/coding or guess from the IO stream, use
`specify` or `guess` on the returned object.

# Examples

```julia
julia> f1 = guess("insulin.dat")
FormattedFilename: insulin.dat
 unknown format

julia> f2 = open(f1)
FormattedIO: IOStream(<file insulin.dat>)
 unknown format

julia> f3 = guess(f2)
FormattedIO: IOStream(<file insulin.dat>)
 inferred format: structure/x-pdb
```
"""
function Base.open(f::FormattedFilename, args...; kwargs...)
	io = open(f.resource, args...; kwargs...)
	FormattedIO(io, f.format, f.coding, f.format_guesses, f.coding_guesses)
end

function Base.open(fn::Function, f::FormattedFilename, args...; kwargs...)
	f2 = open(f, args...; kwargs...)
	results = fn(f2)
	close(f2)
	results
end

"""
	close(f::FormattedIO)

Similar to `close(io::IO)`, closes the wrapped IO stream.
"""
Base.close(f::FormattedIO) = close(f.resource)

"""
	read(f::Formatted, args...; kwargs...) -> value

Similar to `read(filename|io, ...)`, but operates on the resource wrapped by
`f`, reading a single object.

The format and coding are resolved, and appropriate reader and decoder are
selected.

# Examples

```julia
julia> f1 = guess("insulin.pdb")
FormattedFilename: insulin.pdb
 inferred format: structure/x-pdb

julia> mol1 = read(f1)
...

julia> f2 = guess("myoglobin.gro")
FormattedFilename: myoglobin.gro
 inferred format: structure/x-gro

julia> f3 = open(f2)
FormattedIO: IOStream(<file myoglobin.gro>)
 inferred format: structure/x-gro

julia> mol2 = read(f3)
```
"""
function Base.read(f::Formatted, args...; kwargs...)
	format = resolveformat(f)
    coding = resolvecoding(f)
	read(f.resource, format, coding, args...; kwargs...)
end

function Base.read(filename::AbstractString, format::MIME,
		coding::Union{MIME,Nothing}, args...; kwargs...)
	open(filename) do io
		read(io, format, coding, args...; kwargs...)
	end
end

function Base.read(io::IO, format::MIME, coding::Union{MIME,Nothing}, args...;
		kwargs...)
	reader = resolvereader(format)
	if coding == nothing
		read(reader, format, io, args...; kwargs...)
	else
		decoder = resolvedecoder(coding)
		io2 = TranscodingStream(decoder(), io)
		read(reader, format, io2, args...; kwargs...)
	end
end

"""
	read(reader, mime, io, args...; kwargs...) -> value

Read `value` from `io` using a specific `reader` for the `mime` format.

This version should be specialised for readers that wish to handle a specific
format. Arguments `args` and `kwargs` make it possible to customize reader
behavior.

# Arguments

	reader::FormatHandler
	mime::MIME
	io::IO

# Example

```julia
struct MyIO <: Formats.FormatHandler end

function Base.read(::MyIO, ::MIME"image/png", io::IO)
	# Read data from io to construct value x...
	x
end
```
"""
Base.read

"""
	read!(f::Formatted, output, args...; kwargs...) -> value

Similar to `read!(filename|io, array, ...)`, but operates on the resource
wrapped by `f`, reading a single object into pre-allocated `output`.

The format and coding are resolved, and appropriate reader and decoder are
selected.

# Examples

```julia
julia> f1 = guess("insulin.pdb")
FormattedFilename: insulin.pdb
 inferred format: structure/x-pdb

julia> mol1 = MolecularModel()
0-particle 0-key MolecularModel

julia> read!(f1, mol1)
[...]

julia> f2 = guess("myoglobin.gro")
FormattedFilename: myoglobin.gro
 inferred format: structure/x-gro

julia> f3 = open(f2)
FormattedIO: IOStream(<file myoglobin.gro>)
 inferred format: structure/x-gro

julia> mol2 = MolecularModel()
0-particle 0-key MolecularModel

julia> read!(f3, mol2)
```
"""
function Base.read!(f::FormattedFilename, output, args...; kwargs...)
	open(f) do f2
		read!(f2, output, args...; kwargs...)
	end
end

function Base.read!(f::FormattedIO, output, args...; kwargs...)
	format = resolveformat(f)
	reader = resolvereader(format)
    coding = resolvecoding(f)
	if coding == nothing
		io = f.resource
	else
		decoder = resolvedecoder(coding)
		io = TranscodingStream(decoder(), f.resource)
	end
	read!(reader, format, io, output, args...; kwargs...)
end

"""
	read!(reader, mime, io, output, args...; kwargs...) -> output

Read `value` from `io` into pre-allocated `output` using a specific `reader`
for the `mime` format.

This version should be specialised for readers that wish to handle a specific
format and reading into pre-allocated output. Arguments `args` and `kwargs`
make it possible to customize reader behavior.
"""
Base.read!

"""
	write(f::Formatted, x, args...; kwargs...)

Similar to `write(filename|io, x, ...)`, but operates on the resource wrapped by
`f`.

The format and coding are resolved, and appropriate writer and encoder are
selected.

# Examples

```julia
julia> mol = read(guess("insulin.pdb"))
[...]

julia> write(guess("insulin.gro"), mol)
[...]

julia> f = open(guess("insulin.gro.gz"), "w")
FormattedIO: IOStream(<file insulin.gro.gz>)
 inferred format: structure/x-gro
 inferred coding: application/gzip

julia> write(f, mol)
[...]
```
"""
function Base.write(f::Formatted, x, args...; kwargs...)
	format = resolveformat(f)
	coding = resolvecoding(f)
	write(f.resource, format, coding, x, args...; kwargs...)
end

function Base.write(filename::AbstractString, format::MIME,
		coding::Union{MIME,Nothing}, x, args...; kwargs...)
	open(filename, "w") do io
		write(io, format, coding, x, args...; kwargs...)
	end
end

function Base.write(io::IO, format::MIME, coding::Union{MIME,Nothing}, x,
		args...; kwargs...)
	writer = resolvewriter(format)
	pos0 = position(io)
	if coding == nothing
		write(writer, format, io, x, args...; kwargs...)
	else
		encoder = resolveencoder(coding)
		io2 = TranscodingStream(encoder(), io)
		write(writer, format, io2, x, args...; kwargs...)
	end
	position(io) - pos0
end

"""
	write(writer, mime, io, x, args...; kwargs...)

Write `x` to `io` using a specific `writer` for the `mime` format.

This version should be specialised for writers that wish to handle a specific
format. Arguments `args` and `kwargs` make it possible to customize writer
behavior.

# Arguments

	writer::FormatHandler
	mime::Type{<:MIME}
	io::IO

# Example

```julia
struct MyIO <: Formats.FormatHandler end

function Base.write(::MyIO, ::MIME"image/png", io::IO, x::MyT)
	# Write x to the io stream...
end
```
"""
Base.write

"""
	openf(filename|formatted, args...; kwargs...) -> ::FormattedIO
    openf(fn::Function, filename|formatted, args...; kwargs...)

Similar to `open(filename, ...)`, but format/coding are guessed automatically if
missing.

# Arguments

	filename::AbstractString
    formatted::Formatted

This is a convenience function; `openf(filename)` is equivalent to
`open(formatted(filename))`.
"""
openf(filename::Union{AbstractString,FormattedFilename}, args...; kwargs...) =
        open(formatted(filename), args...; kwargs...)

function openf(fn::Function, filename::Union{AbstractString,FormattedFilename},
        args...; kwargs...)
    f = open(filename, args...; kwargs...)
    results = fn(f)
    close(f)
	results
end

"""
	readf(filename|io|formatted, args...; kwargs...) -> value

Similar to `read(filename|io, ...)`, but format/coding are guessed automatically
if missing.

# Arguments

    filename::AbstractString
    io::IO
    formatted::Formatted

This is a convenience function; `readf(resource)` is equivalent to
`read(formatted(resource))`.
"""
readf(resource::Union{AbstractString,IO,Formatted}, args...; kwargs...) =
        read(formatted(resource), args...; kwargs...)

"""
	readf!(filename|io|formatted, output, args...; kwargs...) -> output

Similar to `read!(filename|io, output, ...)`, but format/coding are guessed
automatically if missing.

# Arguments

    filename::AbstractString
    io::IO
    formatted::Formatted

This is a convenience function; `readf!(resource, output)` is equivalent to
`read!(formatted(resource), output)`.
"""
readf!(resource::Union{AbstractString,IO,Formatted}, output, args...;
		kwargs...) = read!(formatted(resource), output, args...; kwargs...)

"""
	writef(filename|io|formatted, x, args...; kwargs...)

Similar to `write(filename|io, x, ...)`, but format/coding are guessed
automatically if unspecified.

# Arguments

    filename::AbstractString
    io::IO
    formatted::Formatted

This is a convenience function; `writef(resource, x)` is equivalent to
`write(formatted(resource), x)`.
"""
writef(resource::Union{AbstractString,IO,Formatted}, x, args...; kwargs...) =
        write(formatted(resource), x, args...; kwargs...)
