import duckdb
import pandas as pd
import json
from scipy.stats import kendalltau
import argparse

# ------------------------------
# Parse command line arguments
# ------------------------------
parser = argparse.ArgumentParser(description="Evaluate results of RAG SQL generation against ground truth")

parser.add_argument(
    "--input",
    type=str,
    default="results/Qwen3-8B.jsonl",
    help="Path to jsonl of generated SQL queries",
)
parser.add_argument(
    "--benchmark",
    type=str,
    default="benchmark/benchmark.jsonl",
    help="Path to jsonl of ground truth benchmark",
)
parser.add_argument("--output_csv", type=str, default="results/Qwen3-8B_eval.csv")
parser.add_argument("--limit", type=int, default=np.inf, help="Only process the first N benchmark items")
args = parser.parse_args()

# =========================================================
# CONFIG
# =========================================================
INPUT_DIR = args.input      # Path to input JSONL file
BENCHMARK = args.benchmark  # Path to groun truth benchmark

JACCARD_TOP_K = 10          # top-k items used for jaccard index (IOU) metric
OVERLAP_TOP_P = 20          # top-p percent of items used for overlap metric

# =========================================================
# HELPERS
# =========================================================
def cosine(a, b):
    denom = (np.linalg.norm(a) * np.linalg.norm(b) + 1e-10)
    return float(np.dot(a, b) / denom)


def batch_embed(texts, model_name, max_retry=3):
    """Batch embedding with retry"""
    for attempt in range(max_retry):
        try:
            r = embedding(model=model_name, input=texts)
            return [np.array(x["embedding"]) for x in r["data"]]
        except Exception as e:
            if attempt == max_retry - 1:
                raise e
            time.sleep(1.2)  # wait then retry
            
def top_k_jaccard(a, b, k=10):
    """Calculates the IOU of the top k items in a and b.
    Null-scored items are ignored.

    Args:
        a, b (pd.Dataframe): dataframe with at least two columns: GEOID and score_rank
        k (int): top-k to compare
    
    Returns:
        float: IOU for top-k items
    """
    a_top_k = set(a.loc[a['score_rank'] <= k, 'GEOID'])
    b_top_k = set(b.loc[b['score_rank'] <= k, 'GEOID'])
    return len(a_top_k & b_top_k) / len(a_top_k | b_top_k)

def kendall_tau(a, b):
    """Calculate the kendall's tau statistic for two dataframes.

    Args:
        a, b (pd.Dataframe): dataframe with at least one column: score

    Returns:
        float: kendall's tau
    """
    res =  kendalltau(
        a['score'],
        b['score']
    )
    return res.statistic

def top_pct_overlap(a, b, p=20.0):
    """Calculate the overlap of the top p percent items in a and b.
    Null-scored items are ignored.

    Args:
        a, b (pd.Dataframe): dataframe with at least two columns: GEOID and score_rank
        p (float, optional): top p percent. Defaults to 20.0

    Returns:
        float: intersection(top p% of a, top p% of b) / min(size of a, size of b)
    """
    n = min(a['score'].notna().sum(), b['score'].notna().sum())
    k_a = int(a['score'].notna().sum() * (p / 100))
    k_b = int(b['score'].notna().sum() * (p / 100))
    a_top_k = set(a.loc[a['score_rank'] <= k_a, 'GEOID'])
    b_top_k = set(b.loc[b['score_rank'] <= k_b, 'GEOID'])
    return len(a_top_k & b_top_k) / n

def run_sql(sql):
    res = duckdb.sql(sql)
    df = res.df()
    return df

def setup_db():
    # TODO: sets up the duckdb db with all the necessary FloodSQL-Bench data
    pass

# =========================================================
# MAIN EVALUATION PIPELINE
# =========================================================

def main():
    
    # load queries and benchmark
    sql_queries = []
    with open(INPUT_DIR, "r", encoding="utf-8") as f:
        for line in f:
            sql_queries.append(json.loads(line))
    sql_queries = sorted(sql_queries, key=lambda item: item['item_id'])
    
    benchmark = []
    with open(BENCHMARK, "r", encoding="utf-8") as f:
        for line in f:
            benchmark.append(json.loads(line))
    benchmark = sorted(benchmark, key=lambda item: item['item_id'])
    
    n = min(len(sql_queries), len(benchmark), args.limit)
    
    results = []
    for query, bench_item in zip(sql_queries[:n], benchmark[:n]):
        try:
            sql_result = run_sql()
        except Exception as e:
            
        results.append({
            
        })
    
    
if __name__ == "__main__":
    main()