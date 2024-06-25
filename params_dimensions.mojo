from math import trunc, sqrt
from testing.testing import assert_equal

alias EnumTypeDimensions_None = 0
alias EnumTypeDimensions_Width = 1
alias EnumTypeDimensions_Height = 2
alias EnumTypeDimensions_Larger = 3
alias EnumTypeDimensions_MaxSize = 4
alias EnumTypeDimensions_MPixels = 5

# Int should be UInt32 but, now, there is bascially nothing we can do now with a UInt
@value
struct ParamsDimensionsResponse:
    var width : UInt32
    var height : UInt32

@value
struct ParamsDimensions:
    var width  : UInt32
    var height : UInt32
    var mpixels : Float32
    var type_dim : UInt8  

    @staticmethod
    fn new_width(x : Int) -> Self:
        """
            new_width()
                we wanna open the image with a given width, the height will be recalculated given the aspect ratio.
        """
        return ParamsDimensions(
            width = x,
            height = Int.MAX,
            mpixels = 0,
            type_dim = EnumTypeDimensions_Width
        )

    @staticmethod
    fn new_height(x : UInt32) -> Self:
        """
            new_height()
                we wanna open the image with a given height, the width will be recalculated given the aspect ratio.
        """
        return ParamsDimensions(
            width = Int.MAX,
            height = x,
            mpixels = 0,
            type_dim = EnumTypeDimensions_Height
        )

    @staticmethod
    fn new_size(width : UInt32, height : UInt32) -> Self:
        """
            new_size()
                we wanna open the image with a given width and height.
                Any value higher than those given will be recalculated given the aspect ratio.
        """
        return ParamsDimensions(
            width,
            height,
            mpixels = 0,
            type_dim = EnumTypeDimensions_MaxSize
        )

    @staticmethod
    fn new_larger(x : UInt32) -> Self:
        """
            new_size()
                we wanna open the image with a given the higher dimension.
                Any value higher than the one given will be recalculated given the aspect ratio.
        """
        return ParamsDimensions(
            width = x,
            height = x,
            mpixels = 0,
            type_dim = EnumTypeDimensions_Larger
        )

    @staticmethod
    fn new_mpixels(x : Float32) -> Self:
        """
            new_size()
                we want to open the image with a given the MPixels size.
                Any image with a higer value than Float32 will be reduced witgh respect of the aspect ratio.
        """
        return ParamsDimensions(
            width = 0,
            height = 0,
            mpixels = x,
            type_dim = EnumTypeDimensions_MPixels
        )


    @staticmethod
    fn new() -> Self:
        """
            new_size()
                we want to open the image without any constraint.
        """
        return ParamsDimensions(
            width = 0,
            height = 0,
            mpixels = 0,
            type_dim = EnumTypeDimensions_None   
        )

    @always_inline
    fn resized_asked(self) -> Bool:
        return self.type_dim!=EnumTypeDimensions_None
        
    fn get_new_dimensions(self, src_width : UInt32, src_height : UInt32) -> ParamsDimensionsResponse:
        var ratio = src_width.cast[DType.float32]() / src_height.cast[DType.float32]()
        var self_width = self.width.cast[DType.float32]()
        var self_height = self.height.cast[DType.float32]()
        var width = src_width.cast[DType.float32]()
        var height = src_height.cast[DType.float32]()
        # fast exit
        if self.type_dim!=EnumTypeDimensions_None:
            if self.type_dim==EnumTypeDimensions_Width:
                if width>self_width:
                    width = self_width
                    height = self_width / ratio
            elif self.type_dim==EnumTypeDimensions_Height:
                if height>self_height:
                    height = self_height
                    width = self_height * ratio
            elif self.type_dim==EnumTypeDimensions_MaxSize:
                if width>self_width:
                    width = self_width
                    height = self_width / ratio
                if height>self_height:
                    height = self_height
                    width = self_height * ratio
            elif self.type_dim==EnumTypeDimensions_Larger:
                if width > height:
                    if width>self_width:
                        width = self_width
                        height = self_width / ratio
                    elif height>self_height:
                        height = self_height
                        width = self_height * ratio
            elif self.type_dim==EnumTypeDimensions_MPixels:                
                var mpixels_image = (height * width) / (1024. * 1024.)
                if mpixels_image > self.mpixels:
                    var coef = sqrt(mpixels_image / self.mpixels)
                    width = width / coef
                    height = width / ratio

        var w = (width / 8).roundeven().cast[DType.uint32]() * 8 # 8 pixels alignement <= 32 bytes (AVX/AVX2/AVX10)            
        var h = height.roundeven().cast[DType.uint32]()
        return ParamsDimensionsResponse( w.value, h.value)
                

    @staticmethod
    fn validation() raises :
        var width = 2048
        var height = 1366
        var ratio = Float32(width) / Float32(height)
        # ask for nothing, get nothing in return : fine
        var x = ParamsDimensions.new()
        var y = x.get_new_dimensions(width,height)
        assert_equal(y.width, width, "Error")
        assert_equal(y.height, height, "Error")

        # minimal width is superior to real width => nothing change : fine
        x = ParamsDimensions.new_width(2050)
        y = x.get_new_dimensions(width,height)
        assert_equal(y.width, width, "Error")
        assert_equal(y.height, height, "Error")

        # minimal height is superior to real height => nothing change : fine
        x = ParamsDimensions.new_height(1500)
        y = x.get_new_dimensions(width,height)
        assert_equal(y.width, width, "Error")
        assert_equal(y.height, height, "Error")
        
        # minimal width is inferior to real width => nothing change : fine
        x = ParamsDimensions.new_width(1920)
        y = x.get_new_dimensions(width,height)
        assert_equal(y.width, 1920, "Error")
        assert_equal(y.height, UInt32(trunc(1920./ratio)), "Error")

        # minimal height is superior to real height => nothing change : fine
        x = ParamsDimensions.new_width(1280)
        print("ratio: ",ratio, 1280.*ratio, trunc(1280.*ratio), UInt32(trunc(1280.*ratio)), UInt32(1919.0))
        y = x.get_new_dimensions(width,height)
        assert_equal(y.width, UInt32(trunc(1280.*ratio)), "Error")
        assert_equal(y.height, 1280, "Error")

        
        











