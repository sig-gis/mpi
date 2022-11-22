# -*- coding: utf-8 -*-
"""
Created on Tue Nov 22 14:05:09 2022

@author: tianc
"""

from pathlib import Path
import pandas as pd
import numpy as np

# code_path = Path(__file__)
code_path = Path(r'C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI')
datafd_path = code_path.parent.parent / 'data' / 'MPI' 
outfd_path = code_path.parent.parent / 'output' / 'data' 


# %%khm dhs14 

# %%% create cluster numbers from ind_id
df = pd.read_stata(datafd_path / 'dta' / 'khm_dhs14.dta')
np.unique(df.ind_id // 1000000)

# %%% compare microdata without and with cluster numbers 
df1 = pd.read_stata(datafd_path / 'dta' / 'khm_dhs14.dta')
df2 = pd.read_stata(datafd_path / 'dta' / 'khm_dhs14_clustno.dta')
df2.iloc[:, :-1].equals(df1)
