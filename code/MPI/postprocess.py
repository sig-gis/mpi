# -*- coding: utf-8 -*-
"""
Created on Wed Nov  9 16:01:01 2022

@author: tianc
"""

from pathlib import Path
import pandas as pd
import geopandas as gpd
import numpy as np

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
mpi_info_df = pd.DataFrame()
for i in range(1,611+1):
    df = pd.read_stata(
        datafd_path / 'dta' / f'khm_dhs14_mpi_{spatial_res}{i}.dta')
    row_df = df.loc[[0], ['psu', 'MPI_1_svy', 'MPI_1_SE', \
                          'MPI_1_low95CI', 'MPI_1_upp95CI']]
    row_df['tot_samp_ppl'] = df.shape[0]
    row_df['pct_samp_ppl_mis'] = (1 - df.per_sample_1[0]) * 100
    mpi_info_df = pd.concat([mpi_info_df, row_df])

old_colnames = ['psu', 'MPI_1_svy', 'MPI_1_SE', \
                'MPI_1_low95CI', 'MPI_1_upp95CI']
new_colnames = ['clust_no', 'mpi', 'mpi_SE', 'mpi_lo95CI', 'mpi_up95CI']
mpi_info_df.rename(columns=dict(zip(old_colnames, new_colnames)), inplace=True)
# mpi_info_df.to_csv(outfd_path / 'mpi_khm_dhs14_clust_CI_mis.csv', index=False)

# %%% join the above df to cluster shapefile
# cluster shapefile
shp_path = datafd_path.parent/'DHS'/'Cambodia'/'geog'/'KHGE71FL'
gdf = gpd.read_file(shp_path)
# attribute join
mpi_info_gdf = gdf.merge(mpi_info_df, left_on='DHSCLUST', right_on='clust_no')
# export
mpi_info_gdf.rename(columns={'tot_samp_ppl': 'tot_ppl',
                             'pct_samp_ppl_mis': 'pct_pplmis'}, inplace=True)
# mpi_info_gdf.to_file(outfd_path/'mpi_khm_dhs14_clust_CI_mis')


# %% MPI
# utils


def mpi_info_to_csv(survey, spatial_res, n_spatial_unit):
    '''Returns df with MPI estimated from SURVEY at SPATIAL_RES level, along
    with uncertainty and missingness info; writes df to csv.'''
    
    mpi_info_df = pd.DataFrame()
    for i in range(1,n_spatial_unit+1):
        df = pd.read_stata(
            datafd_path / survey / f'{"_".join(survey.split("_")[:2])}_mpi_{spatial_res}{i}.dta'
            )  # delete _cot in khm_dhs14_cot
        row_df = df.loc[
            [0], 
            ['psu', 'MPI_1_svy', 'MPI_1_SE', 'MPI_1_low95CI', 'MPI_1_upp95CI']
            ]
        row_df['tot_samp_ppl'] = df.shape[0]
        row_df['pct_samp_ppl_mis'] = (1 - df.per_sample_1[0]) * 100
        mpi_info_df = pd.concat([mpi_info_df, row_df])
    
    old_colnames = ['psu', 'MPI_1_svy', 'MPI_1_SE', \
                    'MPI_1_low95CI', 'MPI_1_upp95CI']
    new_colnames = ['clust_no', 'mpi', 'mpi_SE', 'mpi_lo95CI', 'mpi_up95CI']
    mpi_info_df.rename(
        columns=dict(zip(old_colnames, new_colnames)), inplace=True
        )
    mpi_info_df.to_csv(outfd_path / f'mpi_{survey}_{spatial_res}_CI_mis.csv', 
                       index=False)
    return mpi_info_df


# %%% cluster-level MPI based on Cambodia DHS 2010
survey = 'khm_dhs10'
spatial_res = 'clust'
n_spatial_unit = 611
mpi_info_df = mpi_info_to_csv(survey, spatial_res, n_spatial_unit)

