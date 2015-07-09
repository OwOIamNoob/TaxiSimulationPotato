#----------------------------------------
#-- Import or declare all the tools and types
#--  to represent a taxi problem and its solutions
#----------------------------------------

"represent the network of the city (oriented graph)"
typealias Network   DiGraph
"edge in the city graph (one way of a road)"
typealias Road      Edge

"All data needed to represent a customer"
immutable Customer
    "customer id"
    id::Int
    "Pick-up node in the graph"
    orig::Int
    "drop-off node in the graph"
    dest::Int
    "time of call for online simulations"
    tcall::Float64
    "Earliest time for pickup"
    tmin::Float64
    "Latest time for pickup"
    tmaxt::Float64
    "Fare paid by customer for the ride"
    price::Float64
end

"All data needed to represent a taxi"
immutable Taxi
    id::Int
    initPos::Int
end

"""
TaxiProblem: All data needed for simulation
has to include:
network::Network (graph of city)
roadTime::SparseMatrixCSC{Int,Int} Time to cross a road
roadCost::SparseMatrixCSC{Float64,Int} Cost to cross a road
paths::Path Contain paths information
custs::Array{Customer,1} (customers)
taxis::Array{Taxi,1} (taxis)
nTime::Float64 last possible pickup time
waitingCost::Float64 cost of waiting
discreteTime::Bool if time is discrete
"""
abstract TaxiProblem

"Represent the assignement of a customer to a taxi"
immutable CustomerAssignment
    "id of customer"
    id::Int
    "pickup time"
    timeIn::Float64
    "dropoff time"
    timeOut::Float64
end

"""
Represent the actions of a taxi during a simulation:
his path and interactions with customers
"""
type TaxiActions
    "roads in order : (time, road)"
    path::Vector{ Tuple{ Float64, Road}}
    "customer in order: (id, pickup, dropoff)"
    custs::Vector{ CustomerAssignment} #
end

"Represent the solution of a simulation"
type TaxiSolution
    taxis::Array{TaxiActions, 1}
    notTaken::BitVector
    cost::Float64
end

"""
Contains all the information necessary to have path timings and construction
"""
abstract Paths

"Paths that are the fastest in time"
type ShortestPaths <: Paths
    traveltime::Array{Float64,2}
    travelcost::Array{Float64,2}
    previous::Array{Int,2}
end

"Paths with an extra cost for turning left"
type RealPaths <: Paths
    traveltime::Array{Float64,2}
    travelcost::Array{Float64,2}
    newRoadTime::AbstractArray{Float64,2}
    newRoadCost::AbstractArray{Float64,2}
    newPrevious::Array{Int,2}
    newDest::Array{Int,2}
    nodeMapping::Vector{Int}
end

"Dijkstra Heap entry"
immutable DijkstraEntry{Float64}
    vertex::Int
    dist::Float64
    cost::Float64
end

"Represent the pickup time window of a customer"
type AssignedCustomer
    id::Int
    tInf::Float64
    tSup::Float64
end

"represent a time-window solution (only work with fixed timings)"
type IntervalSolution
    custs::Vector{Vector{AssignedCustomer}}
    notTaken::BitVector
    cost::Float64
end

"x and y coordinates, to represent ENU positions"
immutable Coordinates
    x::Float64
    y::Float64
end


"""
Type used to solve online simulation problems
Needs to implement initialize!(om::OnlineMethod, pb::TaxiProblem), update!(om::OnlineMethod,
    newEndTime::Float64, newCustomers::Vector{Customer})
    initialize! initializes a given OnlineMethod with a selected taxi problem without customers
    update! updates OnlineMethod to account for new customers, returns a list of TaxiActions
    since the last update
    """
    abstract OnlineMethod

    #time epsilon for float comparisons
    EPS = 1e-5
