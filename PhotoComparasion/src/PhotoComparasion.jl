module PhotoComparasion

using Images
using Statistics
import PostgresORM: IEntity
import LibPQ
using JSON3

export getElementsInPath, isImageFile, getDirsInPath, processimagesindirectory,
    Storage, StorageUniqueUnit, StorageDuplicateUnit, write, read
export transformimage, ImageComparasionSetting, aresimilar
export with_default_connection, get_query, table_exists, initializedb
# export *
import Base: push!, push, write, read

CONNECTION_STRING = "dbname=postgres user=admin password=admin"

struct ImageComparasionSetting
    scalingWidth::Int
    scalingHeight::Int
    errorThreshold::Float64
end

struct StorageUniqueUnit
    id::Int
    path::String
    img::Array{Float64}
end

struct StorageDuplicateUnit
    path::String
    id::Int
end

mutable struct Storage
    id_seq::Int
    uniqueStorage::AbstractVector{StorageUniqueUnit}
    duplicateStorage::AbstractVector{StorageDuplicateUnit}
    settings::ImageComparasionSetting
end

Storage(settings::ImageComparasionSetting)::Storage = Storage(0, Vector{StorageUniqueUnit}(), Vector{StorageDuplicateUnit}(), settings)

function getElementsInPath(path::String)::AbstractVector{AbstractString}
    return readdir(path)
end

function getDirsInPath(path::String)::AbstractVector{AbstractString}
    return filter(isdir, getElementsInPath(path))
end

function isImageFile(fileName::String)::Bool
    extensions = [
        r".*\.png$",
        r".*\.jpg$",
        r".*\.jpeg$",
        r".*\.bmp$",
        r".*\.dib$",
        r".*\.jpe$",
    ]
    return any((occursin(extensionRegex, lowercase(fileName)) for extensionRegex in extensions))
end

imagesNamesInPath(path::String)::AbstractVector{AbstractString} = filter(isImageFile, readdir(path))

function processimagesindirectory(path::String, storage::Storage)
    for img in imagesNamesInPath(path)
        checkforduplicates(img, storage)
    end
end

function checkforduplicates(path::String, storage::Storage)
    image = transformimage(path, storage.settings)
    img = findinstorage(image, storage)

    if isnothing(img)
        storage.id_seq += 1
        push!(storage, StorageUniqueUnit(storage.id_seq, path, image))
    elseif img.path != path
        push!(storage, StorageDuplicateUnit(path, img.id))
    end
end

function findinstorage(image::Array{Float64}, storage::Storage)::Union{StorageUniqueUnit,Nothing}
    for i in storage.uniqueStorage
        if aresimilar(i.img, image, storage.settings)
            return i
        end
    end
    return nothing
end

function push!(storage::Storage, unit::StorageUniqueUnit)
    push!(storage.uniqueStorage, unit)
end
function push!(storage::Storage, unit::StorageDuplicateUnit)
    push!(storage.duplicateStorage, unit)
end

transformimage(image::String, settings::ImageComparasionSetting) = transformimage(load(image), settings)

function transformimage(image::Array{T}, settings::ImageComparasionSetting)::Array{Float64} where {T<:Colorant}
    return Float64.(Gray.(imresize(image, (settings.scalingWidth, settings.scalingHeight))))
end

function aresimilar(img_one::Matrix{Float64}, img_two::Matrix{Float64}, settings::ImageComparasionSetting)::Any
    threshold = mean(abs.(img_one .- img_two))
    # print(threshold)
    return threshold <= settings.errorThreshold
end

function aresimilar(image_one::Matrix{T}, image_two::Matrix{T}, settings::ImageComparasionSetting)::Any where {T<:Colorant}
    img_one = transformimage(image_one, settings)
    img_two = transformimage(image_two, settings)

    return aresimilar(img_one, img_two, settings)
end

function aresimilar(image_one::Matrix{Float64}, image_two::Matrix{T}, settings::ImageComparasionSetting)::Any where {T<:Colorant}
    img_one = transformimage(image_one, settings)

    return aresimilar(img_one, image_two, settings)
end

function aresimilar(image_one::Matrix{T}, image_two::Matrix{Float64}, settings::ImageComparasionSetting)::Any where {T<:Colorant}
    img_one = transformimage(image_one, settings)

    return aresimilar(img_one, image_two, settings)
end

function with_default_connection(query::String)::Any
    conn = LibPQ.Connection(CONNECTION_STRING)
    ret = collect(LibPQ.execute(conn, query))
    LibPQ.close(conn)
    return ret
end

get_query(id::String)::String = get_query(Symbol(id))
get_query(id::Symbol)::String = get_query(id, missing)

"""
    get_query(id::Symbol, t_name::Union{String,Symbol,Missing})::String


"""
function get_query(id::Symbol, t_name::Union{String,Symbol,Missing})::String
    mapping = Dict{Symbol,String}(
        :table_exists => "SELECT EXISTS (
            SELECT 1 FROM 
                pg_tables
            WHERE 
                schemaname = 'public' AND 
                tablename  = '$(t_name)'
            );
          ",
        :create_table_unique_image => "
            CREATE TABLE unique_images
            (
                id serial primary key,
                img Float[][]
            );
        ",
        :create_table_image_location => "
        CREATE TABLE image_location
        (
            id serial primary key,
            unique_image_id integer,
            location text,
            width integer,
            height integer,
            extension text
        );
    "
    )

    if haskey(mapping, id)
        return mapping[id]
    else
        error("Missing key for getting query! No " * String(id))
    end

end

"""
    table_exists(name::Union{String,Symbol})::Bool

    Checks if the table exists
"""
table_exists(name::String)::Bool = any(with_default_connection(get_query(:table_exists, name))[1])
table_exists(name::Symbol)::Bool = table_exists(String(name))


create_table(name::Symbol) = any(with_default_connection(get_query(:table_exists, name))[1])
create_table(id::Symbol) = with_default_connection(get_query(Symbol("create_table_" * String(id))))

"""
    initializedb()

Initialized structures if ther are not existent in the default db.
"""
function initializedb()
    for name in (:unique_images, :image_location)
        if !table_exists(name)
            create_table(name)
        end
    end
end # table_exists(:unique_image)

function write(filename::String, storage::Storage)::Nothing
    Base.write(filename, JSON3.write(storage))
    return
end

function read(filename::String)
    contents = Base.read(filename, String)
    JSON3.read(contents, Storage)
end


end # module
