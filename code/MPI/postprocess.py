# -*- coding: utf-8 -*-
"""
Created on Wed Nov  9 16:01:01 2022

@author: tianc
"""

from pathlib import Path
import pandas as pd

# code_path = Path(__file__)
code_path = Path(r'C:\Users\tianc\OneDrive\Documents\SIG\DISES\code\MPI')
datafd_path = code_path.parent.parent / 'data' / 'MPI' / 'dta'


df = pd.read_stata(datafd_path / 'khm_dhs14_mpi_rgn1.dta')

df.MPI_1[0]
