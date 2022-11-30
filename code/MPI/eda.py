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

# %%% save mpi dta for cluster 1 as a csv
mpi_df = pd.read_stata(datafd_path / 'dta' / 'khm_dhs14_mpi_clust1.dta')
mpi_df.to_csv(datafd_path / 'dta' / 'khm_dhs14_mpi_clust1.csv', index=False)

# %%% follow along khm_dhs14_cluster.do with mpi dta for cluster 1
df = pd.read_stata(datafd_path / 'dta' / 'khm_dhs14_mpi_clust1.dta')
# *** Raw Headcount Ratios
df.loc[df.sample_1 == 1, :].g01_edu_1.mean() * 100
df.loc[df.sample_1 == 1, :].g01_cm_1.mean() * 100
# individual weighted deprivation count 'c'
# deprivation matrix
depriv_mat = df.loc[:, df.columns.str.startswith('g01_')].iloc[:, :10]
wgt_vec = pd.Series([1/6] * 4 + [1/18] * 6)
wgt_vec.index = depriv_mat.columns
c_vec = depriv_mat @ wgt_vec  # weighted deprivation count 'c'
np.allclose(c_vec[df.sample_1 == 1], df.c_vector_1.dropna())
# mpi poor indicator
poor_s = c_vec > 0.33
poor_s = poor_s[df.sample_1 == 1]
# mpi
mpi = np.mean(poor_s * c_vec[df.sample_1 == 1])
mpi

# %%% explore exclusion of raw data from samples
rawdatafd_path = Path(
    r'C:\Users\tianc\OneDrive\Documents\SIG\DISES\data\DHS\Cambodia\STATA')
df = pd.read_stata(rawdatafd_path / 'KHPR73DT' / 'KHPR73FL.dta')
df.shape
# 74112 rows
df.hv102  # "Permanent (de jure) household member"
sum(df.hv102 == 'no')
# 804 non-usual residents, excluded from sample
df.hv042
# "Households selected as part of nutrition subsample"
df.hv042.value_counts()
sum(df.hv042 == 'not selected') / len(df.hv042)
# 0.3466... not selected, excluded from sample
# 2/3 selected (48427)

micro_df = pd.read_stata(datafd_path / 'dta' / 'khm_dhs14.dta')
micro_df.shape  # 47917

sum((df.hv102 == 'yes') & (df.hv042 == 'selected'))
# 47917!!

# %%% who are in the raw data?
df = pd.read_stata(datafd_path / 'dta' / 'khm_dhs14.dta')  # microdata
df.columns
df1 = df[df.psu == 1]  
# cluster 1, 74 individuals
assert len(df1.ind_id.unique()) == 74
len(df1.hh_id.unique())
# 17 households
df1.groupby('hh_id').count()
# number of individuals in each hh
df1.loc[df1.hh_id == 10023, 'agec4']
# ages of members of hh10023
df.agec4.unique()
# ['18-59', '0-9', '10-17', '60+', NaN] individuals of all ages?
