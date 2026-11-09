import os
import re
import json
import argparse

import numpy as np
import torch
from transformers import AutoModel, AutoModelForCausalLM, AutoTokenizer

# ------------------------------
# Parse command line arguments
# ------------------------------
parser = argparse.ArgumentParser(description="Run RAG SQL benchmark with local HF models")

parser.add_argument(
    "--model",
    type=str,
    default="Qwen/Qwen3-8B",
    help="HF hub id or local path of the causal LLM used to generate SQL",
)
parser.add_argument(
    "--embed_model",
    type=str,
    default="BAAI/bge-large-en-v1.5",
    help="HF hub id or local path of the embedding model used for RAG retrieval",
)
parser.add_argument(
    "--pooling",
    type=str,
    default="auto",
    choices=["auto", "cls", "mean", "last"],
    help="Pooling for the embedding model. 'auto' picks last-token for Qwen3-Embedding "
         "style models, CLS for bge, and mean otherwise.",
)
parser.add_argument(
    "--query_prefix",
    type=str,
    default="",
    help="Optional instruction prefix prepended to questions only "
         "(e.g. 'Represent this sentence for searching relevant passages: ' for bge).",
)
parser.add_argument("--output_jsonl", type=str, default="results/Qwen3-8B.jsonl")
parser.add_argument("--max_new_tokens", type=int, default=512)
parser.add_argument("--embed_max_length", type=int, default=512)
parser.add_argument("--embed_batch_size", type=int, default=32)
parser.add_argument("--dtype", type=str, default="auto", choices=["auto", "bfloat16", "float16", "float32"])
parser.add_argument("--trust_remote_code", action="store_true")
parser.add_argument("--limit", type=int, default=None, help="Only process the first N benchmark items")

args = parser.parse_args()

# =========================================================
# CONFIG
# =========================================================
INPUT_JSON = "benchmark/benchmark.jsonl"
OUTPUT_JSONL = args.output_jsonl

DATA_DIR = "FloodSQL-Bench/data"
METADATA_PATH = os.path.join(DATA_DIR, "metadata_parquet.json")

MODEL_NAME = args.model
EMBED_MODEL = args.embed_model

TOP_K = 3  # top-k used for table retrieval RAG
TOP_COLS = 5  # top columns kept per retrieved table

DEVICE = ("cuda" if torch.cuda.is_available()
          else "mps" if torch.backends.mps.is_available()
          else "cpu")

TORCH_DTYPE = "auto" if args.dtype == "auto" else getattr(torch, args.dtype)

SYSTEM_PROMPT = """
You are an expert DuckDB SQL generator for the FloodSQL_Bench dataset.
You are aiding a disaster responder who is trying to prioritize the distribution of limited resources to areas that need them most.
Your task is to generate a query that will produce a priority ranking of census tracts by GEOID based on the prompt given.
Use only the tables and columns given in the metadata context.
Do NOT output any reasoning, explanation, or analysis.
Output only the final SQL query, with no comments and no semicolon.
Your output must contain SQL code only.
Any natural language or reasoning is strictly forbidden.
"""

