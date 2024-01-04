# Step 1: Attempting to match using Code_Srok and Code_Khum (of CF) against the commune codes in the reference dataset （DB23)

# Creating a function to perform the matching
def match_commune_by_codes(row, ref_data):
    # Check if Code_Khum matches
    khum_match = ref_data[ref_data['Code'] == row['Code_Khum']]
    if not khum_match.empty:
        return khum_match.iloc[0]['Name (Latin)'], khum_match.iloc[0]['Code']

    # Check if Code_Srok matches, assuming srok code is part of khum code
    srok_match = ref_data[ref_data['Code'].astype(str).str.startswith(str(row['Code_Srok']))]
    if not srok_match.empty:
        return srok_match.iloc[0]['Name (Latin)'], srok_match.iloc[0]['Code']

    # No match found
    return None, None

# # Apply the matching function to the subset data
# subset_data['Matched_Commune_Name'], subset_data['Matched_Commune_Code'] = zip(*subset_data.apply(
#     lambda row: match_commune_by_codes(row, commune_reference_data), axis=1))

# # Display the results of the matching
# subset_data[['CF_Code', 'Code_Srok', 'Code_Khum', 'CommGis', 'Commune', 'Matched_Commune_Name', 'Matched_Commune_Code']].head()
