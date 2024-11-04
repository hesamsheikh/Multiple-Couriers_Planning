
include "globals.mzn";
include "lex_lesseq.mzn";  % Include the correct lexicographical comparison module


% Parameters
int: m;  % Number of couriers
int: n;  % Number of items
int: depot = n+1;  % Depot node index 
int: max_route_length = n + 2;  % Maximum possible route length

set of int: Couriers = 1..m;
set of int: Items = 1..n;
set of int: Nodes = 1..n+1;  % Nodes including depot (1..11)
set of int: Positions = 1..max_route_length;

array[Couriers] of int: l;  % Capacities of couriers
array[Items] of int: s;  % Sizes of items

% Distance matrix D[i,j]: Distance from node i to node j
    % Node indices: 1  2  3  4  5  6  7  8 (Depot)
array[Nodes, Nodes] of int: D;

% Decision Variables
% route[k,p]: Node visited by courier k at position p
array[Couriers, Positions] of var 0..n+1: route;

% route_length[k]: Length of courier k's route (including start and end depot)
array[Couriers] of var 2..max_route_length: route_length;

% Total distance traveled by each courier
array[Couriers] of var int: dist;

% Maximum distance traveled by any courier
var int: max_dist;

% Constraints

% 1. Route starts and ends at depot
constraint forall(k in Couriers)(
    route[k,1] = depot /\
    route[k, route_length[k]] = depot
);

% 2. Unused positions are zeros
constraint forall(k in Couriers, p in route_length[k]+1..max_route_length)(
    route[k,p] = 0
);

% 3. Items Assignment: Each item is visited exactly once
constraint
    all_different([route[k,p] | k in Couriers, p in 2..route_length[k]-1 where route[k,p] > 0]);

% Ensure all items are visited
constraint
    forall(i in Items)(
        exists(k in Couriers, p in 2..route_length[k]-1)(
            route[k,p] = i
        )
    );

% 4. Route Consistency: Nodes in each courier's route are unique
constraint forall(k in Couriers)(
    all_different([route[k,p] | p in 2..route_length[k]-1 where route[k,p] > 0])
);

% 5. Capacity Constraints
constraint forall(k in Couriers)(
    sum(p in 2..route_length[k]-1)(
        s[route[k,p]]  % Exclude depot
    ) <= l[k]
);

% 6. Ensure each courier carries at least one item (route length at least 3: depot, item, depot)
constraint forall(k in Couriers)(
    route_length[k] >= 3
);

% Symmetry-Breaking Constraints
% ==============================================================================================

% Enforce lexicographical order of routes
constraint forall(k in 1..m-1)(
    lex_lesseq([route[k,p] | p in Positions], [route[k+1,p] | p in Positions])
);

% ==============================================================================================

% 6. Distance Calculation
constraint forall(k in Couriers)(
    dist[k] = sum(p in 1..route_length[k]-1)(
        D[route[k,p], route[k,p+1]]
    )
);

% 7. Maximum Distance
constraint forall(k in Couriers)(
    max_dist >= dist[k]
);

% Dynamic Upper Bound Calculation
% ------------------------------------------------------

% Compute average distance from depot to items
array[Items] of int: D_depot_to_items = [ D[depot, i] | i in Items ];
int: avg_D_depot_to_items = round(sum(D_depot_to_items) / n);

% Compute average distance between items directly without defining D_items
int: num_item_pairs = n * (n - 1) div 2;
int: sum_D_items = sum([ D[i, j] | i in Items, j in Items where i < j ]);
int: avg_D_items = round(sum_D_items / num_item_pairs);

% Estimate average item size
int: avg_s = round(sum(s) / n);

% Estimate number of items each courier can carry
array[Couriers] of int: est_items_per_courier = [ max(1, floor(l[k] / avg_s)) | k in Couriers ];

% Estimate maximum distance per courier
array[Couriers] of int: est_dist = [
    2 * avg_D_depot_to_items + (est_items_per_courier[k] - 1) * avg_D_items
    | k in Couriers
];

% Compute upper bound
int: UB = max(est_dist);

% Upper bound constraint
constraint max_dist <= UB;

% ------------------------------------------------------

% Objective Function
solve :: int_search(
    [route[k,p] | k in Couriers, p in Positions],
    first_fail,    % More effective variable selection
    indomain_min,  % Deterministic value selection
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
                | p in 1..rl
            ]),
            "\n    Total Distance: ", show(fix(dist[k])), "\n"
        ])
        | k in Couriers
    ])
];