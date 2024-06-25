
@value
struct ParamsCompression:
    var compression : Int32
    var chrominance_subsampling : Bool
    var density_unit : UInt8
    var x_density : UInt16
    var y_density : UInt16
    var _arithmetic : Int32 # arithmetic or Huffman coding
    var data_precision : Int32

    fn __init__(inout self, compression : Int, chrominance_subsampling : Bool):
        if compression<0:
            self.compression = 1
        elif compression>100:
            self.compression = 100
        else:
            self.compression = compression
        self.chrominance_subsampling = chrominance_subsampling
        self.density_unit = 1 # dots/inch
        self.x_density = 300
        self.y_density = 300
        self._arithmetic = 0 # arithmetic or Huffman coding
        self.data_precision = 8

    # arithmetic coding compress more (let's say 10%) but it is slower (let's say 7 times)
    # better forget it and use jpegli
    @always_inline
    fn set_arithmetic(inout self):
        self._arithmetic = 1   
    
    @always_inline
    fn get_arithmetic(self) -> Int32:
        return self._arithmetic

    @always_inline
    fn set_huffman(inout self):
        self._arithmetic = 0

    # more than 4096 is an insane value
    fn set_dpi(inout self, dpi : Int):
        if dpi>0 and dpi<=4096:
            self.x_density = UInt16(dpi)
            self.y_density = self.x_density
        
    # reserved for future use => 8 bits, 12 bits or 16 bits
    fn set_precision(inout self, precision : Int):
        if precision==8 or precision==12 or precision==16:
            self.data_precision = precision
        
       
            