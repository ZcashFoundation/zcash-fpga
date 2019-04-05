class zcash_fpga:
    import serial
    import codecs
    def __init__(self, COM='COM4'):       
        self.s = self.serial.Serial(COM, 921600, timeout=1)
        #Test getting FPGA status
        self.get_status()
        print("Connected...")

    # FPGA status
    def get_status(self):
        self.s.write(self.codecs.decode('0800000001000000', 'hex'))
        # Parse reply
        res = self.s.read(1024)
        print(res)


    def close(self):
        self.s.close()
        print("Closed...")


#Example usage:

zf = zcash_fpga()

zf.close()


