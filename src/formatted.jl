"""
    abstract type Formatted

Wrap a resource (e.g. filename or IO stream), adding format/coding information.

`Formatted` objects can be created with `guess` or `specify` and can be used
with `open`, `close`, `read` and `write`.
"""
abstract type Formatted end

function Base.show(io::IO, ::MIME"text/plain", f::Formatted)
	print(io, "$(typeof(f)): $(f.resource)")
	if f.format == nothing
		if length(f.format_guesses) == 1
			mime = f.format_guesses[1]
			print(io, "\n inferred format: $(mime)")
		elseif length(f.format_guesses) > 1
			print(io, "\n inferred format possibilities:")
			for mime in f.format_guesses
				print(io, "\n  $(mime)")
			end
		else
			print(io, "\n unknown format")
		end
		if length(f.coding_guesses) == 1
			mime = f.coding_guesses[1]
			print(io, "\n inferred coding: $(mime)")
		elseif length(f.coding_guesses) > 1
			print(io, "\n inferred coding possibilities:")
			for mime in f.coding_guesses
				print(io, "\n  $(mime)")
			end
		end
	else
		print(io, "\n specified format: $(f.format)")
		if f.coding != nothing
			print(io, "\n specified coding: $(f.coding)")
		end
	end
end

"""
    resource(f::Formatted) -> resource

Return the resource (e.g. filename or IO stream) wrapped by `f`.
"""
resource(f::Formatted) = f.resource

"""
	struct FormattedFilename <: Formatted

	FormattedFilename(filename::AbstractString) -> formatted

Wrap a `filename`, adding format/coding information.

See also: `Formatted`.
"""
struct FormattedFilename <: Formatted
	resource::String
	format::Union{MIME,Nothing}
	coding::Union{MIME,Nothing}
	format_guesses::Vector{MIME}
	coding_guesses::Vector{MIME}
end

"""
	struct FormattedIO <: Formatted

	FormattedIO(io::IO) -> formatted

Wrap IO stream `io`, adding format/coding information

See also: `Formatted`.
"""
struct FormattedIO <: Formatted
	resource::IO
	format::Union{MIME,Nothing}
	coding::Union{MIME,Nothing}
	format_guesses::Vector{MIME}
	coding_guesses::Vector{MIME}
end

"""
	guess(filename|io|formatted) -> ::Formatted

Guess the format/coding of a resource (filename, IO stream, `Formatted` object).

# Arguments

	filename::AbstractString
	io::IO
	formatted::Formatted

# Examples

Guess format from filename extension:

```julia
julia> f = guess("insulin.pdb")
FormattedFilename: insulin.pdb
 inferred format: structure/x-pdb
```

Guess format from an IO stream:

```julia
julia> io = open("insulin.pdb")
IOStream(<file insulin.pdb>)

julia> f = guess(io)
FormattedIO: IOStream(<file insulin.pdb>)
 inferred format: structure/x-pdb
```

Guess format from a `Formatted` object:

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
guess(filename::AbstractString) =
		FormattedFilename(filename, nothing, nothing, guesscontent(filename)...)

guess(io::IO) = FormattedIO(io, nothing, nothing, guesscontent(io)...)

guess(f::T) where {T<:Formatted} =
        T(f.resource, nothing, nothing, guesscontent(f.resource)...)

"""
	specify(filename|io|formatted, format, [coding]) -> ::Formatted

Specify the format/coding of a resource (filename, IO stream, Formatted object).

# Arguments

	filename::AbstractString
	io::IO
	formatted::Formatted
	format::AbstractString
	coding::AbstractString

# Examples

Specify a format for a filename:

```julia
julia> f = specify("insulin.dat", "structure/x-pdb")
FormattedFilename: insulin.dat
 specified format: structure/x-pdb
```

Specify a format and coding for an IO stream:

```julia
julia> io = open("myoglobin.gro.gz")
IOStream(<file myoglobin.gro.gz>)

julia> f = specify(io, "structure/x-gro", "application/gzip")
FormattedIO: IOStream(<file myoglobin.gro.gz>)
 specified format: structure/x-gro
 specified coding: application/gzip
```

