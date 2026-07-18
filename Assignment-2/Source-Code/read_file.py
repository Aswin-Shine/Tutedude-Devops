file_name = "assignment_output.txt"

# Open the file in read-only mode ('r')
print(f"Task 4: Reading from '{file_name}':\n")

try:
    with open(file_name, "r") as file:
        content = file.read()
        print(content)
except FileNotFoundError:
    print(f"Error: The file '{file_name}' does not exist. Please run Task 3 first!")