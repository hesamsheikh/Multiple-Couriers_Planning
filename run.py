import subprocess
import os
import json
import re

def parse_output_into_json(output_string):
    # Parse the output
    max_distance_match = re.search(r'Maximum distance traveled by any courier: (\d+)', output_string)
    max_distance = int(max_distance_match.group(1)) if max_distance_match else None

    courier_routes = []
    courier_pattern = re.compile(r'Courier \d+:\n\s+Route: ([\d\s]+)\n')
    for match in courier_pattern.finditer(output_string):
        route = list(map(int, match.group(1).strip().split()))
        courier_routes.append(route)

    time_elapsed_match = re.search(r'% time elapsed: ([\d.]+) s', output_string)
    time_elapsed = float(time_elapsed_match.group(1)) if time_elapsed_match else None

    upper_bound_match = re.search(r'The Upper Bound: (\d+)', output_string)
    upper_bound = int(upper_bound_match.group(1)) if upper_bound_match else None

    solve_time_match = re.search(r'%%%mzn-stat: solveTime=([\d.]+)', output_string)
    solve_time = float(solve_time_match.group(1)) if solve_time_match else None

    # Create the JSON object
    result = {
        "time": time_elapsed,
        "solve_time": solve_time,
        "upper_bound": upper_bound,
        "optimal": False if time_elapsed > 300 else True,
        "obj": max_distance,
        "sol": courier_routes,
    }
    return result

def run_subprocess(instance_path, model):
    try:
        output = subprocess.run(
            [
                "minizinc", 
                "-m", model, 
                "-d", instance_path,
                "--solver", 'gecode', 
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
        return output.stdout
    except:
        print(f"Process timed out and was terminated for model {model}.")
        return None


def solve_instance_cp(models, instance_path):
    output_json = {}

    for model in models:
        output_string = run_subprocess(instance_path, model)
        if output_string:
            output_json[model] = parse_output_into_json(output_string)

    return output_json

instances_dir = "instances_dzn"
output_dir = "json_output2"
models = [
    "CP_SYM_UPB.mzn",
    "CP_SYM_LINUPB.mzn"
    ]  # List of solvers to run


# Ensure the output directory exists
os.makedirs(output_dir, exist_ok=True)

# Iterate over each file in the instances directory
for instance_file in os.listdir(instances_dir):
    if not instance_file.endswith(".dzn"):
        print("File type must be .dzn.")
        continue

    instance_path = os.path.join(instances_dir, instance_file)
    output_json = solve_instance_cp(models, instance_path)

    # Save the JSON output to the output directory
    json_filename = f"{os.path.splitext(instance_file)[0]}.json"
    json_path = os.path.join(output_dir, json_filename)
    with open(json_path, 'w') as json_file:
        json.dump(output_json, json_file, indent=4)

...