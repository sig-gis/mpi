
| file_or_folder | description |
| --- | --- |
| khm_dhsYY_microdata_hmn.do | generates microdata in preparation for calculation of MPI harmonized across 2000 2005 2010 2014 and 2021-22 |
| khm_dhs_mpi_hmn_cluster.do | calculates MPI with microdata generated from khm_dhsYY_microdata_hmn.do |
| khm_dhsYY_microdata_cot.do | generates microdata in preparation for calculation of MPI harmonized across 2005 2010 and 2014 |
| khm_dhsYY_cluster_cot.do | calculates MPI with microdata generated from khm_dhsYY_microdata_cot.do |
| khm_dhsYY_microdata_cot_nowall.do | generates the same microdata as in khm_dhsYY_microdata_cot.do except for the exclusion of wall material from housing indicator |
| khm_dhsYY_cluster_cot_nowall.do | calculates MPI with microdata generated from khm_dhsYY_microdata_cot_nowall.do |
| khm_dhsYY_microdata.do | generates microdata in preparation for calculation of MPI NOT harmonized across 2005 2010 and 2014 |
| khm_dhsYY_cluster.do | calculates MPI with microdata generated from khm_dhsYY_microdata.do |
| khm_dhsYY_dp.do | scripts from OPHI |
| *_test.do | tests during development |
| ado | dependencies of microdata generation do files |
| analysis.ipynb | SE CI missingness of standard MPI and MPI harmonized across 2005 2010 and 2014  |
| ben* | MPI calculation scripts for Benin from UNDP(?) |
| eda.do | exploratory data analysis while going through khm_dhs14_microdata_test.do |
| eda.ipynb | check out raw data and microdata |
| eda_check_microdata.ipynb | check updates done to 05 10 14 microdata for harmonization with 00 and 21-22 |
| eda.py | recreation of some MPI 2014 and 2010 calculations |
| plot.py | bar chart of regional MPI based on Cambodia DHS 2014 |
| postprocess.py | compiles regional/cluster-level data files and joins compiled tables to shapefiles |
| postprocess_summarize_mpi.py | compiles MPI-related outputs (from khm_dhs_mpi_hmn_cluster.do), summarize missingness info, save as CSV |
| setup.do | test importing mpi calculation packages |
| tha* | Thailand scripts |
| v* | Vietnam scripts |
