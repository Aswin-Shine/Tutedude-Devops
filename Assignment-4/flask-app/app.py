from flask import Flask, jsonify, render_template, request, redirect, url_for
import json
from pymongo import MongoClient
from pymongo.errors import PyMongoError

app = Flask(__name__)

# --- MongoDB Atlas Configuration ---
# Replace this with your actual connection string from Atlas
MONGO_URI = "mongodb+srv://<username>:<password>@cluster0.mongodb.net/myDatabase?retryWrites=true&w=majority"

try:
    client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
    db = client['tutedude_devops']
    collection = db['submissions']
except Exception as e:
    print(f"Initial MongoDB Connection Error: {e}")

# =====================================================================
# TASK 1: Read data from a backend file and return a JSON list
# =====================================================================
@app.route('/api', methods=['GET'])
def get_api_data():
    try:
        # Open and parse the backend json file
        with open('data.json', 'r') as file:
            data = json.load(file)
        return jsonify(data), 200
    except FileNotFoundError:
        return jsonify({"error": "Backend data file not found"}), 404
    except json.JSONDecodeError:
        return jsonify({"error": "Invalid JSON format in backend file"}), 500

# =====================================================================
# TASK 2: Frontend Form processing with MongoDB Atlas
# =====================================================================
@app.route('/', methods=['GET', 'POST'])
def home_form():
    error_message = None
    
    if request.method == 'POST':
        # Extract data from the submitted form fields
        username = request.form.get('username')
        email = request.form.get('email')
        
        # Validate that fields aren't completely empty
        if not username or not email:
            error_message = "All fields are required!"
            return render_template('form.html', error=error_message)
            
        try:
            # Attempt to insert data into the MongoDB Atlas Collection
            document = {"username": username, "email": email}
            collection.insert_one(document)
            
            # Redirect to the success page upon smooth execution
            return redirect(url_for('success_page'))
            
        except PyMongoError as e:
            # Stay on the same page and pass the exact database error string
            error_message = f"Database Error: {str(e)}"
            return render_template('form.html', error=error_message)
            
    return render_template('form.html', error=error_message)

@app.route('/todo')
def todo_view():
    return render_template('todo.html')

@app.route('/submittodoitem', methods=['POST'])
def submit_todo_item():
    item_name = request.form.get('itemName')
    item_desc = request.form.get('itemDescription')
    
    try:
        # Connect to your existing MongoDB configuration instance
        db.todo_collection.insert_one({
            "itemName": item_name,
            "itemDescription": item_desc
        })
        return "<h3>To-Do Item Added Safely to MongoDB</h3>", 200
    except Exception as e:
        return f"Database Error: {str(e)}", 500

@app.route('/success')
def success_page():
    return "<h1>Data submitted successfully</h1>"

if __name__ == '__main__':
    app.run(debug=True, port=5000)