# =========================================================
# EMBEDDING MODEL (transformers)
# =========================================================
class Embedder:
    """Wraps a HF encoder to produce L2-normalised sentence embeddings."""

    def __init__(self, name, pooling="auto", max_length=512, batch_size=32, trust_remote_code=False):
        self.tokenizer = AutoTokenizer.from_pretrained(name, trust_remote_code=trust_remote_code)
        self.model = AutoModel.from_pretrained(
            name, torch_dtype=TORCH_DTYPE, trust_remote_code=trust_remote_code
        ).to(DEVICE).eval()
        self.max_length = max_length
        self.batch_size = batch_size

        if pooling == "auto":
            lname = name.lower()
            if "qwen3-embedding" in lname:
                pooling = "last"
            elif "bge" in lname:
                pooling = "cls"
            else:
                pooling = "mean"
        self.pooling = pooling

        # last-token pooling is simplest with left padding
        if self.pooling == "last":
            self.tokenizer.padding_side = "left"

        print(f"[Embedder] {name} | pooling={self.pooling} | device={DEVICE}")

    def _pool(self, hidden, mask):
        if self.pooling == "cls":
            return hidden[:, 0]
        if self.pooling == "last":
            if bool(mask[:, -1].all()):  # left padded
                return hidden[:, -1]
            idx = mask.sum(dim=1) - 1
            return hidden[torch.arange(hidden.size(0), device=hidden.device), idx]
        # mean
        m = mask.unsqueeze(-1).to(hidden.dtype)
        return (hidden * m).sum(dim=1) / m.sum(dim=1).clamp(min=1e-9)

    @torch.no_grad()
    def encode(self, texts):
        if isinstance(texts, str):
            texts = [texts]
        out = []
        for i in range(0, len(texts), self.batch_size):
            batch = texts[i:i + self.batch_size]
            enc = self.tokenizer(
                batch,
                padding=True,
                truncation=True,
                max_length=self.max_length,
                return_tensors="pt",
            ).to(DEVICE)
            hidden = self.model(**enc).last_hidden_state
            emb = self._pool(hidden, enc["attention_mask"]).float()
            emb = torch.nn.functional.normalize(emb, p=2, dim=-1)
            out.append(emb.cpu().numpy())
        return np.concatenate(out, axis=0)


# =========================================================
# LLM (transformers)
# =========================================================
class SQLGenerator:
    def __init__(self, name, max_new_tokens=512, trust_remote_code=False):
        self.tokenizer = AutoTokenizer.from_pretrained(name, trust_remote_code=trust_remote_code)
        if self.tokenizer.pad_token is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token
        self.model = AutoModelForCausalLM.from_pretrained(
            name,
            torch_dtype=TORCH_DTYPE,
            device_map="auto",
            trust_remote_code=trust_remote_code,
        ).eval()
        self.max_new_tokens = max_new_tokens
        print(f"[LLM] {name} loaded")

    def _render(self, system_text, user_text):
        """Apply the model's chat template. Falls back to folding the system prompt
        into the user turn for templates that do not support a system role."""
        kwargs = dict(tokenize=False, add_generation_prompt=True)
        try:
            # enable_thinking is ignored by templates that do not use it (Qwen3 uses it)
            return self.tokenizer.apply_chat_template(
                [{"role": "system", "content": system_text},
                 {"role": "user", "content": user_text}],
                enable_thinking=False,
                **kwargs,
            )
        except Exception:
            return self.tokenizer.apply_chat_template(
                [{"role": "user", "content": system_text + "\n\n" + user_text}],
                enable_thinking=False,
                **kwargs,
            )

    @torch.no_grad()
    def generate(self, system_text, user_text):
        text = self._render(system_text, user_text)
        inputs = self.tokenizer(text, return_tensors="pt", add_special_tokens=False).to(self.model.device)
        out = self.model.generate(
            **inputs,
            max_new_tokens=self.max_new_tokens,
            do_sample=False,  # greedy, equivalent to temperature=0
            pad_token_id=self.tokenizer.pad_token_id,
        )
        new_tokens = out[0, inputs["input_ids"].shape[1]:]
        return self.tokenizer.decode(new_tokens, skip_special_tokens=True)


# =========================================================
# HELPERS
# =========================================================
def clean_sql(sql: str):
    """Remove reasoning blocks and Markdown SQL fences"""
    sql = re.sub(r"<think>.*?</think>", "", sql, flags=re.DOTALL)
    return sql.strip().replace("```sql", "").replace("```", "").strip()


def flatten_sql(sql: str) -> str:
    """Flatten SQL to one line for consistency"""
    return " ".join(sql.split())


