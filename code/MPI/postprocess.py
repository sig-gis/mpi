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

# %% regional MPI based on Cambodia DHS 2014
mpi_dic = {}
for i in range(1,20):
    df = pd.read_stata(datafd_path / 'dta' / f'khm_dhs14_mpi_rgn{i}.dta')
    mpi = df.MPI_1[0]
    mpi_dic[i] = mpi
    
mpi_df = pd.DataFrame(mpi_dic.items(), columns=['region_code', 'mpi'])
# mpi_df.to_csv(outfd_path / 'mpi_khm_dhs14_rgn.csv', index=False)


# %% cluster-level MPI based on Cambodia DHS 2014
spatial_res = 'clust'
mpi_ci_df = pd.DataFrame()
for i in range(1,611+1):
    df = pd.read_stata(
        datafd_path / 'dta' / f'khm_dhs14_mpi_{spatial_res}{i}.dta')
    row_df = df.loc[[0], ['psu', 'MPI_1_svy', 'MPI_1_SE', \
                          'MPI_1_low95CI', 'MPI_1_upp95CI']]
    row_df['tot_samp_ppl'] = df.shape[0]
    row_df['ppt_samp_ppl_mis'] = (1 - df.per_sample_1[0]) * 100
    mpi_ci_df = pd.concat([mpi_ci_df, row_df])

old_colnames = ['psu', 'MPI_1_svy', 'MPI_1_SE', \
                'MPI_1_low95CI', 'MPI_1_upp95CI']
new_colnames = ['clust_no', 'mpi', 'mpi_SE', 'mpi_lo95CI', 'mpi_up95CI']
mpi_ci_df.rename(columns=dict(zip(old_colnames, new_colnames)), inplace=True)
# mpi_ci_df.to_csv(outfd_path / 'mpi_khm_dhs14_clust_CI_mis.csv', index=False)

