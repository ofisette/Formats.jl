"""
	FormatHandler

Abstract type for format readers/writers

# Example

```julia
struct MyIO <: Formats.FormatHandler end
```
"""
abstract type FormatHandler end

struct FormatRegistry
	formats::Set{MIME}
	codings::Set{MIME}
	extensions::Dict{String,Vector{MIME}}
	signatures::Dict{Vector{UInt8},Vector{MIME}}
	readers::Dict{MIME,Vector{FormatHandler}}
	writers::Dict{MIME,Vector{FormatHandler}}
	favorite_readers::Dict{MIME,FormatHandler}
	favorite_writers::Dict{MIME,FormatHandler}
	global_favorite_readers::Vector{FormatHandler}
	global_favorite_writers::Vector{FormatHandler}
	decoders::Dict{MIME,Type}
	encoders::Dict{MIME,Type}
end

FormatRegistry() = FormatRegistry(
		Set{MIME}(),
		Set{MIME}(),
		Dict{String,Vector{MIME}}(),
		Dict{Vector{UInt8},Vector{MIME}}(),
		Dict{MIME,Vector{FormatHandler}}(),
		Dict{MIME,Vector{FormatHandler}}(),
		Dict{MIME,FormatHandler}(),
		Dict{MIME,FormatHandler}(),
		Vector{FormatHandler}(),
		Vector{FormatHandler}(),
		Dict{MIME,Type}(),
		Dict{MIME,Type}())

Base.copy(registry::FormatRegistry) = FormatRegistry(
		copy(registry.formats),
		copy(registry.codings),
		copy(registry.extensions),
		copy(registry.signatures),
		copy(registry.readers),
		copy(registry.writers),
		copy(registry.favorite_readers),
		copy(registry.favorite_writers),
		copy(registry.global_favorite_readers),
		copy(registry.global_favorite_writers),
		copy(registry.decoders),
		copy(registry.encoders))

function Base.empty!(registry::FormatRegistry)
	empty!(registry.formats)
	empty!(registry.codings)
	empty!(registry.extensions)
	empty!(registry.signatures)
	empty!(registry.readers)
	empty!(registry.writers)
	empty!(registry.favorite_readers)
	empty!(registry.favorite_writers)
	empty!(registry.global_favorite_readers)
	empty!(registry.global_favorite_writers)
	empty!(registry.decoders)
	empty!(registry.encoders)
end

function Base.merge!(registry::FormatRegistry, other::FormatRegistry)
	union!(registry.formats, other.formats)
	union!(registry.formats, other.codings)
	merge!(registry.extensions, other.extensions)
	merge!(registry.signatures, other.signatures)
	merge!(registry.readers, other.readers)
	merge!(registry.writers, other.writers)
	merge!(registry.favorite_readers, other.favorite_readers)
	merge!(registry.favorite_writers, other.favorite_writers)
	append!(registry.global_favorite_readers, other.global_favorite_readers)
	append!(registry.global_favorite_writers, other.global_favorite_writers)
	merge!(registry.decoders, other.decoders)
	merge!(registry.encoders, other.encoders)
end

const registry = FormatRegistry()

function newregistry(f::Function)
	tmp_registry = copy(registry)
	empty!(registry)
	f()
	merge!(registry, tmp_registry)
end

"""
	adddformat(name::AbstractString)

Register MIME type `name` as a data format.

# Example

```julia
Formats.addformat("image/png")
```
"""
function addformat(name::AbstractString)
	mime = MIME{Symbol(name)}()
	if mime in registry.codings
		error("$(name) is already registered as a data coding")
	else
		push!(registry.formats, mime)
	end
end

"""
	addcoding(name::AbstractString)

Register MIME type `name` as a data coding.

# Example

```julia
Formats.addcoding("application/gzip")
```
"""
function addcoding(name::AbstractString)
	mime = MIME{Symbol(name)}()
	if mime in registry.formats
		error("$(name) is already registered as a data format")
	else
		push!(registry.codings, mime)
	end
end

"""
	addextension(format::AbstractString, extension::AbstractString)

Register a filename `extension` for a specific `format`.

# Example

```julia
Formats.addextension("image/png", ".png")
```
"""
function addextension(format::AbstractString, extension::AbstractString)
	mime = MIME{Symbol(format)}()
	startswith(extension, ".") || error("invalid filename extension")
	extension = lowercase(extension)
	mimes = get!(registry.extensions, extension, [])
	if mime in mimes
		@debug("extension $(extension) already registered for $(format)")
	else
		push!(mimes, mime)
	end
	if length(mimes) > 1
		@warn("extension $(extension) registered for multiple formats")
	end
end

"""
	addsignature(format::AbstractString, signature::Vector{UInt8})
	addsignature(format::AbstractString, signature::AbstractString)

Register a (max 512-bytes) `signature` for a specific `format`.

# Example

```julia
Formats.addsignature("image/png", [0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a])
```
"""
function addsignature(format::AbstractString, signature::Vector{UInt8})
	mime = MIME{Symbol(format)}()
	length(signature) > 0 || error("signature cannot be empty")
	length(signature) > 512 && error("maximum signature size is 512 bytes")
	mimes = get!(registry.signatures, signature, [])
	if mime in mimes
		@debug("signature already registered for $(format)")
	else
		push!(mimes, mime)
	end
	if length(mimes) > 1
		@warn("signature registered for multiple formats")
	end
end