# =========================================================
# LOAD METADATA
# =========================================================
def load_metadata(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


# =========================================================
# BUILD TABLE + COLUMN DESCRIPTION CORPUS
# =========================================================
def build_table_index(meta):
    """Build a text description for each table for embedding retrieval."""
    table_texts = {}

    for table, info in meta.items():
        if table == "_global":
            continue

        desc_parts = [table]
        for col in info.get("schema", []):
            cname = col.get("column_name", "")
            cdesc = col.get("description", "")
            desc_parts.append(f"{cname}: {cdesc}")

        table_texts[table] = "\n".join(desc_parts)

    return table_texts


def build_column_index(meta):
    """
    Build column-level description index for fine-grained RAG.
    Returns: col_index[table] = [(column_name, description_text)]
    """
    col_index = {}

    for table, info in meta.items():
        if table == "_global":
            continue

        items = []
        for col in info.get("schema", []):
            cname = col.get("column_name", "")
            cdesc = col.get("description", "")
            items.append((cname, f"{cname}: {cdesc}"))

        col_index[table] = items

    return col_index


# =========================================================
# PRECOMPUTE EMBEDDINGS (once, instead of once per question)
# =========================================================
def embed_indices(embedder, table_index, col_index):
    table_names = list(table_index.keys())
    table_embs = embedder.encode([table_index[t] for t in table_names])

    col_embs = {}
    for table, items in col_index.items():
        if items:
            col_embs[table] = embedder.encode([text for _, text in items])
        else:
            col_embs[table] = np.zeros((0, table_embs.shape[1]))

    return table_names, table_embs, col_embs


# =========================================================
# RAG: TABLE RETRIEVAL (TOP_K)
# =========================================================
def retrieve_tables(q_emb, table_names, table_embs, top_k):
    sims = table_embs @ q_emb  # embeddings are L2-normalised -> cosine
    order = np.argsort(-sims)[:top_k]
    scores = [(table_names[i], float(sims[i])) for i in order]
    top_tables = [t for t, _ in scores]
    return top_tables, scores


# =========================================================
# RAG: COLUMN RETRIEVAL (TOP N PER TABLE)
# =========================================================
def retrieve_columns(q_emb, col_index, col_embs, chosen_tables, top_n=TOP_COLS):
    result = {}

    for table in chosen_tables:
        items = col_index[table]
        if not items:
            result[table] = []
            continue

        sims = col_embs[table] @ q_emb
        order = np.argsort(-sims)[:top_n]
        result[table] = [(items[i][0], float(sims[i]), items[i][1]) for i in order]

    return result


# =========================================================
# BUILD METADATA PROMPT
# =========================================================
def build_metadata_prompt(meta, chosen_tables, chosen_columns):
    """
    Build the RAG prompt containing:
    - Selected tables
    - Selected columns
    - Global rules
    - Notes
    - Join rules (key-based & spatial)
    """
    lines = []

    lines.append("[TABLES SELECTED]")
    for t in chosen_tables:
        lines.append(f"- {t}")

    lines.append("\n[COLUMNS SELECTED]")
    for t, cols in chosen_columns.items():
        for cname, score, cdesc in cols:
            lines.append(f"- {t}.{cname}: {cdesc}")

    jr = meta["_global"].get("join_rules", {})

    direct_pairs = jr.get("key_based", {}).get("direct", [])
    lines.append("\n[JOIN RULES: KEY-BASED DIRECT]")
    for it in direct_pairs:
        p = it.get("pair", [])
        if len(p) == 2:
            lines.append(f"- {p[0]}  <->  {p[1]}")

    concat_pairs = jr.get("key_based", {}).get("concat", [])
    lines.append("\n[JOIN RULES: KEY-BASED CONCAT]")
    for it in concat_pairs:
        p = it.get("pair", [])
        if len(p) == 2:
            lines.append(f"- {p[0]}  <->  {p[1]}")

    ppairs = jr.get("spatial", {}).get("point_polygon", [])
    lines.append("\n[JOIN RULES: SPATIAL POINT-POLYGON]")
    for it in ppairs:
        p = it.get("pair", [])
        if len(p) == 2:
            lines.append(f"- {p[0]}  <->  {p[1]}")

    poly_pairs = jr.get("spatial", {}).get("polygon_polygon", [])
    lines.append("\n[JOIN RULES: SPATIAL POLYGON-POLYGON]")
    for it in poly_pairs:
        p = it.get("pair", [])
        if len(p) == 2:
            lines.append(f"- {p[0]}  <->  {p[1]}")

    rules = meta["_global"].get("rules", {})
    lines.append("\n[RULES]")
    for k, v in rules.items():
        lines.append(f"- {k}: {v}")

    notes = meta["_global"].get("notes", [])
    lines.append("\n[NOTES]")
    for n in notes:
        lines.append(f"- {n}")

    sp = meta["_global"].get("spatial_function_notes", [])
    lines.append("\n[SPATIAL-NOTES]")
    for s in sp:
        lines.append(f"- {s}")

    result = "\n".join(lines)

    if len(result) > 80000:
        result = result[:80000] + "\n...[TRUNCATED]..."
        print("⚠ Metadata prompt truncated to 80000 characters.")

    return result


# =========================================================
# MAIN SQL GENERATION PIPELINE
# =========================================================

def generate_sql_rag_embed():
    meta = load_metadata(METADATA_PATH)
    # 1) indexing + one-time embedding of tables/columns
    table_index = build_table_index(meta)
    col_index = build_column_index(meta)

    embedder = Embedder(
        EMBED_MODEL,
        pooling=args.pooling,
        max_length=args.embed_max_length,
        batch_size=args.embed_batch_size,
        trust_remote_code=args.trust_remote_code,
    )
    table_names, table_embs, col_embs = embed_indices(embedder, table_index, col_index)

    generator = SQLGenerator(
        MODEL_NAME,
        max_new_tokens=args.max_new_tokens,
        trust_remote_code=args.trust_remote_code,
    )

    os.makedirs(os.path.dirname(OUTPUT_JSONL) or ".", exist_ok=True)
    fout = open(OUTPUT_JSONL, "w", encoding="utf-8")

    # 2) load merged benchmark
    benchmark_episodes = []
    with open(INPUT_JSON, "r", encoding="utf-8") as f:
        for line in f:
            benchmark_episodes.append(json.loads(line))
    if args.limit is not None:
        benchmark_episodes = benchmark_episodes[:args.limit]

    # 3) iterate over all prompts
    for item in benchmark_episodes:
        for para in ["canonical_prompt", "paraphrase_prompt"]:
            pid = item["item_id"] + ("_og" if para == "canonical_prompt" else "_pp")
            prompt = item[para]
            
            if prompt == "PLACEHOLDER":
                continue
            
            level = item["level"]

            print(f"\n[{pid}] Processing question:\n{prompt}")

            # STEP 0: embed the question once
            q_emb = embedder.encode(args.query_prefix + prompt)[0]

            # STEP 1: retrieve tables
            chosen_tables, table_scores = retrieve_tables(q_emb, table_names, table_embs, TOP_K)

            # STEP 2: retrieve columns
            chosen_columns = retrieve_columns(q_emb, col_index, col_embs, chosen_tables)

            # STEP 3: build metadata prompt
            metadata_prompt = build_metadata_prompt(meta, chosen_tables, chosen_columns)

            # Many chat templates only allow a single system message, so merge them
            system_text = SYSTEM_PROMPT.strip() + "\n\n" + metadata_prompt
            user_prompt = f"""Question:
{prompt}

Return only a single valid DuckDB SQL query."""

            # STEP 4: LLM
            try:
                raw = generator.generate(system_text, user_prompt)
                sql = flatten_sql(clean_sql(raw))
            except Exception as e:
                print(f"[ERROR] LLM failed on {pid}: {e}")
                raise e
                sql = None

            record = {
                "id": pid,
                "item_id": item["item_id"],
                "question": prompt,
                "level": level,
                "generated_sql": sql,
                "chosen_tables": chosen_tables,
                "chosen_columns": {
                    t: [c for c, _, d in cols] for t, cols in chosen_columns.items()
                },
                "table_scores": table_scores,
            }

            fout.write(json.dumps(record, ensure_ascii=False) + "\n")
            fout.flush()

    fout.close()
    print(f"\n[DONE] Saved SQL to {OUTPUT_JSONL}")


if __name__ == "__main__":
    generate_sql_rag_embed()
