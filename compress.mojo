from common import *

alias jpeg_create_compress = fn(UnsafePointer[JpegCompressStruct], Int32, size_t) -> Bool 
alias jpeg_mem_dest = fn(UnsafePointer[JpegCompressStruct],UnsafePointer[UnsafePointer[UInt8]], UnsafePointer[SIMD[DType.uint64,1]]) -> Bool 
alias jpeg_set_defaults = fn(UnsafePointer[JpegCompressStruct]) -> Bool 
alias jpeg_set_quality = fn(UnsafePointer[JpegCompressStruct], Int32, C_Bool) -> Bool 
alias jpeg_start_compress = fn(UnsafePointer[JpegCompressStruct], C_Bool) -> Bool 
alias jpeg_write_icc_profile = fn(UnsafePointer[JpegCompressStruct], UnsafePointer[UInt8], Int32) -> Bool 
alias jpeg_write_scanlines = fn(UnsafePointer[JpegCompressStruct], UnsafePointer[DTypePointer[DType.uint8, AddressSpace.GENERIC]], Int32) -> JDIMENSION 
alias jpeg_finish_compress = fn(UnsafePointer[JpegCompressStruct]) -> Bool 
alias jpeg_destroy_compress = fn(UnsafePointer[JpegCompressStruct]) -> Bool 

@value
struct JpegComponentInfo:
    var component_id : Int32
    var component_index : Int32
    var h_samp_factor : Int32
    var v_samp_factor : Int32
    var quant_tbl_no : Int32
    var dc_tbl_no : Int32
    var ac_tbl_no : Int32
    var width_in_blocks : JDIMENSION
    var height_in_blocks : JDIMENSION
    var DCT_scaled_size : Int32
    var downsampled_width : JDIMENSION
    var downsampled_height : JDIMENSION
    var component_needed : C_Bool
    var MCU_width : Int32
    var MCU_height : Int32
    var MCU_blocks : Int32
    var MCU_sample_width : Int32
    var last_col_width : Int32
    var last_row_height : Int32
    var quant_table: UnsafePointer[UInt8]
    var dct_table: UnsafePointer[UInt8]

    fn __init__(inout self):  
        self.component_id = 0
        self.component_index = 0
        self.h_samp_factor = 0
        self.v_samp_factor = 0
        self.quant_tbl_no = 0
        self.dc_tbl_no = 0
        self.ac_tbl_no = 0
        self.width_in_blocks = 0
        self.height_in_blocks = 0
        self.DCT_scaled_size = 0
        self.downsampled_width = 0
        self.downsampled_height = 0
        self.component_needed = 0
        self.MCU_width = 0
        self.MCU_height = 0
        self.MCU_blocks = 0
        self.MCU_sample_width = 0
        self.last_col_width = 0
        self.last_row_height = 0
        self.quant_table = UnsafePointer[UInt8]()
        self.dct_table = UnsafePointer[UInt8]()

