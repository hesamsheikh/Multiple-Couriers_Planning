
include "globals.mzn";
include "lex_lesseq.mzn";  


% ----- defining parameters and variables ------------------------------ 
int: m;                                         % number of couriers
int: n;                                         % number of items
int: depot = n+1;                               % depot node index 
int: max_route_length = n + 2;                  % maximum possible route length

set of int: Couriers = 1..m;
set of int: Items = 1..n;
set of int: Nodes = 1..n+1;                     % all nodes including depot (1..n+1)
set of int: Positions = 1..max_route_length;

array[Couriers] of int: l;                      % capacities of couriers
array[Items] of int: s;                         % sizes of items

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
% lexicographical order of routes to avoid symmetry
constraint forall(k in 1..m-1)(
    lex_lesseq([route[k,p] | p in Positions], [route[k+1,p] | p in Positions])
);

% additional symmetry breaking for equal-capacity couriers
constraint forall(k1, k2 in Couriers where k1 < k2 /\ l[k1] = l[k2])(
    dist[k1] <= dist[k2]
);

% ------------------- Upper Bound using linear regression formula --------------------------------
% coefs from Ridge regression
float: intercept = 60.0;
float: coef1= 20.16;
float: coef2 = -12.66;
float: coef3 =-70.89;
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

% -------------------------- Lower Bound Calculation ---------------------------------------------
% Compute minimum items each courier must carry
int: min_items_per_courier = max(1, ceil(n / m));

% For each courier, calculate minimum required distance by selecting closest items within capacity
array[Couriers] of int: courier_min_dists = [
    let {
        array[int] of int: valid_items = [j | j in Items where s[j] <= l[k]],  % Fit items within capacity
        array[int] of int: sorted_dists = sort([D[i, j] | i, j in valid_items where i != j])
    } in
    sum(i in 1..min_items_per_courier)(sorted_dists[i]) + 2 * min([D[i, depot] | i in valid_items])
    | k in Couriers
];

int: LB = max(courier_min_dists) - 10;  % Max of minimum distances based on item distribution feasibility


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

% ---------------------- Encouraging a more even distribution ------------------------------------
%  variables to count the number of items each courier is carrying (excluding depot)
array[Couriers] of var 0..n: num_items_per_courier;

% calculating the number of items each courier carries by counting non-zero item indices in their route
constraint forall(k in Couriers) (
    num_items_per_courier[k] = sum(p in 2..route_length[k]-1)(if route[k, p] > 0 then 1 else 0 endif)
);

% limit the difference between the maximum and minimum number of items through allthe couriers
var int: max_items = max(num_items_per_courier);
var int: min_items = min(num_items_per_courier);
constraint max_items - min_items <= 4;
% ------------------------------------------------------------------------------------------------


constraint max_dist <= UB;
constraint max_dist >= LB;


% Search Annotation
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
    "The Lower Bound: ", show(fix(LB)), "\n",
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