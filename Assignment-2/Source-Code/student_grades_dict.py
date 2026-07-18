# Initialize an empty dictionary to hold student records
student_grades = {}

while True:
    print("\n--- Student Grades Manager ---")
    print("1. Add a new student")
    print("2. Update an existing student's grade")
    print("3. Print all student grades")
    print("4. Exit")
    
    choice = input("Choose an option (1-4): ")
    
    if choice == '1':
        name = input("Enter student name: ")
        if name in student_grades:
            print(f"Error: {name} already exists! Use Option 2 to update.")
        else:
            grade = input(f"Enter grade for {name}: ")
            student_grades[name] = grade
            print(f"Successfully added {name} with grade {grade}.")
            
    elif choice == '2':
        name = input("Enter student name to update: ")
        if name in student_grades:
            new_grade = input(f"Enter new grade for {name}: ")
            student_grades[name] = new_grade
            print(f"Successfully updated {name}'s grade to {new_grade}.")
        else:
            print(f"Error: Student '{name}' not found.")
            
    elif choice == '3':
        if not student_grades:
            print("The dictionary is currently empty.")
        else:
            print("\nCurrent Roster:")
            for name, grade in student_grades.items():
                print(f"Student: {name} | Grade: {grade}")
                
    elif choice == '4':
        print("Exiting program.")
        break
    else:
        print("Invalid choice. Please select a number from 1 to 4.")