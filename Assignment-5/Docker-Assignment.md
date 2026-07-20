<div align="center">

# Assignment 5 : Docker

</div>

**Structure your directory**
```
assignment-5-app/
├── .gitignore
├── docker-compose.yml
├── backend/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
└── frontend/
    ├── server.js
    ├── Dockerfile
    ├── package.json
    └── views/
        └── form.ejs
```

---

**Step 1 : Create frontend of the app and dockerfile**

JAVASCRIPT CODE (frontend/server.js)
```
const express = require('express');
const axios = require('axios');
const path = require('path');

const app = express();
const PORT = 3000;

// Target the backend container service using internal Docker Compose DNS routing
const BACKEND_URL = process.env.BACKEND_URL || 'http://backend:5000/api/submit';

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Render initial user submission viewport
app.get('/', (req, res) => {
    res.render('form', { error: null });
});

// Capture Form submission action and route via axios to the Flask worker container
app.post('/submit', async (req, res) => {
    const { username, email } = req.body;
    
    try {
        const response = await axios.post(BACKEND_URL, { username, email });
        
        if (response.data.success) {
            res.send("<h1>Data submitted successfully</h1>");
        } else {
            res.render('form', { error: response.data.error || "Execution fault." });
        }
    } catch (err) {
        // Render failure state inside current client frame without redirecting
        const errMessage = err.response?.data?.error || err.message;
        res.render('form', { error: `Backend Unreachable: ${errMessage}` });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Frontend service listening on port ${PORT}`);
});
```

HTML CODE (frontend/views/form.ejs)
```
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Multi-Container App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; background-color: #f4f6f9; }
        .wrapper { max-width: 400px; padding: 25px; border: 1px solid #ddd; border-radius: 8px; background: #fff; }
        .error { color: white; background: #d9534f; padding: 10px; margin-bottom: 15px; border-radius: 4px; }
        .field { margin-bottom: 15px; }
        .field label { display: block; margin-bottom: 5px; font-weight: bold; }
        .field input { width: 95%; padding: 10px; border: 1px solid #ccc; border-radius: 4px; }
        button { width: 100%; background: #28a745; color: white; padding: 10px; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
    </style>
</head>
<body>

    <div class="wrapper">
        <h2>Node to Flask Database Pipeline</h2>
        
        <% if (error) { %>
            <div class="error">
                <strong>Error:</strong> <%= error %>
            </div>
        <% } %>

        <form action="/submit" method="POST">
            <div class="field">
                <label>Username:</label>
                <input type="text" name="username" required>
            </div>
            <div class="field">
                <label>Email Address:</label>
                <input type="email" name="email" required>
            </div>
            <button type="submit">Deploy Content</button>
        </form>
    </div>

</body>
</html>
```

DOCKERFILE (frontend/dockerfile)
```
FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```
**Frontend Explanation**
- UI Generation Engine (ejs): The application leverages Embedded JavaScript (EJS) templates. This allows Node to dynamically pass context state (like operational errors) straight down into the user's browser frame without executing external redirections or changing the active URL path.

- API Communication (axios): Because the browser client interacts solely with the Node engine on port 3000, the Node runtime handles server-side HTTP forwarding. When the user hits submit, Node aggregates the form variables and triggers an asynchronous server-to-server POST query via axios to push the payload to the internal API endpoint.

- Internal Docker Service Mapping: Instead of resolving to a hardcoded public host location like localhost or an external IP, the variable context targets http://backend:5000/api/submit. This shifts domain resolution duties straight over to Docker's built-in container network DNS manager.

- Optimized Image Footprint (node:18-alpine): The frontend Dockerfile leverages an Alpine Linux distribution base. Alpine drops image weight by hundreds of megabytes by stripping non-essential tracking utilities, minimizing container storage costs and reducing production security vulnerability surfaces.

![Screenshot 1](./Screenshots/Screenshot-1.png)

![Screenshot 1.1](./Screenshots/Screenshot-1.1.png)

---

**Step 2 : Create backend of the app and dockerfile**

PYTHON CODE (backend/app.py)
```
from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo import MongoClient
import os

app = Flask(__name__)
# Enable Cross-Origin Resource Sharing so our Node app can make API requests
CORS(app)

# Fallback URI connection configuration
MONGO_URI = os.getenv("MONGO_URI", "mongodb+srv://<username>:<password>@cluster0.mongodb.net/tutedude?retryWrites=true&w=majority")

try:
    client = MongoClient(MONGO_URI)
    db = client['tutedude_devops']
    collection = db['submissions']
except Exception as e:
    print(f"Database Connection Failure: {e}")

@app.route('/api/submit', methods=['POST'])
def handle_submission():
    data = request.get_json()
    if not data:
        return jsonify({"success": False, "error": "No payload received"}), 400
        
    username = data.get('username')
    email = data.get('email')
    
    if not username or not email:
        return jsonify({"success": False, "error": "Missing required data fields"}), 400
        
    try:
        # Commit to MongoDB Atlas cluster 
        document = {"username": username, "email": email}
        collection.insert_one(document)
        return jsonify({"success": True, "message": "Data processed successfully"}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

DOCKERFILE (backend/dockerfile)
```
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
```

**Backend Explanation**
- Headless API Architecture: The Flask daemon completely avoids rendering HTML views or managing UI assets. It focuses entirely on processing standard application/json data strings, parsing parameters, and returning clean HTTP tracking codes (200 OK or 400/500 Errors) back to the frontend processor.

- Cross-Origin Resource Sharing (flask-cors): To prevent the application from blocking incoming traffic due to standard secure sandbox restrictions, the backend loads the CORS middleware system. This ensures that the Python endpoint accepts input queries generated from varying host ports and container profiles safely.

- State Persistence Execution (pymongo): The API loads environment connection paths using runtime variables (os.getenv), securing credentials away from the tracked source files. It establishes a socket connection pool straight to your cloud-managed MongoDB Atlas Cluster, writing the structured information into a document store using standard BSON collections.

- Minimalist Container Core (python:3.10-slim): The backend utilizes a Slim Debian-based Python base image. This skips heavy graphic layers and peripheral system device frameworks while maintaining the exact structural runtime packages required to successfully compile dynamic C-extensions for tools like pymongo.

![Screenshot 2](./Screenshots/Screenshot-2.png)

![Screenshot 2.1](./Screenshots/Screenshot-2.1.png)

---

**Step 3 : Create docker compose file**

DOCKER COMPOSE (assignment-5-app/docker-compose.yml)
```
services:
  frontend:
    build: ./frontend
    container_name: devops_node_frontend
    ports:
      - "3000:3000"
    environment:
      - BACKEND_URL=http://backend:5000/api/submit
    depends_on:
      - backend
    networks:
      - devops_bridge_net

  backend:
    build: ./backend
    container_name: devops_flask_backend
    ports:
      - "5000:5000"
    environment:
      - MONGO_URI=mongodb+srv://aswinshine:YOURPASSWORD@cluster0.abcde.mongodb.net/tutedude?retryWrites=true&w=majority
    networks:
      - devops_bridge_net

networks:
  devops_bridge_net:
    driver: bridge
```

![Screenshot 3](./Screenshots/Screenshot-3.png)

---

<div align="center">

## Project Screenshots

</div>

![Screenshot 4](./Screenshots/Screenshot-4.png)

![Screenshot 5](./Screenshots/Screenshot-5.png)

![Screenshot 6](./Screenshots/Screenshot-6.png)
