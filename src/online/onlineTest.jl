using TaxiSimulation
using LightGraphs

problem = Metropolis(8, 8)
generateProblem!(problem, 20, 0.45, now(), now() + Dates.Hour(3))
# onlineSimulation(problem, IterativeOffline(90), period = 10)
cd("Dropbox (MIT)/7 Coding/UROP/taxi-simulation/src/online")
include("onlineSimulation.jl")

include("IterativeOffline.jl")
s1 = onlineSimulation(problem, IterativeOffline(90.0), period = 10.0)

include("IterativeOffline2.jl")
s2 = onlineSimulation(problem, IterativeOffline2(90.0), period = 10.0)

include("onlineSimulation.jl")
include("uber.jl")
s3 = onlineSimulation(problem, Uber(90.0), period = 10.0, noTCall = true)

println(s1)
println(s2)