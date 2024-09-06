"""Compile MPI-related outputs, summarize missingness info, save as CSV."""

import pandas as pd
from pathlib import Path

code_path = Path(r'C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI')
outfd_path = code_path.parent.parent / 'output' / 'data'


def mpi_info_to_csv(
        survey, spatial_res, n_spatial_unit, version, datafd_path, outfd_path
    ):
    '''
    Return df with MPI estimated from SURVEY at SPATIAL_RES level, along
    with uncertainty and missingness info. Write df to CSV.
    '''
    
    mpi_info_df = pd.DataFrame()
    for i in range(1, 1000):  # n_spatial_unit + 1):
        try:
            df = pd.read_stata(
                datafd_path / f'{survey}_mpi_{spatial_res}{i}.dta'
            )
            row_df = df.loc[
                [0], 
                ['psu', 'area', 'region', 'MPI_1_svy', 'MPI_1_SE', 'MPI_1_low95CI', 'MPI_1_upp95CI']
            ]
            row_df['tot_samp_ppl'] = df.shape[0]
            row_df['pct_samp_ppl_mis'] = (1 - df.per_sample_1[0]) * 100
            mpi_info_df = pd.concat([mpi_info_df, row_df])
        except:
            break
    assert mpi_info_df.shape[0] == n_spatial_unit

    old_colnames = [
        'psu', 'MPI_1_svy', 'MPI_1_SE', 'MPI_1_low95CI', 'MPI_1_upp95CI'
    ]
    new_colnames = ['clust_no', 'mpi', 'mpi_SE', 'mpi_lo95CI', 'mpi_up95CI']
    mpi_info_df.rename(
        columns=dict(zip(old_colnames, new_colnames)), inplace=True
    )

    mpi_info_df.to_csv(
        outfd_path / f'mpi_{survey}_{version}_{spatial_res}_CI_mis.csv', index=False
    )
    return mpi_info_df


# Cambodia cluster-level MPI harmonized across 00, 05, 10, 14, and 21-22
datafd_path = code_path.parent.parent / 'data' / 'MPI' / 'khm_hmn'
country = 'khm'
spatial_res = 'clust'
version = 'hmn'

for i, year in enumerate(['00', '05', '10', '14', '21-22']):
    survey = f'{country}_dhs{year}'
    n_spatial_unit = [471, 557, 611, 611, 709][i]

    mpi_info_to_csv(
        survey, spatial_res, n_spatial_unit, version, datafd_path, outfd_path
    )