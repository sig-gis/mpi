"""Join MPI CSV to cluster shapefile and output as shapefile"""

import numpy as np
import pandas as pd
import geopandas as gpd
from pathlib import Path

code_path = Path(r'C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI')
outfd_path = code_path.parent.parent / 'output' / 'data' 


def spatial_join(shp_path, shp_key, csv_path, csv_key, n_cluster, out_path):
    gdf = gpd.read_file(shp_path)
    assert (np.sort(gdf[shp_key].unique()) == np.arange(1, n_cluster + 1)).all()

    mpi_info_df = pd.read_csv(csv_path)

    mpi_info_gdf = gdf.merge(mpi_info_df, left_on=shp_key, right_on=csv_key)

    assert mpi_info_gdf.shape[0] == gdf.shape[0]

    mpi_info_gdf.rename(
        columns={
            'tot_samp_ppl': 'tot_ppl',
            'pct_samp_ppl_mis': 'pct_pplmis'
        }, 
        inplace=True
    )

    mpi_info_gdf.to_file(out_path)


# Cambodia cluster-level MPI harmonized across 00, 05, 10, 14, and 21-22
country = 'khm'
spatial_res = 'clust'
version = 'hmn'
geodatafd_path = code_path.parent.parent / 'data' / 'DHS' / 'Cambodia' / 'geog'
years = ['00', '05', '10', '14', '21-22']
geodata_versions = [43, 51, 62, 71, 81]

for i, year in enumerate(years):
    survey = f'{country}_dhs{year}'
    n_cluster = [471, 557, 611, 611, 709][i]

    shp_name = f'KHGE{geodata_versions[i]}FL'
    shp_path =  geodatafd_path / shp_name
    shp_key = 'DHSCLUST'

    csv_path = outfd_path / f'mpi_{survey}_{version}_{spatial_res}_CI_mis.csv'
    csv_key = 'clust_no'

    out_path = outfd_path / f'mpi_{survey}_{version}_{spatial_res}_CI_mis'

    spatial_join(shp_path, shp_key, csv_path, csv_key, n_cluster, out_path)