# DecisionGeoSQL

**Project:** DecisionGeoSQL: Benchmarking Decision-Complete Geospatial Analysis Planning for Disaster Prioritization  
**Purpose:** Finalize the evidence definitions, policy structure, and metropolitan-area benchmark setup so benchmark construction can proceed without another round of feature-selection experiments.

## Setup

1. We will be using [uv](https://docs.astral.sh/uv/) as the package manager for this project and [duckdb](https://duckdb.org/) as our data wrangling tool. Ensure you have both installed by running the following:
```
curl -LsSf https://astral.sh/uv/install.sh | sh
curl https://install.duckdb.org | bash
```
2. Replicate and activate the virtual environment with:
```
uv sync
source .venv/bin/activate
```
3. Download the FloodSQL data and generate a metadata file with:
```
python scripts/download_data.py
python scripts/meta_builder.py
```

## Benchmark creation
1. After running setup steps, you should be set up to run the SQL script with duckdb. This will start an interactive session as well as populate `outputs` with the necessary files for benchmark creation.
```
duckdb -init scripts/DGSQL.sql
```
2. Once the SQL script has completed, you can run the benchmark generation script to save the benchmark into a .jsonl file in `benchmark`.
Update filepaths/constants in the script as needed.
```
python scripts/create_benchmark.py
```

## Running a model on the benchmark
1. Currently, this project only supports running an open-source model uploaded to huggingface. To run the SQL generation pipeline, run:
```
python scripts/run_hf.py --model <hf_model_repo_name> --embed_model <model_for_RAG_embedding> --output_jsonl <output_file_path>
```
The results will be saved to the specified output path.
2. To evaluate the model, run:
```
python scripts/eval.py --input path/to/generated/sql/jsonl --benchmark path/to/ground/truth/benchmark --output_csv <output_file_path>
```