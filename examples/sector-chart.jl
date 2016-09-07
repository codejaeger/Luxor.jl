#!/usr/bin/env julia

using Luxor, Colors

"""
Work out how many rows and columns we need given the number of cells required.
Favours squarer layouts.
"""
function howmanyrowscolumns(n)
  numberofrows = convert(Int, floor(sqrt(n)))
  numberofcols = convert(Int, ceil(n/numberofrows))
  return numberofrows, numberofcols
end

"""
Find area of annular sector.
"""
function areaofsector(innerradius, outerradius, startangle, endangle)
  theta = endangle - startangle
  return (theta/2 * (innerradius + outerradius)^2) - (theta/2 * (innerradius)^2)
end

"""
find the outerradius of a sector if we already know what its area is
"""

function outerradiusgivenarea(area, innerradius, startangle, endangle)
    theta = endangle - startangle
    return sqrt( (area + (theta/2) * innerradius^2) / (theta/2) ) - innerradius
end

"""
Draw a sector chart. You specify the centerposition, the tilewidth and height, some datavalues,
labels (one for each datavalue), and a dictionary that maps languages to colors. And a title.

The incoming values are rescaled to make nice pictures. But the original values are shown in labels.

    sectorchart(centerpos,
        innerradius,
        tilewidth, tileheight,
        rawdatavalues, labels, colordict, title;
        gap=deg2rad(2))
"""

function sectorchart(centerpos, innerradius, tilewidth, tileheight, rawdatavalues, labels, coldict, title; gap=deg2rad(2))
  gsave()
  translate(centerpos)
  n = length(rawdatavalues)
  theta = 2pi/n
  for i in 1:n
    startangle = (i - 1) * theta + gap
    endangle = startangle + theta - gap
    # convert areas to radius values
    # rawdatavalues are areas, to be converted into sector length
    # if datavalue is area, what would outerradius have to be?
    moddatavalues = map(dv -> outerradiusgivenarea(dv, innerradius, startangle, endangle), rawdatavalues)

    # rescale datavalues
    lowv, highv = extrema(moddatavalues)
    scaleddatavalues = map(dv -> rescale(dv, 0, highv, innerradius, min(tilewidth/2, tileheight/2)), moddatavalues)
    outerradius = scaleddatavalues[i]

    # find the required color for this sector
    sethue(coldict[labels[i]])
    sector(innerradius, outerradius, startangle, endangle, :fill)

    gsave()

    # draw the labels for each sector
    fontsize(4)
    sethue("black")
    textoffset = 5
    refpos = Point(
        (innerradius - textoffset) * cos(startangle + (endangle - startangle)/2),
        (innerradius - textoffset) * sin(startangle + (endangle - startangle)/2))
    rotangle = atan2(refpos.y, refpos.x)
    # subtract half the width of the string to center it
    glyph_x_bearing, glyph_y_bearing, glyph_width,
      glyph_height, glyph_x_advance, glyph_y_advance = textextents(labels[i])
    shiftangle = asin((glyph_width/2)/innerradius)
    textcurve(labels[i], rotangle-shiftangle, innerradius - textoffset)

    # show the original raw data value (not the rescaled value used for plotting)
    # refpos is for text placement
    textoffset = 10
    refpos = Point(
        (outerradius + textoffset) * cos(startangle + (endangle - startangle)/2),
        (outerradius + textoffset) * sin(startangle + (endangle - startangle)/2))
    rotangle = atan2(refpos.y, refpos.x)
    translate(refpos)
    roundedtext = string(round(rawdatavalues[i], 2))
    (rotangle > pi/2 || rotangle < -pi/2) ? textright(roundedtext) : text(roundedtext)
    grestore()
  end
  gsave()
  # label this chart
  fontsize(24)
  fontface("Impact")
  sethue("black")
  textcentered(title, 0, min(tilewidth/2, tileheight/2) - 30)
  grestore()
  grestore()
end

function main()
  fname = "/tmp/sector-chart.pdf"
  width, height = 1064, 1064
  Drawing(width, height, fname)
  origin()
  background("ivory")
  setline(1)

  # get the data
  d = readcsv("examples/benchmarks-julia.csv")
  # fields are language | test | timetaken
  d = d[d[:, 1] .!= "octave" , :]
  # but we don't want "Octave" because there are too many outliers :)

  languages = unique(d[:,1])
  benchmarknames = unique(d[:,2])

  # build a color dictionary for languages
  # order: r, fortran, java, lua, javascript, mma, go, matlab, python, julia
  cols   =  ["red3", "darkgreen", "blueviolet", "royalblue2", "orange3", "palegreen3", "cyan3", "rosybrown", "gray56", "chartreuse3", "burlywood3"]
  languagecolors = Dict(languages[i] => cols[i] for i in 1:length(languages))

  # how many charts are we plotting?
  # numberofrows, numberofcolumns = howmanyrowscolumns(length(benchmarknames))

  numberofrows, numberofcolumns = 3, 3
  topbottommargins = 200
  pagetiles = Tiler(width, height - topbottommargins, numberofrows, numberofcolumns, margin=50)

  # draw each chart using the next lot of data, for each benchmark
  for (cpos, counter) in pagetiles
    counter > length(benchmarknames) && continue # not all tiles will be filled
    benchmark = benchmarknames[counter]
    data = d[d[:, 2] .== benchmark, [3]]
    language = d[d[:, 2] .== benchmark, [1]]
    length(data) < 2 && continue # don't bother with tests with only one value!
    sectorchart(cpos, 50, pagetiles.tilewidth, pagetiles.tileheight, data, language, languagecolors, benchmark)
  end

  # finally, decorate the chart
  # heading
  sethue("black")
  fontface("Impact")
  fontsize(40)
  gsave()
  translate(0, -height/2 + 100)
  textcentred("Julia Benchmark Comparisons")
  grestore()

  # footnotes

  gsave()
  fontface("Monaco")
  fontsize(8)
  translate(0, height/2 - 50)
  textcentred("$(Dates.format(now(), "e, dd u yyyy HH:MM")) Bigger sectors are slower. Humans are bad at comparing areas. Benchmarks are taken from the http://julialang.org web site.")
  translate(0, 20)
  textcentred("Terms and conditions apply. Objects appear smaller than they actually are. The value of investments may go up as well as down.")
  grestore()

  # legend
  fontsize(14)
  fontface("Helvetica")
  x, y = width/2-150, height/2 - 350
  for language in languages
    sethue("black")
    textright(language, x - 55, y)
    sethue(languagecolors[language])
    squircle(Point(x, y -5), 50, 10, :fill, rt = 0.3)
    y += 25
  end

  finish()
  println("finished test: output in $(fname)")
  preview()
end

function maintest()
  fname = "/tmp/sector-test.pdf"
  width, height = 1920, 1068
  Drawing(width, height, fname)
  origin()
  background("ivory")
  setline(1)
  sectorchart(
    Point(0, 0),
    100,
    600,
    600,
    [1, 2, 3, 4, 5, 6],
    ["1", "2", "3", "4", "5", "6"],
    Dict("1" => "red3", "2" => "darkgreen", "3" => "blueviolet", "4" => "mediumorchid1", "5" => "sienna1", "6" => "chartreuse3"),
    "test")
  finish()
  println("finished test: output in $(fname)")
  preview()
end

main()

#maintest()