@value
struct JpegCompressStruct:
    var err: UnsafePointer[UInt8]
    var mem: UnsafePointer[UInt8]
    var progress: UnsafePointer[UInt8]
    var client_data: UnsafePointer[UInt8]
    var is_decompressor: C_Bool
    var global_state: Int32
    var dest: UnsafePointer[UInt8]
    var image_width: JDIMENSION
    var image_height: JDIMENSION
    var input_components: Int32
    var in_color_space: J_COLOR_SPACE
    var input_gamma: Float64
    var data_precision: Int32
    var num_components: Int32
    var jpeg_color_space: J_COLOR_SPACE
    var comp_info: UnsafePointer[JpegComponentInfo]
    var quant_tbl_ptrs: InlineArray[Int, 4]    # will be filled with correct values by libjpeg, not by us
    var dc_huff_tbl_ptrs: InlineArray[Int, 4]  # will be filled with correct values by libjpeg, not by us
    var ac_huff_tbl_ptrs: InlineArray[Int, 4]  # will be filled with correct values by libjpeg, not by us
    var arith_dc_L: InlineArray[UInt8, 16] 
    var arith_dc_U: InlineArray[UInt8, 16] 
    var arith_ac_K: InlineArray[UInt8, 16]     
    var num_scans: Int32
    var scan_info: UnsafePointer[UInt8]
    var raw_data_in: C_Bool
    var arith_code: C_Bool
    var optimize_coding: C_Bool
    var CCIR601_sampling: C_Bool
    var smoothing_factor: Int32
    var dct_method: J_DCT_METHOD
    var restart_interval: UInt32
    var restart_in_rows: Int32
    var write_JFIF_header: C_Bool
    var JFIF_major_version: UInt8
    var JFIF_minor_version: UInt8
    var density_unit: UInt8
    var X_density: UInt16
    var Y_density: UInt16
    var write_Adobe_marker: C_Bool
    var next_scanline: JDIMENSION
    var progressive_mode: C_Bool
    var max_h_samp_factor: Int32
    var max_v_samp_factor: Int32
    var total_iMCU_rows: JDIMENSION
    var comps_in_scan: Int32
    var cur_comp_info: InlineArray[Int, 4]
    var MCUs_per_row: JDIMENSION
    var MCU_rows_in_scan: JDIMENSION
    var blocks_in_MCU: Int32
    var MCU_membership: InlineArray[UInt32, 10]
    var Ss: Int32
    var Se: Int32
    var Ah: Int32
    var Al: Int32
    var master: UnsafePointer[UInt8]
    var main: UnsafePointer[UInt8]
    var prep: UnsafePointer[UInt8]
    var coef: UnsafePointer[UInt8]
    var marker: UnsafePointer[UInt8]
    var cconvert: UnsafePointer[UInt8]
    var downsample: UnsafePointer[UInt8]
    var fdct: UnsafePointer[UInt8]
    var entropy: UnsafePointer[UInt8]
    var script_space: UnsafePointer[UInt8]
    var script_space_size: Int32

    # I should just do a memeset_zero for the struct but I'm not sure I can
    fn __init__(inout self):   
        self.err = UnsafePointer[UInt8]()
        self.mem = UnsafePointer[UInt8]()
        self.progress = UnsafePointer[UInt8]()
        self.client_data = UnsafePointer[UInt8]()
        self.is_decompressor = C_Bool_False
        self.global_state = 0
        self.dest = UnsafePointer[UInt8]()
        self.image_width = 0
        self.image_height = 0
        self.input_components = 0
        self.in_color_space = 0
        self.input_gamma = 0.0
        self.data_precision = 0
        self.num_components = 0
        self.jpeg_color_space = 0
        self.comp_info = UnsafePointer[JpegComponentInfo]()
        self.quant_tbl_ptrs = InlineArray[Int, 4](0)    # will be filled with correct values by libjpeg, not by us
        self.dc_huff_tbl_ptrs = InlineArray[Int, 4](0)  # will be filled with correct values by libjpeg, not by us
        self.ac_huff_tbl_ptrs = InlineArray[Int, 4](0)  # will be filled with correct values by libjpeg, not by us
        self.arith_dc_L = InlineArray[UInt8, 16](0)
        self.arith_dc_U = InlineArray[UInt8, 16](0)
        self.arith_ac_K = InlineArray[UInt8, 16](0) 
        self.num_scans = 0
        self.scan_info = UnsafePointer[UInt8]()
        self.raw_data_in = 0
        self.arith_code = 0
        self.optimize_coding = 0
        self.CCIR601_sampling = 0
        self.smoothing_factor = 0
        self.dct_method = 0
        self.restart_interval = 0 
        self.restart_in_rows = 0
        self.write_JFIF_header = 0
        self.JFIF_major_version = 0
        self.JFIF_minor_version = 0
        self.density_unit = 0
        self.X_density = 0
        self.Y_density = 0
        self.write_Adobe_marker = 0
        self.next_scanline = 0
        self.progressive_mode = 0
        self.max_h_samp_factor = 0
        self.max_v_samp_factor = 0
        self.total_iMCU_rows = 0
        self.comps_in_scan = 0
        self.cur_comp_info = InlineArray[Int, 4](0) # ugly, should be [*mut jpeg_component_info; 4usize]
        self.MCUs_per_row = 0
        self.MCU_rows_in_scan = 0
        self.blocks_in_MCU = 0
        self.MCU_membership = InlineArray[UInt32, 10](0)
        self.Ss = 0
        self.Se = 0
        self.Ah = 0
        self.Al = 0
        self.master = UnsafePointer[UInt8]()
        self.main = UnsafePointer[UInt8]()
        self.prep = UnsafePointer[UInt8]()
        self.coef = UnsafePointer[UInt8]()
        self.marker = UnsafePointer[UInt8]()
        self.cconvert = UnsafePointer[UInt8]()
        self.downsample = UnsafePointer[UInt8]()
        self.fdct = UnsafePointer[UInt8]()
        self.entropy = UnsafePointer[UInt8]()
        self.script_space = UnsafePointer[UInt8]()
        self.script_space_size = 0

      