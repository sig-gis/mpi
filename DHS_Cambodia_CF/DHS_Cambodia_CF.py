#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue May 24 13:20:07 2022

@author: apple
"""

# %% import modules

import geopandas as gpd
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

sns.set_theme()  # style="whitegrid")


# %% helper functions


def find_duplicate_geom(gdf, id_colname, decimal=1, geom_colname='geometry'):
    '''
    Parameters
    ----------
    gdf : geodataframe
        Dataset.
    geom_colname : string
        Name of column containing geometries.
    decimal : int
        Decimal points to consider when deciding coincidence of coordinates.
    id_colname : string
        Name of column containing geometry identifiers.

    Returns
    -------
    List of identifiers of duplicated geometries.

    '''

    geom_ser = gdf.loc[:, geom_colname]
    uniqgeoms = []
    dupids = []
    for i, geom in enumerate(geom_ser):
        if any(g.almost_equals(geom, decimal=decimal) for g in uniqgeoms):
            dupids.append(gdf.iloc[i, ][id_colname])
        else:
            uniqgeoms.append(geom)
    return dupids


# %% read in data

# code_path = Path(__file__)
code_path = Path('/Users/apple/Desktop/SIG/DISES/DHS_Cambodia_CF')
datafd_path = code_path.parent / 'data'

# community forests (CF)
CF_path = datafd_path / 'CF' / 'Cambodia' / 'CF layer of Cambodia' / \
    'All_CF_Cambodia_July_2016.shp'
CF_gdf = gpd.read_file(CF_path)  # EPSG:3148
# CF, updated in 20220526 email
CFv1_path = datafd_path / 'CF' / 'Cambodia' / \
    'All_CF_Cambodia_July_2016_DISES_v1' / \
    'All_CF_Cambodia_July_2016_DISES_v1.shp'
CFv1_gdf = gpd.read_file(CFv1_path)  # EPSG:3148

# DHS clusters
DHS_fdlst = ['KHGE43FL', 'KHGE51FL', 'KHGE62FL', 'KHGE71FL']
DHS_pathlst = [datafd_path/'DHS'/'Cambodia'/'geog'/fd for fd in DHS_fdlst]
DHS_gdflst = [gpd.read_file(file) for file in DHS_pathlst]

# districts
# TODO


# %% check and clean data

# %%% CFv1

# %%%% raw CF

# compare with CF (original version, v0):

# CFv1 has three more columns than CF:
# UniqueID - 1 to 675, with gaps, unique (= CF_gdf.id + 1)
# Why_Remove
# Overlap_Pa

# 675 rows in CF, only 639 left in CFv1

# # check multipolygons
# np.unique(CFv1_gdf.geometry.geom_type)  # MultiPolygon and Polygon
# tuple(CFv1_gdf.loc[CFv1_gdf.geometry.geom_type == 'MultiPolygon', :][
#     'UniqueID'])  # ids
# # check multipolygons in qgis: filter attribute table: "UniqueID" IN (30,...)
# # same as in v0

# # check geom validity
# tuple(CFv1_gdf.loc[~CFv1_gdf.geometry.is_valid, :]['UniqueID'])
# # same as in v0

# # check duplicate geom
# find_duplicate_geom(CFv1_gdf, id_colname='UniqueID')  # none!
# # check duplicate geom in qgis (check geometries): none either!

# # check areas
# np.sort(CFv1_gdf.area)[0]
# np.sort(CFv1_gdf.area)[-1]
# # all reasonable areas, shpfile HECTARES field has wrong info for UniqueID=347

# # 'check geometries' in qgis #no geom within another geom

# %%%% buffered CF

# buffer
CFv1_gdf['geom_bf20km'] = CFv1_gdf.geometry.buffer(20*1000)

# # check multipolygons
# np.unique(CFv1_gdf.geom_bf20km.geom_type)  # only Polygon

# # check geom validity
# tuple(CFv1_gdf.loc[~CFv1_gdf.geom_bf20km.is_valid, :]['UniqueID'])  # all valid

# # check duplicate geom
# find_duplicate_geom(CFv1_gdf,
#                     id_colname='UniqueID',
#                     geom_colname='geom_bf20km')  # none

# # check areas
# np.sort(CFv1_gdf.geom_bf20km.area)[0] / 1e4  # all reasonable areas
# np.sort(CFv1_gdf.geom_bf20km.area)[-1]

# # write buffered CF data
CFv1_bf20km_gdf = CFv1_gdf.set_geometry('geom_bf20km', drop=True)
# out_path = datafd_path / 'CF' / 'Cambodia' / \
#     'All_CF_Cambodia_July_2016_DISES_v1_bf20km'
# CFv1_bf20km_gdf.to_file(out_path)

# %%%% centroid of CF

# compute centroids
CFv1_gdf['geom_centroid'] = CFv1_gdf.geometry.centroid

# # check multipolygons
# np.unique(CFv1_gdf.geom_centroid.geom_type)  # only Point

# # check geom validity
# tuple(CFv1_gdf.loc[~CFv1_gdf.geom_centroid.is_valid, :]['UniqueID'])
# # all valid

# # check duplicate geom
# find_duplicate_geom(CFv1_gdf,
#                     id_colname='UniqueID',
#                     geom_colname='geom_centroid')  # none

# # write CF centroid data
CFv1_ctrd_gdf = CFv1_gdf.set_geometry('geom_centroid', drop=True).drop(
    columns='geom_bf20km')  # otherwise cannot write to file
# out_path = datafd_path / 'CF' / 'Cambodia' / \
#     'All_CF_Cambodia_July_2016_DISES_v1_centroid'
# CFv1_ctrd_gdf.to_file(out_path)

# %%% CF (original version, v0) - skip

# # %%%% raw CF

# # add unique id
# CF_gdf['id'] = CF_gdf.index
# # # write CF data with unique id
# # out_path = datafd_path / 'CF' / 'Cambodia' / 'All_CF_Cambodia_July_2016_id'
# # CF_gdf.to_file(out_path)

# # check multipolygons
# np.unique(CF_gdf.geometry.geom_type)  # MultiPolygon and Polygon
# tuple(CF_gdf.loc[CF_gdf.geometry.geom_type == 'MultiPolygon', :]['id'])  # ids
# # check multipolygons in qgis: filter attribute table: "id" IN (29, 35, ...)

# # check geom validity
# tuple(CF_gdf.loc[~CF_gdf.geometry.is_valid, :]['id'])
# # check in qgis

# # check duplicate geom
# find_duplicate_geom(CF_gdf, id_colname='id')
# # if any(g.equals(geom) for g in uniqgeoms):  # dupids:[473, 606, 639]
# # if any(g.almost_equals(geom, decimal=3) for g in uniqgeoms):  # 3 more id
# # check duplicate geom in qgis (check geometries): some not picked up by gpd

# # check areas
# np.sort(CF_gdf.area)  # all reasonable areas, correspond to qgis areas

# # 'check geometries' in qgis #1 geom within another geom

# # %%%% buffered CF

# # buffer
# CF_gdf['geom_bf20km'] = CF_gdf.geometry.buffer(20*1000)

# # check multipolygons
# np.unique(CF_gdf.geom_bf20km.geom_type)  # only Polygon

# # check geom validity
# tuple(CF_gdf.loc[~CF_gdf.geom_bf20km.is_valid, :]['id'])  # all valid

# # check duplicate geom
# find_duplicate_geom(CF_gdf,
#                     id_colname='id',
#                     geom_colname='geom_bf20km')  # all already known

# # check areas
# np.sort(CF_gdf.geom_bf20km.area)[0]  # all reasonable areas
# np.sort(CF_gdf.geom_bf20km.area)[-1]

# # # write buffered CF data
# CF_bf20km_gdf = CF_gdf.set_geometry('geom_bf20km', drop=True)
# # out_path = datafd_path / 'CF' / 'Cambodia' / 'All_CF_Cambodia_July_2016_id_bf20km'
# # CF_bf20km_gdf.to_file(out_path)


# %%% DHS clusters

for i in range(4):
    DHS_gdf = DHS_gdflst[i]
    DHS_gdf.to_crs(epsg=3148, inplace=True)  # project
    assert(all(DHS_gdf.columns == DHS_gdflst[0].columns))  # same columns

DHS_gdf = pd.concat(DHS_gdflst)  # long df with all four dfs

# # quick checks
# assert sum(DHS_gdf.DHSID.duplicated()) == 0  # unique DHSIDs
# np.sort(DHS_gdf.DHSID)  # DHSIDs all formated
# assert set(DHS_gdf.URBAN_RURA) == {'U', 'R'}  # urban rural info

# # check geom type
# np.unique(DHS_gdf.geometry.geom_type)  # only Point

# # check geom validity
# DHS_gdf.loc[~DHS_gdf.geometry.is_valid, :]  # all valid

# # check duplicate geom
# find_duplicate_geom(DHS_gdf, 'DHSID')  # about a dozen, 
# # but no more after dropping rows w/ MIS in SOURCE col
# # duplicates within each year?
# for i,gdf in enumerate(DHS_gdflst):
#     print(i)
#     print(np.unique(gdf.DHSYEAR))
#     print(find_duplicate_geom(gdf, 'DHSID'))
# # 2005
# # ['KH200500000042', 'KH200500000180', 'KH200500000210', 'KH200500000323', 
# # 'KH200500000389', 'KH200500000400', 'KH200500000407', 'KH200500000513']
# # 2010
# # ['KH201000000386', 'KH201000000387', 'KH201000000498']
# # these are actually clusters with missing GPS data: SOURCE column says 'MIS'

# drop rows with missing location info
DHS_gdf = DHS_gdf.loc[DHS_gdf.SOURCE != 'MIS', :]


# %% process data


year = 2000

# %%% count # of clusters within buffered CF geoms

## wrapped into function: count_npt_in_poly
# join CF gdf with DHS cluster points within each CF
CFbf_DHSinCF_gdf = CFv1_bf20km_gdf.sjoin(DHS_gdf.loc[DHS_gdf.DHSYEAR==year, :],
                                          how='inner', predicate='contains')
# count # of clusters for CFs with clusters near them
n_DHSinCF_ser = CFbf_DHSinCF_gdf.groupby('UniqueID').size()
# count # of clusters for each CF id
n_DHSinAllCF_ser = n_DHSinCF_ser.reindex(CFv1_bf20km_gdf.UniqueID,
                                          fill_value=0)


def count_npt_in_poly(pt_gdf, poly_gdf, polyID_colname):
    poly_w_ptInPoly_gdf = poly_gdf.sjoin(pt_gdf, 
                                         how='inner', predicate='contains')
    npt_in_poly_ser = poly_w_ptInPoly_gdf.groupby(polyID_colname).size()
    poly_id_ser = poly_gdf.loc[:, polyID_colname]
    npt_in_eachPoly_ser = npt_in_poly_ser.reindex(poly_id_ser,
                                                  fill_value=0)
    return npt_in_eachPoly_ser


count_npt_in_poly(DHS_gdf.loc[DHS_gdf.DHSYEAR==year, :],
                  CFv1_bf20km_gdf, 'UniqueID')

# %%%% count # of URBAN clusters within buffered CF geoms
n_uCLUSTinCF_ser = count_npt_in_poly(DHS_gdf.loc[(DHS_gdf.DHSYEAR==year) &
                                                 (DHS_gdf.URBAN_RURA=='U'), :],
                                     CFv1_bf20km_gdf, 'UniqueID')

# %%%% count # of RURAL clusters within buffered CF geoms
n_rCLUSTinCF_ser = count_npt_in_poly(DHS_gdf.loc[(DHS_gdf.DHSYEAR==year) &
                                                 (DHS_gdf.URBAN_RURA=='R'), :],
                                     CFv1_bf20km_gdf, 'UniqueID')


# %%% find closest cluster to each CF centroid and calculate the distance
CFctrd_nearstDHS_gdf = CFv1_ctrd_gdf.sjoin_nearest(
    DHS_gdf.loc[DHS_gdf.DHSYEAR==year, :],
    how='left', distance_col='dist2closestCluster_m')


# %% results

# %%% histogram: size of community forests

CFarea_ser = CFv1_gdf.geometry.area / 10000  # m2 to hectare
# %%%% plot
fig, ax = plt.subplots(1)
ax.hist(CFarea_ser, bins=20)
ax.set_xlabel('area of community forest (ha)')
ax.set_ylabel('number of community forests')


# %%% number and % of CF that have >0 clusters within 20km

nCF_hasDHS = np.sum(n_DHSinCF_ser > 0)
nCF_tot = CFv1_bf20km_gdf.shape[0]
percCF_hasDHS = nCF_hasDHS / nCF_tot * 100
f"{round(percCF_hasDHS, 1)}% ({nCF_hasDHS}/{nCF_tot}) community forests have at least one DHS-{year} cluster within 20km."


# %%% boxplot: CF size (y axis) vs T/F—CF has clusters within 20km (x axis)

# %%%% raw area
plot_df = pd.DataFrame({'area': CFarea_ser,
                        'has_clust': 
                            (n_DHSinAllCF_ser > 0).reset_index(drop=True)})
# %%%%% calculate mean, sd, median
plot_df.groupby('has_clust').describe().round(2).T

# calculate mean, sd, median: has_urban_clust, has rural_clust
udf = pd.DataFrame({'area': CFarea_ser,
                    'has_urban_clust': (n_uCLUSTinCF_ser > 0).reset_index(drop=True)})
udf = udf.groupby('has_urban_clust').describe().round(2).T
# udf.to_csv('Desktop/urban.csv')
rdf = pd.DataFrame({'area': CFarea_ser,
                    'has_rural_clust': (n_rCLUSTinCF_ser > 0).reset_index(drop=True)})
rdf = rdf.groupby('has_rural_clust').describe().round(2).T
# rdf.to_csv('Desktop/rural.csv')

# %%%% log area
plot_df = pd.DataFrame({'area': np.log(CFarea_ser),
                        'has_clust': 
                            (n_DHSinAllCF_ser > 0).reset_index(drop=True)})

# %%%% plot
fig, ax = plt.subplots(1)
plot_df.boxplot(column='area', by='has_clust', ax=ax)
ax.set_xlabel('community forest has a cluster within 20km')
ax.set_ylabel('log area of community forest (ha)')
# ax.set_ylabel('area of community forest (ha)')
ax.set_title(year)
fig.suptitle('')

# %%% histogram: # of CFs (y axis) vs binned # of clusters w/in 20km of CF (x)

# %%%% plot without 0's
fig, ax = plt.subplots(1)
xticks = np.arange(0, max(n_DHSinCF_ser) + 1, 2)
ax.hist(n_DHSinCF_ser, bins=xticks)
ax.set_xticks(xticks)
ax.set_xlabel('number of clusters within 20km of a community forest')
ax.set_ylabel('number of community forests')
ax.set_title(year)

# %%%% plot including CF w/ no clusters near them
fig, ax = plt.subplots(1)
xticks = np.arange(0, max(n_DHSinAllCF_ser) + 1, 2)
ax.hist(n_DHSinAllCF_ser, bins=xticks)
ax.set_xticks(xticks)
ax.set_xlabel('number of clusters within 20km of a community forest')
ax.set_ylabel('number of community forests')
ax.set_title(year)


# %%% scatterplot: CF size (y axis) vs # of clusters within 20km of CF(x axis)
# %%%% plot
fig, ax = plt.subplots(1)
plt.scatter(n_DHSinAllCF_ser, CFarea_ser,
            s=.5)
ax.set_xlabel('number of clusters within 20km of community forest')
ax.set_ylabel('area of community forest (ha)')
xticks = np.arange(0, max(n_DHSinAllCF_ser) + 1, 2)
ax.set_xticks(xticks)
ax.set_title(year)


# %%% histogram: # of CF (y) vs distance b/w CF ctrd & its closest CLUST (x)
# %%%% plot
fig, ax = plt.subplots(1)
ax.hist(CFctrd_nearstDHS_gdf.dist2closestCluster_m / 1000, bins=20)
ax.set_xlabel('''distance between community forest centroid 
              and its closest cluster (km)''')
ax.set_ylabel('number of community forests')
ax.set_title(year)


# %%% scatterplot: distance between community forest centroid and 
# its closest cluster (x axis) vs CF size (y axis)
# %%%% plot
fig, ax = plt.subplots(1)
plt.scatter(CFctrd_nearstDHS_gdf.dist2closestCluster_m / 1000,
            CFarea_ser,
            s=.5)
ax.set_xlabel('''distance between community forest centroid 
              and its closest cluster (km)''')
ax.set_ylabel('area of community forest (ha)')
ax.set_title(year)
# %%%% plot - log on y axis
fig, ax = plt.subplots(1)
plt.scatter(CFctrd_nearstDHS_gdf.dist2closestCluster_m / 1000,
            np.log(CFarea_ser),
            s=.5)
ax.set_xlabel('''distance between community forest centroid 
              and its closest cluster (km)''')
ax.set_ylabel('log area of community forest (ha)')
ax.set_title(year)





