Specify a format for an existing Formatted object:

```julia
julia> f1 = guess("lysozyme.dat")
FormattedFilename: lysozyme.dat
 unknown format

julia> f2 = specify(f1, "structure/x-gro")
FormattedFilename: lysozyme.dat
 specified format: structure/x-gro
```
"""
specify(filename::AbstractString, format::AbstractString,
        coding::AbstractString) = FormattedFilename(filename,
        MIME{Symbol(format)}(), MIME{Symbol(coding)}(), [], [])

specify(filename::AbstractString, format::AbstractString) =
		FormattedFilename(filename, MIME{Symbol(format)}(), nothing, [], [])

specify(io::IO, format::AbstractString, coding::AbstractString) =
		FormattedIO(io, MIME{Symbol(format)}(), MIME{Symbol(coding)}(), [], [])

specify(io::IO, format::AbstractString) =
		FormattedIO(io, MIME{Symbol(format)}(), nothing, [], [])

specify(f::T, format::AbstractString, coding::AbstractString) where
        {T<:Formatted} =
        T(f.resource, MIME{Symbol(format)}(), MIME{Symbol(coding)}(), [], [])

specify(f::T, format::AbstractString) where {T<:Formatted} =
		T(f.resource, MIME{Symbol(format)}(), nothing, [], [])

"""
    formatted(filename|io|formatted) -> ::Formatted

Wrap a resource, preserving existing format/coding information, and guessing
format/coding when there is no such information.

# Arguments

	filename::AbstractString
	io::IO
	formatted::Formatted
"""
formatted(filename::AbstractString) = guess(filename)

formatted(io::IO) = guess(io)

formatted(f::Formatted) = f

"""
    isspecified(f::Formatted) -> ::Bool

Check if the format of `f` was explicitly specified.
"""
isspecified(f::Formatted) = (f.format != nothing)

"""
    isguessed(f::Formatted) -> ::Bool

Check if the format of `f` was guessed from a filename extension or stream
signature.
"""
isguessed(f::Formatted) =
        (f.format == nothing) && (length(f.format_guesses) > 0)

"""
    isunknown(f::Formatted) -> ::Bool

Check if the format of `f` was neither specified nor successfully inferred.
"""
isunknown(f::Formatted) =
        (f.format == nothing) && (length(f.format_guesses) == 0)

"""
    isambiguous(f::Formatted) -> ::Bool

Check if several possible formats were guessed for `f`.
"""
isambiguous(f::Formatted) =
        (f.format == nothing) && (length(f.format_guesses) > 1)

function resolveformat(f::Formatted)
	format = f.format
	if format == nothing
		if length(f.format_guesses) == 0
			error("$(f.resource): could not determine format")
		else
			format = f.format_guesses[1]
			if length(f.format_guesses) > 1
				@warn("$(f.resource): ambiguous format, assuming $(format)")
			end
		end
	end
	format
end

"""
	getformat(f::Formatted) -> ::String

Resolve the format associated with the resource wrapped by `f`.

If the format was not specified and could not be inferred, an error is thrown.
If the format was not specified and several possible formats were inferred, the
first guess is returned, and a warning is recorded.
"""
getformat(f::Formatted) = string(resolveformat(f))

function resolvecoding(f::Formatted)
	coding = f.coding
	if f.format == nothing
		if length(f.coding_guesses) != 0
			coding = f.coding_guesses[1]
			if length(f.coding_guesses) > 1
				@warn("$(f.resource): ambiguous coding, assuming $(coding)")
			end
		end
	end
    coding
end

"""
	getcoding(f::Formatted) -> ::String

Resolve the coding associated with the resource wrapped by `f`.

If the coding was not specified and could not be inferred, no coding is assumed
and `nothing` is returned. If the coding was not specified and several possible
codings were inferred, the first guess is returned, and a warning is recorded.
"""
function getcoding(f::Formatted)
    coding = resolvecoding(f)
    if coding == nothing
        nothing
    else
        string(coding)
    end
end