# %%% join the above df to cluster shapefile
# cluster shapefile
shp_path = datafd_path.parent/'DHS'/'Cambodia'/'geog'/'KHGE62FL'
gdf = gpd.read_file(shp_path)
# sanity check before joining
gdf.columns
(np.sort(gdf.DHSCLUST.unique()) == np.arange(1, n_spatial_unit+1)).all()
mpi_info_df.shape
gdf.shape
# attribute join
mpi_info_gdf = gdf.merge(mpi_info_df, left_on='DHSCLUST', right_on='clust_no')
# sanity check after joining
mpi_info_gdf.shape
# export
mpi_info_gdf.rename(columns={'tot_samp_ppl': 'tot_ppl',
                             'pct_samp_ppl_mis': 'pct_pplmis'}, inplace=True)
# mpi_info_gdf.to_file(outfd_path/f'mpi_{survey}_clust_CI_mis')


# %%% harmonized cluster-level MPI based on Cambodia DHS 2014
survey = 'khm_dhs14_cot'
spatial_res = 'clust'
n_spatial_unit = 611
mpi_info_df = mpi_info_to_csv(survey, spatial_res, n_spatial_unit)

# %%%% join the above df to cluster shapefile
# cluster shapefile
shp_path = datafd_path.parent/'DHS'/'Cambodia'/'geog'/'KHGE71FL'
gdf = gpd.read_file(shp_path)
# sanity check before joining
gdf.columns
(np.sort(gdf.DHSCLUST.unique()) == np.arange(1, n_spatial_unit+1)).all()
mpi_info_df.shape
gdf.shape
# attribute join
mpi_info_gdf = gdf.merge(mpi_info_df, left_on='DHSCLUST', right_on='clust_no')
# sanity check after joining
mpi_info_gdf.shape
# export
mpi_info_gdf.rename(columns={'tot_samp_ppl': 'tot_ppl',
                             'pct_samp_ppl_mis': 'pct_pplmis'}, inplace=True)
# mpi_info_gdf.to_file(outfd_path/f'mpi_{survey}_clust_CI_mis')


# %%% harmonized cluster-level MPI based on Cambodia DHS 2010
survey = 'khm_dhs10_cot'
spatial_res = 'clust'
n_spatial_unit = 611
mpi_info_df = mpi_info_to_csv(survey, spatial_res, n_spatial_unit)

# %%%% join the above df to cluster shapefile
# cluster shapefile
shp_path = datafd_path.parent/'DHS'/'Cambodia'/'geog'/'KHGE62FL'
gdf = gpd.read_file(shp_path)
# sanity check before joining
gdf.columns
(np.sort(gdf.DHSCLUST.unique()) == np.arange(1, n_spatial_unit+1)).all()
mpi_info_df.shape
gdf.shape
# attribute join
mpi_info_gdf = gdf.merge(mpi_info_df, left_on='DHSCLUST', right_on='clust_no')
# sanity check after joining
mpi_info_gdf.shape
# export
mpi_info_gdf.rename(columns={'tot_samp_ppl': 'tot_ppl',
                             'pct_samp_ppl_mis': 'pct_pplmis'}, inplace=True)
# mpi_info_gdf.to_file(outfd_path/f'mpi_{survey}_clust_CI_mis')


# %%% harmonized cluster-level MPI based on Cambodia DHS 2005
survey = 'khm_dhs05_cot'
spatial_res = 'clust'
n_spatial_unit = 557
mpi_info_df = mpi_info_to_csv(survey, spatial_res, n_spatial_unit)

# %%%% join the above df to cluster shapefile
# cluster shapefile
shp_path = datafd_path.parent/'DHS'/'Cambodia'/'geog'/'KHGE51FL'
gdf = gpd.read_file(shp_path)
# sanity check before joining
gdf.columns
(np.sort(gdf.DHSCLUST.unique()) == np.arange(1, n_spatial_unit+1)).all()
mpi_info_df.shape
gdf.shape
# attribute join
mpi_info_gdf = gdf.merge(mpi_info_df, left_on='DHSCLUST', right_on='clust_no')
# sanity check after joining
mpi_info_gdf.shape
# export
mpi_info_gdf.rename(columns={'tot_samp_ppl': 'tot_ppl',
                             'pct_samp_ppl_mis': 'pct_pplmis'}, inplace=True)
# mpi_info_gdf.to_file(outfd_path/f'mpi_{survey}_clust_CI_mis')
