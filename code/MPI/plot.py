# -*- coding: utf-8 -*-
"""
Created on Wed Nov  9 17:34:29 2022

@author: tianc
"""

from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

# code_path = Path(__file__)
code_path = Path(r'C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI')
datafd_path = code_path.parent.parent / 'data' / 'MPI' 
outfd_path = code_path.parent.parent / 'output'

# %% regional MPI based on Cambodia DHS 2014
rgn_name_df = pd.read_table(datafd_path / 'region_code_name_khm.txt', 
                            delimiter=' ')
mpi_df = pd.read_csv(outfd_path / 'data' / 'mpi_khm_dhs14_rgn.csv')
mpi_rgn_name_df = mpi_df.merge(rgn_name_df, on='region_code')
# %%% bar chart
mpi_rgn_name_df.plot.bar(x='region_name', y='mpi')
plt.savefig(outfd_path / 'figures' / 'mpi_khm_dhs14_rgn.png',
            bbox_inches='tight')
