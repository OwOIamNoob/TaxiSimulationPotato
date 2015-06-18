#----------------------------------------
#-- Elaborate network, depending on parameters
#-- Represent whole city, with commuting effects
#-- 1time-step = 30s
#----------------------------------------

#Price paid by customer for an hour's ride
hourFare(t::DateTime) = 150
#Cost for a taxi to drive an hour
const driveCost = 30
const waitCost  = 10

cityTrvlTime() = rand(1:4)
longTrvlTime() = rand(5:15)
cityTrvlCost(trvltime) = trvltime * driveCost/120
longTrvlCost(trvltime) = trvltime * driveCost/120

type Metropolis <: TaxiProblem
  network::Network
  roadTime::SparseMatrixCSC{Float64, Int}
  roadCost::SparseMatrixCSC{Float64, Int}
  custs::Array{Customer,1}
  taxis::Array{Taxi,1}
  nTime::Int
  waitingCost::Float64
  sp::ShortPaths
#--------------
#Specific attributes
  width::Int
  subWidth::Int
  nSub::Int
  tStart::DateTime
  tEnd::DateTime


  function Metropolis(width::Int, nSub::Int)
    c = new()
    c.width = width
    c.subWidth = int( floor(width/2))
    c.nSub = nSub
    c.waitingCost = waitCost/120

  #-----------------------------------
  #First, we construct the network
    nLocs = width^2 + nSub * (c.subWidth^2)
    c.network  = DiGraph(nLocs)
    c.roadTime = spzeros(nLocs,nLocs)
    c.roadCost = spzeros(nLocs,nLocs)
    #add the main city
    addSquare(c.network, c.roadTime, c.roadCost, width,0)

    #add the sub cities
    for sub in 1:nSub
      addSquare(c.network, c.roadTime, c.roadCost, c.subWidth, width^2 + (sub - 1 )*(c.subWidth^2))
    end

    #link subs to city
    function sortOrder(x)
      s,t = x
      return (s-1)*width + t
    end
    anchors = sort( [(rand(1:4), rand(1:(width-1))) for i in 1:nSub], by=sortOrder)
    for sub in 1:nSub
      #random anchor in big city
      s, t = anchors[sub]
      i, j = 0, 0
      if s == 1
        i, j = 1, t
      elseif s == 2
        i, j = t, width
      elseif s == 3
        i, j = width, (width - t + 1)
      else
        i, j = (width - t + 1), 1
      end

      a, b = coordToLoc(1,1,sub,c), coordToLoc(i,j,0,c)
      add_edge!(c.network, a, b)
      tt = longTrvlTime()
      c.roadTime[a, b] = tt
      c.roadCost[a, b] = longTrvlCost(tt)

      add_edge!(c.network, b, a)
      tt = longTrvlTime()
      c.roadTime[b, a] = tt
      c.roadCost[b, a] = longTrvlCost(tt)
    end

    #link subs between then (in a circle)
    for sub in 1:(nSub-1)
      a, b = coordToLoc(1,c.subWidth,sub,c), coordToLoc(c.subWidth,1, sub+1,c)
      add_edge!(c.network, a, b)
      tt = cityTrvlTime()
      c.roadTime[a, b] = tt
      c.roadCost[a, b] = cityTrvlCost(tt)

      add_edge!(c.network, b, a)
      tt = cityTrvlTime()
      c.roadTime[b, a] = tt
      c.roadCost[b, a] = cityTrvlCost(tt)
    end
    #last link
    if nSub >1
      a, b = coordToLoc(1,c.subWidth,nSub,c), coordToLoc(c.subWidth,1, 1,c)
      add_edge!(c.network, a, b)
      tt = cityTrvlTime()
      c.roadTime[a, b] = tt
      c.roadCost[a, b] = cityTrvlCost(tt)

      add_edge!(c.network, b, a)
      tt = cityTrvlTime()
      c.roadTime[b, a] = tt
      c.roadCost[b, a] = cityTrvlCost(tt)
    end

    #We compute the shortest paths from everywhere to everywhere (takes time)
    c.sp = shortestPaths(c.network, c.roadTime, c.roadCost)
    c.custs = Customer[]
    c.taxis = Taxi[]
    c.nTime = 0
    return c
  end

  Metropolis(network,roadTime,roadCost,custs,taxis,nTime,waitingCost,sp,width,subWidth,nSub,tStart,tEnd) =
   new(network,roadTime,roadCost,custs,taxis,nTime,waitingCost,sp,width,subWidth,nSub,tStart,tEnd)
end

clone(m::Metropolis) =
  Metropolis(m.network,m.roadTime,m.roadCost,m.custs,m.taxis,m.nTime,m.waitingCost,m.sp,m.width,m.subWidth,m.nSub,m.tStart,m.tEnd)

