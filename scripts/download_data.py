from huggingface_hub import snapshot_download
import pandas as pd

# download  the dataset from Hugging Face Hub
snapshot_download(
    repo_id="HanzhouLiu/FloodSQL-Bench",
    local_dir="data",
    repo_type="dataset"
)

six_metro = pd.read_csv("six_metro_counties.csv")
six_metro.to_parquet("data/data/six_metro.parquet")