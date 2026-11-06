'''
Creates a benchmark .json file from canonical SQL prompts and natural language prompts.
'''

from pathlib import Path
import pandas as pd
import json
import argparse
import duckdb

# Constants

# - Filepaths

# - - Canonical policy query directory
query_dir = Path('scripts/canonical/policies')
# - - Metropolitan area data file
metro_data_path = Path('six_metro_counties.csv')
# - - Benchmark data file
benchmark_data_path = Path('outputs/benchmark.parquet')
# - - Output filepath
out_path = Path('benchmark/benchmark.jsonl')
# - - Prompt file
prompt_path = Path('prompts.txt')

# - Canonical policy evidence dimensions
policy_evidence_map = {
    'P1': ['H'],
    'P2': ['E'],
    'P3': ['E', 'V'],
    'P4': ['L'],
    'P5': ['H', 'F'],
    'P6': ['H', 'E', 'L', 'V', 'F']
}

def get_scores(benchmark, episode):
    return benchmark.loc[
        benchmark['episode']==episode,
        ['GEOID', 'score', 'score_rank']
    ].set_index('GEOID')

def main():
    parser = argparse.ArgumentParser(description='Create benchmark json from prompts.')
    
    # Read in metro area data
    metro_areas = pd.read_csv(metro_data_path)
    metro_ids = metro_areas[['metro_id', 'cbsa_title']].drop_duplicates()
    metro_ids = metro_ids.set_index('metro_id')
    
    # Read in benchmark data
    benchmark = pd.read_parquet(benchmark_data_path)
    
    # Read prompts
    with open(prompt_path, 'r', encoding='utf-8') as prompt_file:
        prompts = prompt_file.readlines()
        
    # Write data out
    with open(out_path, 'w', encoding='utf-8') as out:
        policy = 'P1'
        for prompt in prompts:
            prompt = prompt.strip()
            if len(prompt) == 0:
                continue
            if prompt[0] == '#':
                policy = prompt[1:]
                continue
            
            idx, level, prompts = prompt.split('::')
            prompt, paraphrase_prompt = prompts.split('|')
            for metro_id in metro_ids.index:
                episode_id = f'{metro_id}_{policy}'
                # print(metro_ids)
                cbsa_title = metro_ids.loc[metro_id, 'cbsa_title']
                final_prompt = prompt.replace('<METRO_AREA>', f'the {cbsa_title} area')
                final_paraphrase_prompt = paraphrase_prompt.replace('<METRO_AREA>', f'the {cbsa_title} area')
                policy_scores = get_scores(benchmark, episode_id)
                
                episode = {
                    'episode_id': episode_id,
                    'metro_id': metro_id,
                    'cbsa_title': cbsa_title,
                    'policy_id': policy,
                    'canonical_prompt':final_prompt,
                    'paraphrase_prompt': final_paraphrase_prompt,
                    'level': level,
                    'candidate_unit': 'census_tract',
                    'gold_evidence': policy_evidence_map[policy],
                    'eligible_geoids': list(policy_scores.index),
                    'gold_score_by_geoid': dict(zip(
                        policy_scores.index,
                        policy_scores['score']
                        )),
                    'gold_ranking': dict(zip(
                        policy_scores.index,
                        policy_scores['score_rank']
                        )),
                    'benchmark_version': '1.0',
                    'data_version': '1.0'
                }
                out.write(json.dumps(episode) + '\n')
    return

if __name__ == '__main__':
    main()