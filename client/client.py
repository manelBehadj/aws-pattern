import requests
import argparse
import json


parser = argparse.ArgumentParser()
parser.add_argument("gatekeeper_dns", help="Instance DNS to reach the gatekeeper")


# Retrieve args
args = parser.parse_args()
gatekeeper_dns = args.gatekeeper_dns


"""
Insert data into a  database table through the gatekeeper
:param query: SQL INSERT query
:return: insertion status (success or failure)
"""
def insert_data(query):
    try:
        payload = {"query": query}
        response = requests.post(f"http://{gatekeeper_dns}:8080/direct", json=payload)
        return response
    except Exception as ex:
        print(f"Failed to insert data into database : {ex}")
        raise SystemExit(ex)


"""
Select data from table through the gatekeeper using direct call to master node
:param query: SQL select query
:return: Query output
"""
def select_direct_data(query):
    try:
        payload = {"query": query}
        response = requests.get(f"http://{gatekeeper_dns}:8080/direct", json=payload)
        return response
    except Exception as ex:
        print(f"Failed to select direct data from database : {ex}")
        raise SystemExit(ex)


"""
Select data from table through the gatekeeper using random call to silver nodes
:param query: SQL select query
:return: Query output
"""
def select_random_data(query):
    try:
        payload = {"query": query}
        response = requests.get(f"http://{gatekeeper_dns}:8080/random", json=payload)
        return response
    except Exception as ex:
        print(f"Failed to select random data from database : {ex}")
        raise SystemExit(ex)


"""
Select data from table through the gatekeeper using custom call with best ping time between master and slaves
:param query: SQL select query
:return: Query output
"""
def select_custom_data(query):
    try:
        payload = {"query": query}
        response = requests.get(f"http://{gatekeeper_dns}:8080/custom", json=payload)
        return response
    except Exception as ex:
        print(f"Failed to select random data from database : {ex}")
        raise SystemExit(ex)


"""
Drop databse/table through the gatekeeper
:param query: SQL select query
:return: databse/table dropped
"""
def delete(query):
    try:
        payload = {"query": query}
        response = requests.delete(f"http://{gatekeeper_dns}:8080/delete", json=payload)
        return response
    except Exception as ex:
        print(f"Failed to delete databse : {ex}")
        raise SystemExit(ex)


"""
Call a bench of scenarios to insert/select/delete using direct/random/custom calls
:return: print queries outputs
"""
def main():
    insert_query = (
        """INSERT INTO actor (first_name, last_name) VALUES ('Tom','Cruise');"""
    )
    select_actor_query = (
        "SELECT * FROM actor where first_name = 'Tom' and last_name= 'Cruise';"
    )
    select_customer_query = "select * from cutomer;"
    delete_query = "DROP TABLE actor;"

    print("\nSearch for actor Tom cruise using direct call")
    print(json.loads(select_direct_data(select_actor_query).content))

    print("\nAdd Tom Cruise into actor table")
    print(json.loads(insert_data(insert_query).content))

    print("\nSearch for actor Tom cruise using direct call")
    print(json.loads(select_direct_data(select_actor_query).content))

    print("\nSearch for actor Tom cruise using random call")
    print(json.loads(select_random_data(select_actor_query).content))

    print("\nSearch for actor Tom cruise using custom call")
    print(json.loads(select_custom_data(select_actor_query).content))

    print("\nSearch for all customers data")
    print(json.loads(select_direct_data(select_customer_query).content))

    print("\nDelete actor table")
    print(json.loads(delete(delete_query).content))
    print("\n")


## Main function
main()
