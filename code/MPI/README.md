
| file_or_folder | description |
| --- | --- |
| khm_dhsYY_microdata_hmn.do | generates microdata in preparation for calculation of MPI harmonized across 2000 2005 2010 2014 and 2021-22 |
| khm_dhs_mpi_hmn_cluster.do | calculates cluster-level MPI with microdata generated from khm_dhsYY_microdata_hmn.do |
| khm_dhs_mpi_hmn_national.do | calculates national MPI with microdata generated from khm_dhsYY_microdata_hmn.do |
| ado | dependencies of khm_dhsYY_microdata_hmn.do (micro data generation do files) |
| postprocess_summarize_mpi.py | compiles MPI-related outputs (from khm_dhs_mpi_hmn_cluster.do), summarize missingness info, save as CSV |
| postprocess_map.py | joins MPI CSVs output from postprocess_summarize_mpi.py to cluster point shapefiles |