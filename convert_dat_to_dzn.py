## DISCLAIMER: This code is AI-generated as it's not a main part of the submission

import sys

def convert_dat_to_dzn(filename):
    try:
        with open(filename, "r") as file:
            lines = file.readlines()
    except FileNotFoundError:
        print(f"Error: File {filename} not found.")
        sys.exit(1)

    # Start building the MiniZinc data format
    dzn_lines = []
    dzn_lines.append(f"m = {lines[0].strip()};")
    dzn_lines.append(f"n = {lines[1].strip()};")

    # Parse 'load' array
    load_values = lines[2].strip().split()
    dzn_lines.append(f"l = [{', '.join(load_values)}];")

    # Parse 'size' array
    size_values = lines[3].strip().split()
    dzn_lines.append(f"s = [{', '.join(size_values)}];")

    # Parse distance matrix D
    d_matrix = "D = ["
    for line in lines[4:]:
        row_values = line.strip().split()
        d_matrix += f"| {', '.join(row_values)} "
    d_matrix += "|];"

    dzn_lines.append(d_matrix)

    # Create the output directory if it doesn't exist
    output_dir = "instances_dzn"
    os.makedirs(output_dir, exist_ok=True)

    # Write the converted content to a .dzn file in the new directory
    base_filename = os.path.basename(filename).rsplit(".", 1)[0]
    output_filename = os.path.join(output_dir, base_filename + ".dzn")
    with open(output_filename, "w") as output_file:
        output_file.write("\n".join(dzn_lines) + "\n")

    print(f"Conversion completed. Output written to {output_filename}")

import os

if __name__ == "__main__":
    folder_path = "instances_dat"

    if not os.path.isdir(folder_path):
        print(f"Error: {folder_path} is not a valid directory.")
        sys.exit(1)

    for filename in os.listdir(folder_path):
        if filename.endswith(".dat"):
            file_path = os.path.join(folder_path, filename)
            convert_dat_to_dzn(file_path)

