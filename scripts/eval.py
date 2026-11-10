import duckdb
import pandas as pd
import numpy as np
import json
from scipy.stats import kendalltau
import argparse
from pathlib import Path

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
parser.add_argument(
    "--data_dir",
    type=str,
    default="data/data",
    help="Path to directory with FloodSQL-Bench data as parquet files",
)

parser.add_argument("--output_csv", type=str, default="results/Qwen3-8B_eval.csv")
parser.add_argument("--limit", type=int, default=np.inf, help="Only process the first N benchmark items")
args = parser.parse_args()

# =========================================================
# CONFIG
# =========================================================
INPUT_DIR = args.input      # Path to input JSONL file
OUTPUT_DIR = args.output_csv
BENCHMARK_FILE = args.benchmark  # Path to ground truth benchmark

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
    """Calculate the kendall's tau statistic for policy scores of tracts existing in both dataframes.

    Args:
        a, b (pd.Dataframe): dataframe with at least two columns: GEOID and score

    Returns:
        float: kendall's tau
    """
    results_by_geoid = a.merge(b, on='GEOID', how='inner', suffixes=["_a", "_b"])
    res = kendalltau(
        results_by_geoid['score_a'],
        results_by_geoid['score_b']
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
    data_files = Path(args.data_dir).glob("*.parquet")
    for file in data_files:
        table_name = file.stem.lower().replace("_tx_fl_la", "")
        data_table = duckdb.read_parquet(file).df()
        duckdb.execute("CREATE OR REPLACE TABLE %s AS SELECT * FROM data_table" % table_name)
    duckdb.execute("INSTALL spatial")
    duckdb.execute("LOAD spatial")
    print(duckdb.sql("SHOW TABLES"))

# =========================================================
# MAIN EVALUATION PIPELINE
# =========================================================

def main():
    # Set up database
    print("Creating DuckDB database...")
    setup_db()
    
    # load queries and benchmark
    print("Loading queries & benchmark...")
    gen_episodes = []
    with open(INPUT_DIR, "r", encoding="utf-8") as f:
        for line in f:
            gen_episodes.append(json.loads(line))
    gen_episodes = sorted(gen_episodes, key=lambda item: item['item_id'])
    
    bench_episodes = []
    with open(BENCHMARK_FILE, "r", encoding="utf-8") as f:
        for line in f:
            bench_episodes.append(json.loads(line))
    bench_episodes = sorted(bench_episodes, key=lambda item: item['item_id'])
    
    n = min(len(gen_episodes), len(bench_episodes), args.limit)
    
    results = []
    for i, gen_ep, bench_ep in zip(range(n), gen_episodes[:n], bench_episodes[:n]):
        item_id = gen_ep['item_id']
        level = gen_ep['level']
        for para in ['canonical_prompt', 'paraphrase_prompt']:
            # retrieve basic info, NL prompt, generated SQL query
            suff = "_og" if para == "canonical_prompt" else "_pp"
            ep = gen_ep[para]
            query = ep['generated_sql']
            
            result = {
                'pid' : item_id + suff,
                'item_id': item_id,
                'canon': para=="canonical_prompt",
                'prompt': bench_ep[para],
                'query': query,
                'level': level,
            }
            
            # Attempt to run SQL: if error, save error type
            try:
                print("\n[%s] Running query %d of %d:\n%s" 
                  % (item_id, i+1, n, query))
                
                sql_result = run_sql(query)
                gold = pd.DataFrame({
                    'GEOID': bench_ep['eligible_geoids'],
                    'score': [bench_ep['gold_score_by_geoid'][geoid] 
                              for geoid in bench_ep['eligible_geoids']],
                    'score_rank': [bench_ep['gold_ranking'][geoid] 
                                   for geoid in bench_ep['eligible_geoids']],
                })
                result.update({
                    'error' : "None",
                    'kendall_tau' : kendall_tau(sql_result, gold),
                    'top10_jaccard' : top_k_jaccard(sql_result, gold, k=10),
                    'top20_jaccard' : top_k_jaccard(sql_result, gold, k=20),
                    'top20pct_overlap' : top_pct_overlap(sql_result, gold, p=20),
                    'top40pct_overlap' : top_pct_overlap(sql_result, gold, p=40),
                })
            except Exception as e:
                print(type(e), e)
                result.update({
                    'error' : type(e)
                })
                pass
            results.append(
                result
            )
    pd.DataFrame(results).to_csv(OUTPUT_DIR, index=False)
    
if __name__ == "__main__":
    main()