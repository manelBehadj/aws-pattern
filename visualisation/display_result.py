import pandas as pd
import plotly.graph_objects as go
import argparse


parser = argparse.ArgumentParser()
parser.add_argument("standalone_metrics")
parser.add_argument("cluster_metrics")


args = parser.parse_args()
standalone_metrics = args.standalone_metrics
cluster_metrics = args.cluster_metrics


"""
Generate a dataframe
:param rows_list: list of the dataframe rows 
:return: a dataframe that will contain sysbench metrics
"""


def generate_dataframe(rows_list):
    df = pd.DataFrame(rows_list, columns=["name", "latency"])
    return df


"""
Display the comparaison results between standalone and cluster mysql
:param df1: dataframe that contains the results of the standalone instance
:param df: dataframe that contains the results of the cluster
:return: graph diagrams
"""


def compare_result(df1, df2):
    fig = go.Figure()
    fig.add_trace(
        go.Bar(
            x=df1["name"],
            y=df1["latency"],
            name=f"Standalone latency (avg/ms)",
            marker_color="#ffa500",
        )
    )
    fig.add_trace(
        go.Bar(
            x=df2["name"],
            y=df2["latency"],
            name=f"Cluster latency (avg/ms)",
            marker_color="#008000",
        )
    )
    fig.show()


# Main
df1 = generate_dataframe([["Standalone", float(standalone_metrics)]])
df2 = generate_dataframe([["Cluster", float(cluster_metrics)]])
compare_result(df1, df2)