# Add a square-city to the graph
function addSquare(n::Network,roadTime::SparseMatrixCSC{Float64, Int},
  roadCost::SparseMatrixCSC{Float64, Int}, width::Int, start::Int)

  function coordToLoc(i,j)
    return start + j + (i-1)*width
  end
  for i in 1:(width-1), j in 1:width
    #Vertical roads
    a, b = coordToLoc(i,j), coordToLoc(i+1,j)
    add_edge!(n, a, b)
    tt = cityTrvlTime()
    roadTime[a, b] = tt
    roadCost[a, b] = cityTrvlCost(tt)

    add_edge!(n, b, a)
    tt = cityTrvlTime()
    roadTime[b, a] = tt
    roadCost[b, a] = cityTrvlCost(tt)

    #Horizontal roads
    a, b = coordToLoc(j,i), coordToLoc(j,i+1)
    add_edge!(n, a, b)
    tt = cityTrvlTime()
    roadTime[a, b] = tt
    roadCost[a, b] = cityTrvlCost(tt)

    add_edge!(n, b, a)
    tt = cityTrvlTime()
    roadTime[b, a] = tt
    roadCost[b, a] = cityTrvlCost(tt)
  end
end

#Generate customers and taxis, demand is a parameter correlated to the number of
# customers
function generateProblem!(city::Metropolis, nTaxis::Int, demand::Float64,
   tStart::DateTime, tEnd::DateTime)

   city.tStart = tStart
   city.tEnd   = tEnd
   city.nTime  = 1 + floor( (tEnd-tStart).value/(30 *1000))
   if city.nTime < 1
     error("Time of simulation is negative!")
   end
   generateCustomers!(city, demand)
   generateTaxis!(city, nTaxis)
end

#compute the demand probabilities for a particular time
# (overall probability, [city=>city, sub=>sub, city=>sub, sub=>city])
#overall probability is the mean of a Poisson law, in customers per hour

function metroDemand(sim::Metropolis, time::DateTime, demand::Float64)
  meanPerHour = (2*sim.width^2 + 0.5*sim.nSub*sim.subWidth^2)*demand
  cityCity = 0.4
  subSub   = 0.1
  citySub  = 0.25
  SubCity  = 0.25
  return (meanPerHour, [cityCity, subSub, citySub, SubCity])
end

#to generate the customers
function generateCustomers!(sim::Metropolis, demand::Float64)
  sim.custs = Customer[]
  tCurrent = sim.tStart
  for i = 1:sim.nTime
    meanPerHour, catProb = metroDemand(sim, tCurrent, demand)

    nCusts = rand(Poisson(meanPerHour/120))
    for j in 1:nCusts
      category = rand(Categorical(catProb))
      orig, dest = 0, 0
      #-------------
      #-- city=>city
      if category == 1
        orig = coordToLoc(rand(1:sim.width), rand(1:sim.width), 0, sim)
        dest = coordToLoc(rand(1:sim.width), rand(1:sim.width), 0, sim)
        while orig == dest
          dest = coordToLoc(rand(1:sim.width), rand(1:sim.width), 0, sim)
        end
      #-------------
      #-- sub=>sub
      elseif category == 2
        orig = coordToLoc(rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)
        dest = coordToLoc(rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)
        while orig == dest
          dest = coordToLoc(rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)
        end
      #-------------
      #-- city=>sub
      elseif category == 3
        orig = coordToLoc(rand(1:sim.width), rand(1:sim.width), 0, sim)
        dest = coordToLoc(rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)
      #-------------
      #-- sub=>city
      else
        dest = coordToLoc(rand(1:sim.width), rand(1:sim.width), 0, sim)
        orig = coordToLoc(rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)
      end
      pathTime = sim.sp.traveltime[orig,dest]

      if pathTime + i <= sim.nTime
        price = (hourFare(tCurrent)/120)*pathTime
        tmin  = i
        tmaxt = min(sim.nTime, i + rand(1:10))
        tmax  = min(sim.nTime, tmaxt + pathTime)
        tcall = max(1, tmin - rand(1:120))
        push!(sim.custs,
         Customer(length(sim.custs)+1,orig,dest,tcall,tmin,tmaxt,tmax,price))
      end
    end
    #First, get the number of customers to generate
    tCurrent += Second(30)
  end
end



function generateTaxis!(sim::Metropolis, nTaxis::Int)
  sim.taxis = Taxi[]
  for k in 1:nTaxis
    if rand(1:2) == 1 #taxi in city
      push!(sim.taxis, Taxi( k, coordToLoc( rand(1:sim.width), rand(1:sim.width), 0, sim)))
    else
      push!(sim.taxis, Taxi( k, coordToLoc( rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)))
    end
  end
end

#Gives the index of vertex, given coords and city number
function coordToLoc(i::Int, j::Int, c::Int, city::Metropolis)
  if c ==0
    return j + (i-1)*city.width
  else
    return city.width^2 + (c-1)*city.subWidth^2 + j + (i-1)*city.subWidth
  end
end