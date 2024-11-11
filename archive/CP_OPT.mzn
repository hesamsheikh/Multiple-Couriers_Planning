include "globals.mzn";
include "lex_lesseq.mzn";

% Parameters
int: m;  % number of couriers
int: n;  % number of items
int: depot = n+1;  
int: max_route_length = n + 2;  

set of int: Couriers = 1..m;
set of int: Items = 1..n;
set of int: Nodes = 1..n+1;  
set of int: Positions = 1..max_route_length;

array[Couriers] of int: l;  
array[Items] of int: s;  
array[Nodes, Nodes] of int: D;

% Pre-calculated bounds and parameters
int: total_capacity = sum(l);
int: total_item  = sum(s);
int: max_single_capacity = max(l);
int: min_single_item = min(s);
int: max_single_item  = max(s);
int: min_dist = 2 * min(i,j in Nodes where i != j)(D[i,j]);
int: max_possible_dist = sum(i in Items)(D[i,depot]); % Upper bound on maximum distance
int: min_couriers_needed = ceil(total_item  / max_single_capacity);

% Variables
array[Couriers, Positions] of var 0..n+1: route;
array[Couriers] of var 2..max_route_length: route_length;
array[Couriers] of var int: dist;
array[Couriers] of var 0..total_item : courier_load; % Added to track loads directly
var int: max_dist;

% Basic routing constraints (unchanged)
constraint forall(k in Couriers)(
    route[k,1] = depot /\
    route[k, route_length[k]] = depot
);

constraint forall(k in Couriers, p in route_length[k]+1..max_route_length)(
    route[k,p] = 0
);

% Item assignment constraint
constraint forall(i in Items)(
    count([route[k,p] | k in Couriers, p in 2..max_route_length-1], i) = 1
);

% Load calculation and capacity constraints
constraint forall(k in Couriers)(
    courier_load[k] = sum(p in 2..route_length[k]-1)(
        if route[k,p] > 0 then s[route[k,p]] else 0 endif
    )
);

constraint forall(k in Couriers)(
    courier_load[k] <= l[k]
);

% Route length constraints with tighter bounds
constraint forall(k in Couriers)(
    route_length[k] >= 3 /\
    route_length[k] <= min(max_route_length, 
                          2 + ceil(l[k] / min_single_item ))  % Tighter upper bound
);

% Distance calculations with bounds
constraint forall(k in Couriers)(
    dist[k] = sum(p in 1..route_length[k]-1)(
        D[route[k,p], route[k,p+1]]
    )
);

constraint forall(k in Couriers)(
    dist[k] >= min_dist /\
    dist[k] <= max_possible_dist
);

constraint max_dist = max(k in Couriers)(dist[k]);

% Enhanced symmetry breaking for equal capacity couriers
constraint forall(i,j in Couriers where i < j /\ l[i] = l[j])(
    lex_lesseq([route[i,p] | p in 1..max_route_length],
               [route[j,p] | p in 1..max_route_length])
);

% Better search strategy incorporating LNS and multiple phases
solve :: seq_search([
    % Phase 1: Route construction with impact-based search
    int_search([route[k,p] | k in Couriers, p in Positions],
               first_fail,  % Alternative to dom_w_deg
               indomain_split,
               complete),

    % Phase 2: Route length optimization
    int_search(route_length, 
               first_fail,
               indomain_split,
               complete),

    % Use relax_and_reconstruct instead of LNS
    relax_and_reconstruct([route[k,p] | k in Couriers, p in Positions], 30),

    % restart_luby(m*n)
]) minimize max_dist;

output [
    "maximum distance of any courier: ", show(fix(max_dist)), "\n",
    "\ncourier routes and assignments:\n",
    concat([
        let { int: rl = fix(route_length[k]) } in
        concat([
            "courier ", show(k), 
            ":\n    route: ",
            concat([
                show(fix(route[k,p])) ++ " "
                | p in 2..rl-1
            ]),
            "\n    Total Distance: ", show(fix(dist[k])), "\n"
        ])
        | k in Couriers
    ])
];
