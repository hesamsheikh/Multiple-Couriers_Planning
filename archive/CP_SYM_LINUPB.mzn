
include "globals.mzn";
include "lex_lesseq.mzn";  


% ----- defining parameters and variables ------------------------------ 
int: m;  % number of couriers
int: n;  % number of items
int: depot = n+1;  % depot node index 
int: max_route_length = n + 2;  % maximum possible route length

set of int: Couriers = 1..m;
set of int: Items = 1..n;
set of int: Nodes = 1..n+1;  % all nodes including depot (1..n+1)
set of int: Positions = 1..max_route_length;

array[Couriers] of int: l;  % capacities of couriers
array[Items] of int: s;  % sizes of items

% Distance matrix D[i,j]: Distance from node i to node j from the data 
array[Nodes, Nodes] of int: D;

% -------------------- problem variables ------------------------------ 
% route[k,p]: node visited by courier k at position p
array[Couriers, Positions] of var 0..n+1: route;

% route_length[k]: length of courier k's route so far
array[Couriers] of var 2..max_route_length: route_length;

% total distance traveled by each courier
array[Couriers] of var int: dist;

% opt: maximum distance traveled by any courier
var int: max_dist;

% ------------------ Constraints -------------------------------------
% 1. Cycle Constraint: route starts and ends at depot
constraint forall(k in Couriers)(
    route[k,1] = depot /\
    route[k, route_length[k]] = depot
);

% 2. Unused Positions: unused positions are zeros
constraint forall(k in Couriers, p in route_length[k]+1..max_route_length)(
    route[k,p] = 0 );

% 3. Items Assignment: each item is visited exactly once
constraint
    all_different([route[k,p] | k in Couriers, p in 2..route_length[k]-1 where route[k,p] > 0]);

% making sure all items are visited
constraint
    forall(i in Items)(
        exists(k in Couriers, p in 2..route_length[k]-1)(
            route[k,p] = i
        )
    );

% 4. Route Consistency: Nodes in each courier's route are unique
constraint forall(k in Couriers)(
    all_different([route[k,p] | p in 2..route_length[k]-1 where route[k,p] > 0]));

% 5. Capacity Constraints: the sum of items of each courier is below its capacity
constraint forall(k in Couriers)(
    sum(p in 2..route_length[k]-1)(
        s[route[k,p]]  % excluding depot
    ) <= l[k]
);

% 6. No Free Courier: ensure each courier carries at least one item (route length at least 3: depot, item, depot)
constraint forall(k in Couriers)(
    route_length[k] >= 3
);

% --------------------------------- Symmetry-Breaking Constraint --------------------------------
% Improved Symmetry Breaking Constraints
% 1. Order couriers by total load when they have equal capacity
constraint forall(i, j in Couriers where i < j /\ l[i] = l[j])(
    sum(p in 2..route_length[i]-1)(if route[i,p] > 0 then s[route[i,p]] else 0 endif) >=
    sum(p in 2..route_length[j]-1)(if route[j,p] > 0 then s[route[j,p]] else 0 endif)
);

% 2. For couriers with different capacities, higher capacity should handle more load
constraint forall(i, j in Couriers where i < j /\ l[i] > l[j])(
    sum(p in 2..route_length[i]-1)(if route[i,p] > 0 then s[route[i,p]] else 0 endif) >
    sum(p in 2..route_length[j]-1)(if route[j,p] > 0 then s[route[j,p]] else 0 endif)
);

% 3. Break symmetry for empty positions by forcing zeros to appear at the end
constraint forall(k in Couriers, p in 2..max_route_length-1)(
    route[k,p] = 0 -> route[k,p+1] = 0
);

% ------------------- Upper Bound using linear regression formula --------------------------------
% coefs from Ridge regression model
float: intercept = 60.0;
float: coef1 = 20.16;
float: coef2 = -12.66;
float: coef3 = -70.89;
float: coef4 =9.49;

% calculating features

% x1: mean_distance (mean distance between all nodes, excluding self-distances)
float: total_distance = sum(i in Nodes, j in Nodes where i != j)(int2float(D[i,j]));
float: count_distances = int2float((n + 1) * n);
float: x1 = total_distance / count_distances;

% x2: mean_capacity
float: x2 = sum(k in Couriers)(int2float(l[k])) / int2float(m);

% x3: num_couriers
float: x3 = int2float(m);

% x4: total_item_size
float: x4 = sum(i in Items)(int2float(s[i]));

% compute UB using the regression formula
float: UB_real = intercept + coef1 * x1 + coef2 * x2 + coef3 * x3 + coef4 * x4;

% setting a minimum to the possible UB
float: UB_nonnegative = max(20.0, UB_real);

% ceil to ensure it's sufficient and integer
int: UB = ceil(UB_nonnegative);

% Upper Bound constraint
constraint max_dist <= UB;

% -------------------------- Calculation of Maximum Distance -------------------------------------
% Distance Calculation
constraint forall(k in Couriers)(
    dist[k] = sum(p in 1..route_length[k]-1)(
        D[route[k,p], route[k,p+1]]
    )
);

% Maximum Distance
constraint forall(k in Couriers)(
    max_dist >= dist[k]
);
% ------------------------------------------------------------------------------------------------

% Objective Function
solve :: int_search(
    [route[k,p] | k in Couriers, p in Positions],
    first_fail,    % More effective variable selection
    indomain_max,  % Deterministic value selection
    complete
) minimize max_dist;


% Output Formatting
output [
    "Maximum distance traveled by any courier: ", show(fix(max_dist)), "\n",
    "The Upper Bound: ", show(fix(UB)), "\n",
    "\nCourier Routes and Assignments:\n",
    concat([
        let { int: rl = fix(route_length[k]) } in
        concat([
            "Courier ", show(k), ":\n    Route: ",
            concat([
                show(fix(route[k,p])) ++ " "
                | p in 2..rl-1
            ]),
            "\n    Total Distance: ", show(fix(dist[k])), "\n"
        ])
        | k in Couriers
    ])
];