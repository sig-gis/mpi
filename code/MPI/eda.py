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


df = pd.read_stata(datafd_path / 'dta' / 'khm_dhs14.dta')
np.unique(df.ind_id // 1000000)

