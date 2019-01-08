using Formats
using Test

datapath = joinpath(@__DIR__, "..", "data")

struct TestIO1 <: Formats.FormatHandler end
struct TestIO2 <: Formats.FormatHandler end
struct TestIO3 <: Formats.FormatHandler end

testio1 = TestIO1()
testio2 = TestIO2()
testio3 = TestIO3()

function Base.read(::TestIO1, ::MIME"text/plain", io::IO)
    chars = Char[]
    while true
        char = read(io, Char)
        if char == '/'
            break
        end
        push!(chars, char)
    end
    String(chars)
end

function Base.write(::TestIO1, ::MIME"text/plain", io::IO, x)
    write(io, x)
    write(io, "/")
end

@testset "Formats" begin

    @testset "Specify" begin
        Formats.newregistry() do
            f1 = specify("kitten.png", "image/png")
            @test isspecified(f1)
            @test !isguessed(f1)
            @test !isunknown(f1)
            @test !isambiguous(f1)
            @test getformat(f1) == "image/png"
            @test getcoding(f1) == nothing
            @test resource(f1) == "kitten.png"

            f2 = specify("oldcat.dat", "image/bmp", "application/gzip")
            @test isspecified(f2)
            @test !isguessed(f2)
            @test !isunknown(f2)
            @test !isambiguous(f2)
            @test getformat(f2) == "image/bmp"
            @test getcoding(f2) == "application/gzip"
        end
    end

    @testset "Guess from filename" begin
        Formats.newregistry() do
            f1 = guess("kitten.png")
            @test !isspecified(f1)
            @test !isguessed(f1)
            @test isunknown(f1)
            @test !isambiguous(f1)
            @test_throws ErrorException getformat(f1)
            @test getcoding(f1) == nothing

            Formats.addformat("image/png")
            Formats.addextension("image/png", ".png")
            f2 = guess("kitten.png")
            @test !isspecified(f2)
            @test isguessed(f2)
            @test !isunknown(f2)
            @test !isambiguous(f2)
            @test getformat(f2) == "image/png"
            @test getcoding(f2) == nothing

            f3 = guess("kitten.png.gz")
            @test !isspecified(f3)
            @test !isguessed(f3)
            @test isunknown(f3)
            @test !isambiguous(f3)
            @test_throws ErrorException getformat(f3)
            @test getcoding(f3) == nothing

            Formats.addcoding("application/gzip")
            Formats.addextension("application/gzip", ".gz")
            f4 = guess("kitten.png.gz")
            @test !isspecified(f4)
            @test isguessed(f4)
            @test !isunknown(f4)
            @test !isambiguous(f4)
            @test getformat(f4) == "image/png"
            @test getcoding(f4) == "application/gzip"

            Formats.addformat("game/pong")
            Formats.addextension("game/pong", ".png")
            f5 = guess("kitten.png")
            @test !isspecified(f5)
            @test isguessed(f5)
            @test !isunknown(f5)
            @test isambiguous(f5)
            getformat(f5)
            @test getcoding(f5) == nothing
        end
    end

    @testset "Guess from IOStream" begin
        Formats.newregistry() do
            io = open("$(datapath)/kitten.png")

            f1 = guess(io)
            @test !isspecified(f1)
            @test !isguessed(f1)
            @test isunknown(f1)
            @test !isambiguous(f1)
            @test_throws ErrorException getformat(f1)
            @test getcoding(f1) == nothing

            Formats.addformat("image/png")
            Formats.addsignature("image/png",
                    [0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a])
            Formats.addsignature("image/png", "fake!")
            f2 = guess(io)
            @test !isspecified(f2)
            @test isguessed(f2)
            @test !isunknown(f2)
            @test !isambiguous(f2)
            @test getformat(f2) == "image/png"
            @test getcoding(f2) == nothing

            Formats.addformat("game/pong")
            Formats.addsignature("game/pong",
                    [0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a])
            f3 = guess(io)
            @test !isspecified(f3)
            @test isguessed(f3)
            @test !isunknown(f3)
            @test isambiguous(f3)
            getformat(f3)
            @test getcoding(f3) == nothing
        end
    end

    @testset "Guess from Formatted object" begin
        Formats.newregistry() do
            Formats.addformat("image/png")
            Formats.addsignature("image/png",
                    [0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a])
            f1 = guess("$(datapath)/kitten.png")

            f2 = open(f1)
            @test !isspecified(f2)
            @test !isguessed(f2)
            @test isunknown(f2)
            @test !isambiguous(f2)
            @test_throws ErrorException getformat(f2)
            @test getcoding(f2) == nothing

            f3 = guess(f2)
            @test !isspecified(f3)
            @test isguessed(f3)
            @test !isunknown(f3)
            @test !isambiguous(f3)
            @test getformat(f3) == "image/png"
            @test getcoding(f3) == nothing
        end
    end

    @testset "Passthrough with formatted" begin
        Formats.newregistry() do
            f1 = guess("kitten.png")
            Formats.addformat("image/png")
            Formats.addextension("image/png", ".png")
            Formats.addsignature("image/png",
                    [0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a])

            f2 = formatted(f1)
            @test !isspecified(f2)
            @test !isguessed(f2)
            @test isunknown(f2)
            @test !isambiguous(f2)
            @test_throws ErrorException getformat(f2)
            @test getcoding(f2) == nothing

            f3 = formatted("kitten.png")
            @test !isspecified(f3)
            @test isguessed(f3)
            @test !isunknown(f3)
            @test !isambiguous(f3)
            @test getformat(f3) == "image/png"
            @test getcoding(f3) == nothing

            f4 = formatted(open("$(datapath)/kitten.png"))
            @test !isspecified(f4)
            @test isguessed(f4)
            @test !isunknown(f4)
            @test !isambiguous(f4)
            @test getformat(f4) == "image/png"
            @test getcoding(f4) == nothing
        end
    end

    @testset "Resolving reader" begin
        Formats.newregistry() do
            Formats.addformat("image/png")
            mime = MIME"image/png"()
            Formats.addreader("image/png", testio1)
            @test Formats.resolvereader(mime) == testio1
            Formats.addreader("image/png", testio2)
            Formats.resolvereader(mime)
            Formats.preferreader(testio1, "image/png")
            @test Formats.resolvereader(mime) == testio1
            Formats.preferreader(testio2, "image/png")
            @test Formats.resolvereader(mime) == testio2
            Formats.addreader("image/png", testio3)
            @test Formats.resolvereader(mime) == testio2
            Formats.preferreader(testio3)
            @test Formats.resolvereader(mime) == testio3
        end
    end

    @testset "Resolving writer" begin
        Formats.newregistry() do
            Formats.addformat("image/png")
            mime = MIME"image/png"()
            Formats.addwriter("image/png", testio1)
            @test Formats.resolvewriter(mime) == testio1
            Formats.addwriter("image/png", testio2)
            Formats.resolvewriter(mime)
            Formats.preferwriter(testio1, "image/png")
            @test Formats.resolvewriter(mime) == testio1
            Formats.preferwriter(testio2, "image/png")
            @test Formats.resolvewriter(mime) == testio2
            Formats.addwriter("image/png", testio3)
            @test Formats.resolvewriter(mime) == testio2
            Formats.preferwriter(testio3)
            @test Formats.resolvewriter(mime) == testio3
        end
    end

    @testset "Formatted reading" begin
        Formats.newregistry() do
            Formats.addformat("text/plain")
            Formats.addreader("text/plain", testio1)
            io = IOBuffer("kitten/cat/feline/")
            f = specify(io, "text/plain")
            @test read(f) == "kitten"
            @test read(f) == "cat"
            @test read(f) == "feline"
            @test_throws Exception read(f)
        end
    end

    @testset "Formatted writing" begin
        Formats.newregistry() do
            Formats.addformat("text/plain")
            Formats.addwriter("text/plain", testio1)
            io = IOBuffer(write = true)
            f = specify(io, "text/plain")
            write(f, "kitten")
            write(f, "cat")
            write(f, "feline")
            @test String(take!(io)) == "kitten/cat/feline/"
        end
    end

end # @testset
