vlst = '1030201\n1030202\n1030203\n1030204\n1030205\n1030206\n1030207\n1030208\n1030209\n1030212'


def commun_code_is_unique(vlst): 
    vlst = vlst.split('\n')
    clst = [vcode[:-2] for vcode in vlst]
    return len(set(clst)) == 1


commun_code_is_unique(vlst)
commun_code_is_unique('10060705\r\n10060706\r\n10060707\r\n10060708\r\n10060801')


def extract_first_commun_code(vlst):
    vlst = vlst.split('\n')
    first_vcode = vlst[0]
    first_ccode = first_vcode[:-2]
    try:
        return int(first_ccode)
    except:
        return -9999
