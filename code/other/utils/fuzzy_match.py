"""Fuzzy matching."""
import numpy as np
import pandas as pd
from fuzzywuzzy import process

def fuzz_match(string, string_pool_lst):
    result, score = process.extractOne(string, string_pool_lst)
    if score < 70:
        result = f'{result} (?)'
    return result


def append_fuzz_match_result(
        row, result_col, string, pool, 
        list_string, list_pool=lambda x: x.split('\n'),
    ):
    string = row[string]
    string_pool = row[pool]
    
    if (not pd.isna(string)) & (not pd.isna(string_pool)): 
        str_lst = list_string(string)
        str_pool_lst = list_pool(string_pool)
        result_lst = [fuzz_match(s, str_pool_lst) for s in str_lst]
        result = ', '.join(result_lst)
        
    else:
        result = np.nan
        
    row[result_col] = result
    return row


def list_Village_na_CBNRM(name):
    name_lst = name.split(',')
    return [na.strip() for na in name_lst]