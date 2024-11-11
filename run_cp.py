import subprocess
import os
import json
import re

def parse_output_into_json(output_string):
    # Parse the output
    max_distance_match = re.search(r'maximum distance of any courier: (\d+)', output_string)
    max_distance = int(max_distance_match.group(1)) if max_distance_match else None

    max_possible_dist_match = re.search(r'max possible distance: (\d+)', output_string)
    max_possible_dist = int(max_possible_dist_match.group(1)) if max_possible_dist_match else None

    courier_max_lengths = re.search(r'courier max lengths: (\d+)', output_string)
    courier_max_lengths = int(courier_max_lengths.group(1)) if courier_max_lengths else None

    courier_routes = []
    courier_pattern = re.compile(r'courier \d+:\n\s+route: ([\d\s]+)\n')
    for match in courier_pattern.finditer(output_string):
        route = list(map(int, match.group(1).strip().split()))
        courier_routes.append(route)
    courier_routes = str(courier_routes)
    if courier_routes: courier_routes = courier_routes[1:len(courier_routes)-1]

    time_elapsed_match = re.search(r'% time elapsed: ([\d.]+) s', output_string)
    time_elapsed = float(time_elapsed_match.group(1)) if time_elapsed_match else None

    solve_time_match = re.search(r'%%%mzn-stat: solveTime=([\d.]+)', output_string)
    solve_time = float(solve_time_match.group(1)) if solve_time_match else None

    # Create the JSON object
    result = {
        "total_time": time_elapsed,
        "solve_time": solve_time,
        "courier_max_lengths": courier_max_lengths,
        "UP": max_possible_dist,
        "optimal": False if time_elapsed > 300 else True,
        "obj": max_distance,
        "sol": courier_routes,
    }    
    return result

def run_subprocess(instance_path, model, solver_type="gecode"):
    try:
        output = subprocess.run(
            [
                "minizinc", 
                "-m", model, 
                "-d", instance_path,
                "--solver", solver_type, 
                "--output-time", 
                "--solver-time-limit", "300000",
                "-s" 
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            shell=False, 
            timeout=301,
        )
        if output.stderr and DEBUG:
            print(output.stderr)

        return output.stdout
    
    except:
        print(f"Process timed out and was terminated for model {model}.")
        return None


def solve_instance_cp(models, instance_path, solver_types):
    output_json = {}

    for model in models:
        for solver in solver_types:
            output_string = run_subprocess(instance_path, model, solver)
            if output_string:
                output_json[solver+"_"+model.split(".")[0]] = parse_output_into_json(output_string)
                ...

    return output_json

def save_json_output(json_data):
    # Save the JSON output to the output directory
    json_filename = f"{os.path.splitext(instance_file)[0]}.json"
    json_path = os.path.join(output_dir, json_filename)
    with open(json_path, 'w') as json_file:
        json.dump(json_data, json_file, indent=4)
    ...

if __name__=="__main__":
    DEBUG = 1
    instances_dir = "instances_dzn"
    output_dir = "outputs/CP_test_search"
    exclude_list = [
        "inst11.dat",
        "inst14.dat",
        "inst15.dat",
        "inst18.dat",
        "inst20.dat",
    ]
    models = [
        # "CP_NO_SYMBRK.mzn",
        # "CP_OPT.mzn",
        "CP_test.mzn",
        # "CP_SYM_VER2.mzn",
        ]
    solver_types = [
        "gecode", 
        # "chuffed"
        ]


    # create a directory if not exists
    os.makedirs(output_dir, exist_ok=True)

    # solve each instance in the directory
    for instance_file in os.listdir(instances_dir)[13:19]:
        if instance_file in exclude_list: 
            pass
        if not instance_file.endswith(".dzn"):
            print("File type must be .dzn.")
            continue
        instance_path = os.path.join(instances_dir, instance_file)
        
        print(f"Solving {instance_file}")
        output_json = solve_instance_cp(models, instance_path, solver_types)

        if output_json:
            save_json_output(output_json)
        ...

...