addsignature(format::AbstractString, signature::AbstractString) =
		addsignature(format, Vector{UInt8}(signature))

"""
	addreader(format::AbstractString, reader::FormatHandler)

Register a `reader` for the specified `format`.

# Example

```julia
struct MyIO <: Formats.FormatHandler end

Formats.addreader("image/png", MyIO())
```
"""
function addreader(format::AbstractString, reader::FormatHandler)
	mime = MIME{Symbol(format)}()
	readers = get!(registry.readers, mime, [])
	if reader in readers
		error("reader $(reader) already registered for $(format)")
	else
		push!(readers, reader)
	end
	if length(readers) > 1
		@info("$(format) has multiple registered readers")
	end
end

"""
	addwriter(format::AbstractString, writer::FormatHandler)

Register a `writer` for the specified `format`.

# Example

```julia
struct MyIO <: Formats.FormatHandler end

Formats.addwriter("image/png", MyIO())
```
"""
function addwriter(format::AbstractString, writer::FormatHandler)
	mime = MIME{Symbol(format)}()
	writers = get!(registry.writers, mime, [])
	if writer in writers
		error("writer $(writer) already registered for $(format)")
	else
		push!(writers, writer)
	end
	if length(writers) > 1
		@info("$(format) has multiple registered writers")
	end
end

"""
	preferreader(reader::FormatHandler, [format::AbstractString])

Register `reader` as the preferred alternative for the specified `format`.

If `format` is omitted, `reader` becomes a globally preferred alternative: it
is used for all the formats it can read.
```
"""
function preferreader(reader::FormatHandler)
	if reader in registry.global_favorite_readers
		error("reader $(reader) is already globally preferred")
	end
	push!(registry.global_favorite_readers, reader)
end

function preferreader(reader::FormatHandler, format::AbstractString)
	mime = MIME{Symbol(format)}()
	readers = get(registry.readers, mime, [])
	if ! (reader in readers)
		error("reader $(reader) is not registered for $(format)")
	end
	if haskey(registry.favorite_readers, mime)
		@warn("replacing preferred reader for $(format)")
	end
	registry.favorite_readers[mime] = reader
end

"""
	preferwriter(writer::FormatHandler, [format::AbstractString])

Register `writer` as the preferred alternative for the specified `format`.

If `format` is omitted, `writer` becomes a globally preferred alternative: it
is used for all the formats it can write.
"""
function preferwriter(writer::FormatHandler)
	if writer in registry.global_favorite_writers
		error("writer $(writertype) is already globally preferred")
	end
	push!(registry.global_favorite_writers, writer)
end

function preferwriter(writer::FormatHandler, format::AbstractString)
	mime = MIME{Symbol(format)}()
	writers = get(registry.writers, mime, [])
	if ! (writer in writers)
		error("writer $(writer) is not registered for $(format)")
	end
	if haskey(registry.favorite_writers, mime)
		@warn("replacing preferred writer for $(format)")
	end
	registry.favorite_writers[mime] = writer
end

"""
	setdecoder(coding::AbstractString, decoder::Type)

Set the `decoder` to use for the specified `coding`.
"""
function setdecoder(coding::AbstractString, decoder::Type)
	mime = MIME{Symbol(coding)}()
	if haskey(registry.decoders, mime)
		@warn("replacing decoder for $(coding)")
	end
	registry.decoders[mime] = decoder
end

"""
	setencoder(coding::AbstractString, encoder::Type)

Set the `encoder` to use for the specified `coding`.
"""
function setencoder(coding::AbstractString, encoder::Type)
	mime = MIME{Symbol(coding)}()
	if haskey(registry.encoders, mime)
		@warn("replacing encoder for $(coding)")
	end
	registry.encoders[mime] = encoder
end

function resolvehandler(mime::MIME, thing::AbstractString,
		available::Dict{MIME,Vector{FormatHandler}},
		favorites::Dict{MIME,FormatHandler},
		global_favorites::Vector{FormatHandler})
	name = string(mime)
	handlers = get(available, mime) do
		error("no $(thing) registered for $(name)")
	end
	nfavorites = 0
	for favorite in global_favorites
		if favorite in handlers
			handler = favorite
			nfavorites += 1
		end
	end
	if nfavorites > 1
		error("multiple $(thing)s for $(name) are marked as favorites")
	elseif nfavorites == 0
		handler = get(favorites, mime, nothing)
		if handler == nothing
			handler = handlers[1]
			if length(handlers) > 1
				@warn("multiple applicable $(thing)s, using $(handler)")
			end
		else
			if ! (handler in handlers)
				error("$(thing) $(handler), preferred for $(name), " *
						"is not registered")
			end
		end
	else
		if haskey(favorites, mime)
			@warn("both a global and a format-specific preferred $(thing) " *
					"are registered for $(name); " *
					"using global preferred $(thing) $(handler)")
		end
	end
	handler
end

resolvereader(mime::MIME) =
		resolvehandler(mime, "reader", registry.readers,
		registry.favorite_readers, registry.global_favorite_readers)

resolvewriter(mime::MIME) =
		resolvehandler(mime, "writer", registry.writers,
		registry.favorite_writers, registry.global_favorite_writers)

function resolvedecoder(mime::MIME)
	get(registry.decoders, mime) do
		error("no decoder registered for format $(string(mime))")
	end
end

function resolveencoder(mime::MIME)
	get(registry.encoders, mime) do
		error("no encoder registered for format $(string(mime))")
	end
end
