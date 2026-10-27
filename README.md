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
3. Clone the FloodSQL submodule with:
```
git submodule update --init
```
4. Download the FloodSQL data with:
```
python FloodSQL-Bench/download_hf.py
```
5. You should be set up to run the SQL script with duckdb. This will start an interactive session as well as populate `outputs` with the week 1 deliverables.
```
duckdb -init scripts/DGSQL.sql
```