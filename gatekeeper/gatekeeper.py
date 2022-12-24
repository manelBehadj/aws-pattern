import argparse
import re
import requests
import json

from flask import Flask
from flask import jsonify, request


app = Flask(__name__)
# Disable json keys sorting
app.config["JSON_SORT_KEYS"] = False


parser = argparse.ArgumentParser()
parser.add_argument("proxy_private_ip", help="Private ip to reach the proxy")

# Get args
args = parser.parse_args()
proxy_private_ip = args.proxy_private_ip

# Regex to match restricted queries. Only select and insert operations from/into actor table are authorized

select_validator = re.compile(r"(?i)(^SELECT \* FROM actor .)")
insert_validator = re.compile(r"(?i)(^INSERT INTO actor ?\((first_name,\s{0,}last_name)\) VALUES)")


"""
Direct endpoint that validate query before sending it to proxy and master node. If query does not match with rules defined above.
The request will be aborted with Access denied as message 
:param json: json data that contains query
:return: Query output
"""
@app.route("/direct", methods=["POST"])
def save():
    request_data = request.get_json()
    if validate("insert", request_data["query"]):
        proxy_response = requests.post(
            f"http://{proxy_private_ip}:8081/direct", json=request_data
        )
        return json.loads(proxy_response.content)
    else:
        response = "Access denied by gatekeeper"
        return jsonify(message=response), 403


"""
Direct endpoint that validate query before sending it to proxy and master node. If query does not match with rules defined above.
The request will be aborted with Access denied as message 
:param json: json data that contains query
:return: Query output
"""
@app.route("/direct", methods=["GET"])
def direct_call():
    request_data = request.get_json()
    print(request_data)
    if validate("select", request_data["query"]):
        proxy_response = requests.get(
            f"http://{proxy_private_ip}:8081/direct", json=request_data
        )
        return json.loads(proxy_response.content)

    else:
        response = "Access denied by gatekeeper"
        print(response)
        return jsonify(message=response), 403


"""
Random endpoint that validate query before sending it to proxy and slave nodes. If query does not match with rules defined above.
The request will be aborted with Access denied as message 
:param json: json data that contains query
:return: Query output
"""
@app.route("/random", methods=["GET"])
def random_call():
    request_data = request.get_json()
    if validate("select", request_data["query"]):
        proxy_response = requests.get(
            f"http://{proxy_private_ip}:8081/random", json=request_data
        )
        return json.loads(proxy_response.content)
    else:
        response = "Access denied by gatekeeper"
        return jsonify(message=response), 403


"""
Custom endpoint that validate query before sending it to proxy and best ping time node. If query does not match with rules defined above.
The request will be aborted with Access denied as message 
:param json: json data that contains query
:return: Query output
"""
@app.route("/custom", methods=["GET"])
def custom_call():
    request_data = request.get_json()
    if validate("select", request_data["query"]):
        proxy_response = requests.get(
            f"http://{proxy_private_ip}:8081/custom", json=request_data
        )
        return json.loads(proxy_response.content)
    else:
        response = "Access denied by gatekeeper"
        return jsonify(message=response), 403


"""
Delete endpoint that ensure that only select/insert operations are allowed
:param json: json data that contains query
:return: Query output
"""
@app.route("/delete", methods=["DELETE"])
def delete():
    request_data = request.get_json()
    if validate("delete", request_data["query"]):
        print("Nothing to do")
    else:
        response = "Access denied by gatekeeper"
        return jsonify(message=response), 403


"""
Funtion that uses regex to validate that the query is allowed to be sent to proxy or not
The request will be aborted with Access denied as message 
:param json: json data that contains query
:return: Query output
"""
def validate(mode, query):
    if mode == "insert":
        return bool(insert_validator.match(" ".join(query.split())))
    if mode == "select":
        return bool(select_validator.match(" ".join(query.split())))
    return False


if __name__ == "__main__":
    app.run(debug=False, host="0.0.0.0", port=8080)
