#main.py
import os
import sys
from flask import Flask, jsonify, request
from pymongo import MongoClient, ReturnDocument
from bson.json_util import dumps
import json
from urllib.parse import quote_plus

app = Flask(__name__)

# --- Product Data ---
PRODUCTS = [
    {"_id": 1, "name": "A Dozen Large Eggs", "price": 4.29, "image": "/images/eggs.png"},
    {"_id": 2, "name": "KitchenAid Artisan Series 5 Quart Stand Mixer", "price": 449.95, "image": "/images/kitchenaid_mixer.png"},
    {"_id": 3, "name": "Toilet Paper (12 Mega Rolls)", "price": 22.50, "image": "/images/toilet_paper.png"},
    {"_id": 4, "name": "Gallon of Milk", "price": 3.89, "image": "/images/milk_gallon.png"},
    {"_id": 5, "name": "Amazon Fire TV Stick 4K", "price": 49.99, "image": "/images/fire_stick.png"},
    {"_id": 6, "name": "Paper Towels (6 Double Rolls)", "price": 15.99, "image": "/images/paper_towels.png"},
    {"_id": 7, "name": "Fujifilm Instax Mini 12 Instant Camera", "price": 79.95, "image": "/images/fujifilm_camera.png"},
    {"_id": 8, "name": "A Loaf of Bread", "price": 3.49, "image": "/images/bread.png"},
    {"_id": 9, "name": "Yoga Mat", "price": 34.95, "image": "/images/yoga_mat.png"},
    {"_id": 10, "name": "Sonos Era 100 Speaker", "price": 249.00, "image": "/images/sonos_speaker.png"},
    {"_id": 11, "name": "Laundry Detergent (92 oz)", "price": 14.97, "image": "/images/laundry_detergent.png"},
    {"_id": 12, "name": "Wireless Optical Mouse", "price": 29.99, "image": "/images/mouse.png"},
    {"_id": 13, "name": "Compact Travel Umbrella", "price": 24.99, "image": "/images/umbrella.png"}
]



required_vars = ['DB_USER', 'DB_PASS', 'DB_HOST', 'DB_NAME']
missing_vars = [var for var in required_vars if not os.environ.get(var)]

if missing_vars:
    print(f"ERROR: Missing required environment variables: {', '.join(missing_vars)}")
    sys.exit(1)

mongo_user = os.environ.get('DB_USER')
mongo_password = os.environ.get('DB_PASS')
mongo_host = os.environ.get('DB_HOST')
db_name = os.environ.get('DB_NAME')

escaped_user = quote_plus(mongo_user)
escaped_password = quote_plus(mongo_password)

db_uri = f"mongodb://{escaped_user}:{escaped_password}@{mongo_host}:27017/{db_name}?authSource=admin"

try:
    client = MongoClient(db_uri)
    client.admin.command('ismaster')
    print("Successfully connected to MongoDB!")
    db = client[db_name]

    if 'items' not in db.list_collection_names() or db.items.count_documents({}) == 0:
        print("Items collection is empty. Seeding database...")
        db.items.insert_many(PRODUCTS)
        print("Database seeded with products.")
    else:
        print("Items collection already contains data.")

except Exception as e:
    print(f"Error connecting to or seeding MongoDB: {e}")
    db = None

# --- API Routes ---

@app.route('/items', methods=['GET'])
def get_items():
    if db is None:
        return jsonify({"error": "Database connection failed"}), 500
    try:
        items = list(db.items.find())
        return dumps(items), 200
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route('/bid', methods=['POST'])
def place_bid():
    if db is None:
        return jsonify({"error": "Database connection failed"}), 500
    try:
        data = request.get_json()
        item_id = int(data['itemId'])
        bid_amount = float(data['bid'])
        username = data.get('username', 'Anonymous')

        item = db.items.find_one({"_id": item_id})
        if not item:
            return jsonify({"error": "Item not found"}), 404
        
        actual_price = item['price']
        difference = abs(actual_price - bid_amount)
        score = max(0, 100 - difference)

        leaderboard_entry = db.leaderboard.find_one_and_update(
            {'username': username},
            {'$inc': {'score': score}},
            upsert=True,
            return_document=ReturnDocument.AFTER
        )

        return jsonify({
            "message": "Bid placed successfully!",
            "yourBid": bid_amount,
            "actualPrice": actual_price,
            "scoreThisRound": round(score, 2),
            "newTotalScore": round(leaderboard_entry['score'], 2)
        }), 200

    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route('/leaderboard', methods=['GET'])
def get_leaderboard():
    if db is None:
        return jsonify({"error": "Database connection failed"}), 500
    try:
        leaderboard_data = list(db.leaderboard.find({}, {'_id': 0}).sort('score', -1))
        return jsonify(leaderboard_data), 200
    except Exception as e:
        return jsonify(error=str(e)), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
