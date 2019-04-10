
     
class zcash_fpga:
    import serial
    import codecs
    import struct

    def byt_to_ver(a):
        return 'v{}.{}.{}'.format(a[2], a[1], a[0])

    def byt_to_str(a):
        return a[::-1].decode("utf-8")

    def byt_to_hex(a):
        return a.hex()

    fpga_msg_type_dict = {'FPGA_IGNORE_RPL':int('80000002', 16),
                          'FPGA_STATUS_RPL':int('80000001', 16),
                          'RESET_FPGA_RPL':int('80000000', 16),
                          'VERIFY_SECP256K1_SIG_RPL':int('80000101', 16)}

    fpga_msg_dict = {fpga_msg_type_dict['VERIFY_SECP256K1_SIG_RPL']:{'name':'FPGA_IGNORE_RPL', 'feilds':[(8, 'index', byt_to_hex), (1, 'bm', byt_to_hex)]},
                     fpga_msg_type_dict['FPGA_IGNORE_RPL']:{'name':'FPGA_IGNORE_RPL', 'feilds':[(8, 'ignored_header', byt_to_hex)]},
                     fpga_msg_type_dict['FPGA_STATUS_RPL']:{'name':'FPGA_STATUS_RPL', 'feilds':[(4, 'version', byt_to_ver), (8, 'build_date', byt_to_str), (8, 'buid_host', byt_to_str), (8, 'cmd_cap', byt_to_hex)]},
                     fpga_msg_type_dict['RESET_FPGA_RPL']:{'name':'RESET_FPGA_RPL', 'feilds':[]}}

    
    def __init__(self, COM='COM4'):       
        self.s = self.serial.Serial(COM, 921600, timeout=1)
        #Test getting FPGA status
        self.get_status()
        print("Connected...")

    # FPGA status
    def get_status(self):
        self.s.write(self.codecs.decode('0800000001000000', 'hex'))
        # Parse reply
        self.get_reply()

    def reset_fpga(self):
        self.s.write(self.codecs.decode('0800000000000000', 'hex'))
        # Parse reply - should be reset
        res = self.get_reply()
        if (self.struct.unpack('<I', res[4:8])[0] != self.fpga_msg_type_dict['RESET_FPGA_RPL']):
            print("ERROR: Reply type was not RESET_FPGA_RPL")                

    def get_reply(self):    
        res = self.s.read(1024)
        self.print_reply(res)
        return res
 
    def secp256k1_verify_sig(self, index, hsh, r, s, Qx, Qy):
        cmd = 'B000000001010000'
        cmd += format(index, 'x').ljust(16, '0')
        cmd += format(s, 'x').ljust(64, '0')
        cmd += format(r, 'x').ljust(64, '0')
        cmd += format(hsh, 'x').ljust(64, '0')
        cmd += format(Qx, 'x').ljust(64, '0')
        cmd += format(Qy, 'x').ljust(64, '0')
        self.s.write(self.codecs.decode(cmd, 'hex'))
        res = self.get_reply()
        if (self.struct.unpack('<I', res[4:8])[0] != self.fpga_msg_type_dict['VERIFY_SECP256K1_SIG_RPL']):
            print("ERROR: Reply type was not VERIFY_SECP256K1_SIG_RPL")
            
    def close(self):
        self.s.close()
        print("Closed...")

    def print_reply(self, msg):
        if (len(msg) < 8):
            print("ERROR: Message too small")
        length = (self.struct.unpack('<I', msg[0:4])[0])
        if (len(msg) != length):
            print("ERROR: Message length mismatch")
        cmd = (self.struct.unpack('<I', msg[4:8])[0])
        if (cmd not in self.fpga_msg_dict):
            print("ERROR: Unknown message type:", cmd)             

        print ("INFO: Received ", self.fpga_msg_dict[cmd]['name'])
        offset = 8
        for i in range(len(self.fpga_msg_dict[cmd]['feilds'])):
            length = self.fpga_msg_dict[cmd]['feilds'][i][0]
            print(self.fpga_msg_dict[cmd]['feilds'][i][1], ":", self.fpga_msg_dict[cmd]['feilds'][i][2](bytes(msg[offset:offset+length])))
            offset += length

#Example usage:

zf = zcash_fpga()
zf.secp256k1_verify_sig(1, 1, 1, 1, 1, 1)

zf.close()


