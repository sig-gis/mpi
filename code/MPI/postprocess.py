# -*- coding: utf-8 -*-
"""
Created on Wed Nov  9 16:01:01 2022

@author: tianc
"""

from pathlib import Path
import pandas as pd

# code_path = Path(__file__)
code_path = Path(r'C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI')
datafd_path = code_path.parent.parent / 'data' / 'MPI' 
outfd_path = code_path.parent.parent / 'output' / 'data' 

# regional MPI based on Cambodia DHS 2014
mpi_dic = {}
for i in range(1,20):
    df = pd.read_stata(datafd_path / 'dta' / f'khm_dhs14_mpi_rgn{i}.dta')
    mpi = df.MPI_1[0]
    mpi_dic[i] = mpi
    
mpi_df = pd.DataFrame(mpi_dic.items(), columns=['region_code', 'mpi'])
# mpi_df.to_csv(outfd_path / 'mpi_khm_dhs14_rgn.csv', index=False)
