def check_code_structure(code, level):
    """
    Check if the code structure matches the expected pattern based on the administrative level.
    """
    code_str = str(code)
    if level == 'Province':
        return len(code_str) in [1, 2]
    elif level in ['ស្រុក', 'ក្រុង', 'ខណ្ឌ']:  # District or Capital District or Special District
        return len(code_str) in [3, 4] and int(code_str[-2:]) > 0 and int(code_str[-2:]) < 20
    elif level == 'ឃុំ' or level == 'សង្កាត់':  # Commune or Special Commune
        return len(code_str) in [5, 6] and int(code_str[-2:]) > 0 and int(code_str[-2:]) < 30
    elif level == 'ភូមិ':  # Village
        return len(code_str) in [7, 8] and int(code_str[-2:]) > 0 and int(code_str[-2:]) < 35
    else:
        return False