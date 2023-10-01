using Pkg

Pkg.activate(pwd())
# Pkg.add("Revise")
# Pkg.add("Images")
# Pkg.add("FileIO")
# Pkg.add("ImageIO")
# Pkg.add("PostgresORM")
# Pkg.add("LibPQ")
# Pkg.add("OffsetArrays")
# Pkg.add("JSON3")

using Revise
includet(joinpath("..", "PhotoComparasion", "src", "PhotoComparasion.jl"))

using FileIO
using OffsetArrays

using .PhotoComparasion


settings = ImageComparasionSetting(
    10,
    10,
    0.1
)
"""
1. Wykrycie obrazka,
2. utworzenie 20/20 poglądu,
3. sprawdzenie czy istnieje taki w bazie
4. Jak nie to dodanie do bazy wraz z unikatowym identyfikatorem
5. jak tak, to dodanie rekordu z informacją, że jest duplikat

"""

# img_1 = load("tree.jpg")
# img_12 = load("tree_mess.jpg")
# @time x = aresimilar(img_12, img_1, settings)
# transformimage(img_1, settings)

# initializedb()


directory = pwd()

storage = Storage(settings)


@time processimagesindirectory(directory,storage)

PhotoComparasion.write("testFile.json", storage)

PhotoComparasion.read("testFile.json")