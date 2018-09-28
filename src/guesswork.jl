"""
    guesscontent(filename|io) -> (formats[], codings[])

Guess possible formats/codings from a filename or IO stream.

In the case of a filename, the extension is checked; for IO streams, the first
few bytes of the stream are examined.
"""
function guesscontent(filename::AbstractString)
	format_guesses = []
	coding_guesses = []
	filename2, extension = splitext(filename)
	extension = lowercase(extension)
	for mime in get(registry.extensions, extension, [])
		if mime in registry.codings
			push!(coding_guesses, mime)
		elseif mime in registry.formats
			push!(format_guesses, mime)
		end
	end
	if length(coding_guesses) > 0 && length(format_guesses) > 0
		coding_guesses = []
	end
	if length(coding_guesses) > 0
		extension2 = lowercase(splitext(filename2)[2])
		for mime in get(registry.extensions, extension2, [])
			if mime in registry.formats
				push!(format_guesses, mime)
			end
		end
	end
	return format_guesses, coding_guesses
end

function guesscontent(io::IO)
	format_guesses = []
	coding_guesses = []
	mark(io)
	beginning = read(io, 512)
	reset(io)
	if length(beginning) > 0
		for (signature, mimes) in registry.signatures
			if length(beginning) >= length(signature)
				if view(beginning, axes(signature)...) == signature
					for mime in mimes
						if mime in registry.codings
							push!(coding_guesses, mime)
						elseif mime in registry.formats
							push!(format_guesses, mime)
						end
					end
				end
			end
		end
	end
	if length(format_guesses) > 0 && length(coding_guesses) > 0
		coding_guesses = []
	end
	return format_guesses, coding_guesses
end
