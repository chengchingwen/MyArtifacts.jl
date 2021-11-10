using OhMyArtifacts, Pkg, Dates
using Scratch
using Test
include("utils.jl")

# Set to true for verbose Pkg output
const verbose = false
global const pkgio = verbose ? stderr : (VERSION < v"1.6.0-DEV.254" ? mktemp()[2] : devnull)

@testset "OhMyArtifacts.jl Basics" begin
    temp_pkg_dir() do project_dir
        artifacts_toml = @my_artifacts_toml!()
        @test isdir(OhMyArtifacts.get_scratch_dir())
        @test isdir(OhMyArtifacts.get_artifacts_dir())
        @test isfile(artifacts_toml)
        @test startswith(artifacts_toml, OhMyArtifacts.get_scratch_dir())
        @test isempty(OhMyArtifacts.load_my_artifacts_toml(artifacts_toml))

        hash_a = create_my_artifact() do artifact_dir
            cp(@__FILE__, joinpath(artifact_dir, "a"))
        end
        hash_b = create_my_artifact() do artifact_dir
            cp(joinpath(@__DIR__, "utils.jl"), joinpath(artifact_dir, "a"))
        end
        @test isfile(joinpath(OhMyArtifacts.get_artifacts_dir(), string(hash_a)))
        @test isfile(joinpath(OhMyArtifacts.get_artifacts_dir(), string(hash_b)))
        @test isfile(my_artifact_path(hash_a))
        @test isfile(my_artifact_path(hash_b))
        @test my_artifact_exists(hash_a)
        @test my_artifact_exists(hash_b)

        bind_my_artifact!(artifacts_toml, "runtestfile", hash_a)
        bind_my_artifact!(artifacts_toml, "utils.jl", hash_b)
        @test length(OhMyArtifacts.load_my_artifacts_toml(artifacts_toml)) == 2
        @test my_artifact_hash("runtestfile", artifacts_toml) == hash_a
        @test my_artifact_hash("utils.jl", artifacts_toml) == hash_b

        usagefile = OhMyArtifacts.usages_toml()
        @test isfile(usagefile)
        usage = OhMyArtifacts.parse_toml(usagefile)
        @test length(usage) == 2
        @test length(usage[my_artifact_path(hash_a)]) == 1
        @test length(usage[my_artifact_path(hash_b)]) == 1
        @test now() - usage[my_artifact_path(hash_a)][artifacts_toml]["runtestfile"] < Day(1)
        @test now() - usage[my_artifact_path(hash_b)][artifacts_toml]["utils.jl"] < Day(1)

        OhMyArtifacts.unbind_my_artifact!(artifacts_toml, "utils.jl")
        @test length(OhMyArtifacts.load_my_artifacts_toml(artifacts_toml)) == 1
        @test my_artifact_exists(hash_a)
        @test my_artifact_exists(hash_b)

        orphanfile = OhMyArtifacts.orphanages_toml()
        @test isfile(orphanfile)
        orphan = OhMyArtifacts.parse_toml(orphanfile)
        @test isempty(orphan)

        OhMyArtifacts.find_orphanages()
        orphan = OhMyArtifacts.parse_toml(orphanfile)
        @test length(orphan) == 1
        @test now() - orphan[my_artifact_path(hash_b)] < Day(1)
        @test my_artifact_exists(hash_a)
        @test my_artifact_exists(hash_b)

        OhMyArtifacts.find_orphanages(; collect_delay=Hour(0))
        orphan = OhMyArtifacts.parse_toml(orphanfile)
        @test isempty(orphan)
        @test my_artifact_exists(hash_a)
        @test !my_artifact_exists(hash_b)

    end
end
