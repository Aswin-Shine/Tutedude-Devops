file_name = "assignment_output.txt"

# Open the file in write mode ('w'). 
# This automatically creates the file or overwrites it if it already exists.
with open(file_name, "w") as file:
    file.write("Hello! This file was created using Python file operations.\n")
    file.write("DevOps automation often requires editing and reading configuration files.\n")

print(f"Task 3 Complete: Successfully wrote text content to '{file_name}'.")